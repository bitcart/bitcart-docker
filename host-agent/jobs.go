package main

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"slices"
	"strconv"
	"strings"
	"syscall"
	"time"
)

type jobStatus struct {
	State    string `json:"state"`
	Verb     string `json:"verb,omitempty"`
	Created  *int64 `json:"created,omitempty"`
	Started  *int64 `json:"started,omitempty"`
	Finished *int64 `json:"finished,omitempty"`
	ExitCode *int   `json:"exit_code,omitempty"`
	Reason   string `json:"reason,omitempty"`
}

func now() *int64 { t := time.Now().Unix(); return &t }

func newJobID() string {
	b := make([]byte, 3)
	rand.Read(b)
	return time.Now().UTC().Format("20060102T150405Z") + "-" + hex.EncodeToString(b)
}

func detectExecutor() string {
	if st, err := os.Stat("/run/systemd/system"); err == nil && st.IsDir() && os.Geteuid() == 0 {
		if _, err := exec.LookPath("systemd-run"); err == nil {
			return "systemd-run"
		}
	}
	if runtime.GOOS == "darwin" {
		return "launchd"
	}
	return "setsid"
}

func readStatus(id string) (*jobStatus, error) {
	raw, err := os.ReadFile(filepath.Join(jobsDir, id, "status.json"))
	if err != nil {
		return nil, err
	}
	var st jobStatus
	return &st, json.Unmarshal(raw, &st)
}

func writeFileAtomic(path string, data []byte) error {
	tmp, err := os.CreateTemp(filepath.Dir(path), filepath.Base(path)+".*")
	if err != nil {
		return err
	}
	_, err = tmp.Write(data)
	if cerr := tmp.Close(); err == nil {
		err = cerr
	}
	if err == nil {
		err = os.Rename(tmp.Name(), path)
	}
	if err != nil {
		os.Remove(tmp.Name())
	}
	return err
}

func updateStatus(id string, change func(*jobStatus)) error {
	st, err := readStatus(id)
	if err != nil {
		return err
	}
	change(st)
	data, err := json.Marshal(st)
	if err != nil {
		return err
	}
	return writeFileAtomic(filepath.Join(jobsDir, id, "status.json"), append(data, '\n'))
}

func jobAlive(id string, st *jobStatus) bool {
	f, err := os.Open(filepath.Join(jobsDir, id, "pid"))
	if err == nil {
		defer f.Close()
		return errors.Is(
			syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB),
			syscall.EWOULDBLOCK,
		)
	}
	return st.Created != nil && time.Now().Unix()-*st.Created < jobStartGrace
}

func lockHolder() string {
	raw, err := os.ReadFile(lockFile)
	if id := strings.TrimSpace(string(raw)); err == nil && reJobID.MatchString(id) {
		return id
	}
	return ""
}

func refreshJob(id string) *jobStatus {
	st, err := readStatus(id)
	if err != nil || st.State != "running" || jobAlive(id, st) {
		return st
	}
	updateStatus(id, func(s *jobStatus) {
		if s.State != "running" {
			return
		}
		s.Finished = now()
		if s.Created != nil && *s.Finished-*s.Created >= jobSeconds {
			s.State, s.Reason = "failed", "timeout"
		} else {
			s.State = "lost"
		}
	})
	st, _ = readStatus(id)
	return st
}

func isRunning(id string) bool {
	st := refreshJob(id)
	return st != nil && st.State == "running"
}

func withGuard(fn func() error) error {
	f, err := os.Open(stateDir)
	if err != nil {
		return err
	}
	defer f.Close()
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX); err != nil {
		return err
	}
	return fn()
}

var errBusy = errors.New("busy")

func acquireLock(id string) (busy string, err error) {
	err = withGuard(func() error {
		if holder := lockHolder(); holder != "" && isRunning(holder) {
			busy = holder
			return errBusy
		}
		return writeFileAtomic(lockFile, []byte(id+"\n"))
	})
	return busy, err
}

func releaseLock(id string) {
	withGuard(func() error {
		if lockHolder() == id {
			os.Remove(lockFile)
		}
		return nil
	})
}

func runningJob() string {
	if holder := lockHolder(); holder != "" && isRunning(holder) {
		return holder
	}
	return ""
}

func pruneJobs() {
	entries, err := os.ReadDir(jobsDir)
	if err != nil {
		return
	}
	var ids []string
	for _, e := range entries {
		if e.IsDir() && reJobID.MatchString(e.Name()) {
			ids = append(ids, e.Name())
		}
	}
	slices.Sort(ids)
	slices.Reverse(ids)
	for _, id := range ids[min(keepJobs, len(ids)):] {
		if st := refreshJob(id); st != nil &&
			slices.Contains([]string{"done", "failed", "lost"}, st.State) {
			os.RemoveAll(filepath.Join(jobsDir, id))
		}
	}
}

func encodeRequest(fields []string) []byte {
	var buf bytes.Buffer
	for _, f := range fields {
		buf.WriteString(f)
		buf.WriteByte(0)
	}
	buf.WriteByte(0)
	return buf.Bytes()
}

func startJob(verbName string, fields []string) *apiError {
	pruneJobs()
	id := newJobID()
	auditJob = id
	dir := filepath.Join(jobsDir, id)
	status, _ := json.Marshal(jobStatus{State: "running", Verb: verbName, Created: now()})
	if os.Mkdir(dir, 0o700) != nil ||
		os.WriteFile(filepath.Join(dir, "request.bin"), encodeRequest(fields), 0o600) != nil ||
		os.WriteFile(filepath.Join(dir, "status.json"), append(status, '\n'), 0o600) != nil {
		os.RemoveAll(dir)
		return fail("internal", "could not create the job")
	}
	if busy, err := acquireLock(id); err != nil {
		os.RemoveAll(dir)
		auditJob = busy
		if busy != "" {
			return &apiError{Code: "busy", Message: "another job is running", JobID: busy}
		}
		return fail("internal", "could not start the job")
	}
	if spawnRunner(id) != nil {
		os.RemoveAll(dir)
		releaseLock(id)
		return fail("internal", "could not start the job")
	}
	send(reply{OK: true, Data: map[string]string{"job_id": id}}, nil)
	audit("started")
	return nil
}

func spawnRunner(id string) error {
	run := []string{filepath.Join(base, "bitcart-agent"), "--run-job", id}
	var cmd *exec.Cmd
	switch detectExecutor() {
	case "systemd-run":
		limit := strconv.FormatInt(jobSeconds+300, 10)
		cmd = exec.Command(
			"systemd-run",
			append([]string{"--unit", "bitcart-job-" + id, "--collect", "--quiet",
				"-p", "RuntimeMaxSec=" + limit, "--"}, run...)...)
	case "launchd":
		cmd = exec.Command(
			"launchctl",
			append([]string{"submit", "-l", "org.bitcart.job." + id, "--"}, run...)...)
	default:
		cmd = exec.Command(run[0], run[1:]...)
		cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
		if err := cmd.Start(); err != nil {
			return err
		}
		return cmd.Process.Release()
	}
	return cmd.Run()
}

func tailLines(b []byte, n int) []byte {
	if n == 0 {
		return nil
	}
	i := len(b)
	if i > 0 && b[i-1] == '\n' {
		i--
	}
	for count := 0; i > 0; i-- {
		if b[i-1] == '\n' {
			if count++; count == n {
				break
			}
		}
	}
	return b[i:]
}

func readTail(path string, limit int64) []byte {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return nil
	}
	start := max(st.Size()-limit, 0)
	buf, _ := io.ReadAll(io.NewSectionReader(f, start, st.Size()-start))
	return buf
}

func jobStatusVerb(a args) *apiError {
	id := a["id"]
	if !reJobID.MatchString(id) {
		return invalid("id", "id is not a job id")
	}
	n := defaultLogLines
	if lines, ok := a["log_lines"]; ok && lines != "all" {
		var err error
		if n, err = strconv.Atoi(lines); err != nil || n < 0 {
			return invalid("log_lines", "log_lines must be a number or all")
		}
	}
	dir := filepath.Join(jobsDir, id)
	if _, err := os.Stat(filepath.Join(dir, "status.json")); err != nil {
		return fail("not_found", "no such job")
	}
	auditJob = id
	st := refreshJob(id)
	if st == nil {
		return fail("internal", "unreadable job status")
	}
	logPath := filepath.Join(dir, "log")
	var logTail []byte
	logComplete := true
	if n == 0 {
		if info, err := os.Stat(logPath); err == nil {
			logComplete = info.Size() == 0
		}
	} else {
		snapshot := readTail(logPath, maxLogBytes)
		logTail = snapshot
		if a["log_lines"] != "all" {
			logTail = tailLines(snapshot, n)
		}
		logComplete = len(snapshot) < maxLogBytes && len(logTail) == len(snapshot)
	}
	var result json.RawMessage
	if raw, err := os.ReadFile(filepath.Join(dir, "result.json")); err == nil && json.Valid(raw) {
		result = raw
	}
	data := struct {
		ID string `json:"id"`
		jobStatus
		Result      json.RawMessage `json:"result"`
		LogBytes    int             `json:"log_bytes"`
		LogComplete bool            `json:"log_complete"`
	}{ID: id, jobStatus: *st, Result: result, LogBytes: len(logTail), LogComplete: logComplete}
	if data.Result == nil {
		data.Result = json.RawMessage("null")
	}
	send(reply{OK: true, Data: data}, logTail)
	return nil
}

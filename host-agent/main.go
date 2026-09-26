package main

import (
	"bufio"
	"bytes"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"io"
	"log/syslog"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	protocol         = 1
	maxRequest       = 64 << 10
	requestTimeout   = 10 * time.Second
	jobStartGrace    = 60
	keepJobs         = 50
	defaultLogLines  = 50
	maxLogBytes      = 16 << 20
	maxAgentLogBytes = 1 << 20
	jobSeconds       = 7200
	backupsDir       = "/var/lib/docker/volumes/backup_datadir/_data"
)

var reJobID = regexp.MustCompile(`^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{6}$`)

var (
	base, jobsDir, stateDir, lockFile, profileDir string
	deployName, agentToken                        string
	transport                                     = "unknown"
)

type apiError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
	Field   string `json:"field,omitempty"`
	JobID   string `json:"job_id,omitempty"`
}

func fail(code, message string) *apiError { return &apiError{Code: code, Message: message} }

func invalid(field, message string) *apiError {
	return &apiError{Code: "invalid_argument", Message: message, Field: field}
}

type reply struct {
	V     int       `json:"v"`
	OK    bool      `json:"ok"`
	Data  any       `json:"data,omitempty"`
	Error *apiError `json:"error,omitempty"`
}

var (
	out       sync.Mutex
	responded bool
	auditVerb = "invalid"
	auditJob  string
)

func marshal(v any) ([]byte, error) {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	err := enc.Encode(v)
	return buf.Bytes(), err
}

// send writes the one response line, then tail as raw bytes; later calls are ignored
func send(r reply, tail []byte) bool {
	out.Lock()
	defer out.Unlock()
	if responded {
		return false
	}
	responded = true
	r.V = protocol
	line, err := marshal(r)
	if err != nil {
		r, tail = reply{V: protocol, Error: fail("internal", "internal agent error")}, nil
		line, _ = marshal(r)
	}
	if r.Error != nil {
		audit(r.Error.Code)
	}
	os.Stdout.Write(append(line, tail...))
	return true
}

func audit(outcome string) {
	job := auditJob
	if job == "" {
		job = "-"
	}
	if w, err := syslog.New(syslog.LOG_INFO|syslog.LOG_USER, "bitcart-agent"); err == nil {
		w.Info("verb=" + auditVerb + " outcome=" + outcome + " job=" + job)
		w.Close()
	}
}

func readFields(r io.Reader) ([]string, *apiError) {
	br := bufio.NewReader(io.LimitReader(r, maxRequest+1))
	var fields []string
	size := 0
	for {
		b, err := br.ReadBytes(0)
		if size += len(b); size > maxRequest {
			return nil, fail("bad_request", "request too long")
		}
		if err != nil {
			return nil, fail("bad_request", "incomplete request")
		}
		if string(b) == "\x00" {
			break
		}
		fields = append(fields, string(b[:len(b)-1]))
	}
	if len(fields) == 0 {
		return nil, fail("bad_request", "empty request")
	}
	return fields, nil
}

func readRequestFile(path string) ([]string, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	fields, apiErr := readFields(f)
	if apiErr != nil {
		return nil, errors.New(apiErr.Message)
	}
	return fields, nil
}

func eachLine(path string, fn func(line string)) error {
	f, err := os.Open(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		fn(sc.Text())
	}
	return sc.Err()
}

func readHostConfig() error {
	err := eachLine(filepath.Join(base, ".deploy"), func(line string) {
		if val, ok := strings.CutPrefix(line, "NAME="); ok {
			deployName = val
		}
	})
	if err != nil {
		return err
	}
	return eachLine(filepath.Join(base, ".env"), func(line string) {
		key, val, _ := strings.Cut(line, "=")
		switch key {
		case "BITCART_AGENT_TOKEN":
			agentToken = val
		case "BITCART_AGENT_TRANSPORT":
			transport = val
		}
	})
}

// servicePath is the PATH for the agent and its jobs: service managers start it with one that may not include docker
func servicePath() string {
	if runtime.GOOS == "darwin" {
		home := os.Getenv("HOME")
		return "/opt/homebrew/bin:/usr/local/bin:" + home + "/.docker/bin:" + home + "/.orbstack/bin:/usr/bin:/bin:/usr/sbin:/sbin"
	}
	return "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
}

func setup() {
	os.Setenv("PATH", servicePath())
	exe, err := os.Executable()
	if err == nil {
		base, err = filepath.EvalSymlinks(filepath.Dir(exe))
	}
	if err != nil {
		os.Exit(1)
	}
	os.Setenv("BITCART_BASE_DIRECTORY", base)
	stateDir = filepath.Join(base, ".agent")
	jobsDir = filepath.Join(stateDir, "jobs")
	lockFile = filepath.Join(stateDir, "lock")
	profileDir = os.Getenv("BITCART_AGENT_PROFILE_DIR")
	if os.MkdirAll(jobsDir, 0o700) == nil {
		logPath := filepath.Join(stateDir, "agent.log")
		if st, err := os.Stat(logPath); err == nil && st.Size() > maxAgentLogBytes {
			os.Rename(logPath, logPath+".1")
		}
		if f, err := os.OpenFile(logPath, os.O_WRONLY|os.O_APPEND|os.O_CREATE, 0o600); err == nil {
			redirectStderr(f)
		}
	}
}

func readRequest() ([]string, *apiError) {
	timer := time.AfterFunc(requestTimeout, func() {
		if send(reply{Error: fail("bad_request", "request timed out")}, nil) {
			os.Exit(0)
		}
	})
	fields, err := readFields(os.Stdin)
	if !timer.Stop() {
		select {}
	}
	if err != nil {
		return nil, err
	}
	return fields, checkAuth(fields)
}

func handleRequest(fields []string) *apiError {
	if readHostConfig() != nil {
		return fail("internal", "could not read the host configuration")
	}
	if len(fields) == 0 {
		var err *apiError
		if fields, err = readRequest(); err != nil {
			return err
		}
	}
	name := fields[0]
	v, ok := verbs[name]
	if !ok {
		return fail("unknown_verb", "unknown verb")
	}
	auditVerb = name
	args, err := parseArgs(v, fields[1:])
	if err != nil {
		return err
	}
	if v.respond != nil {
		return v.respond(args)
	}
	return startJob(name, fields)
}

func checkAuth(fields []string) *apiError {
	if agentToken == "" {
		return nil
	}
	var auth string
	for _, f := range fields[1:] {
		if v, ok := strings.CutPrefix(f, "auth="); ok {
			auth = v
		}
	}
	if subtle.ConstantTimeCompare([]byte(auth), []byte(agentToken)) != 1 {
		return fail("unauthorized", "authentication failed")
	}
	return nil
}

func writeJobResult(pairs []string) error {
	path := os.Getenv("BITCART_JOB_RESULT")
	if path == "" {
		return nil
	}
	if len(pairs)%2 != 0 {
		return errors.New("usage: bitcart-agent --job-result KEY VALUE [KEY VALUE...]")
	}
	result := map[string]any{}
	for i := 0; i < len(pairs); i += 2 {
		result[pairs[i]] = pairs[i+1]
		if n, err := strconv.ParseUint(pairs[i+1], 10, 64); err == nil {
			result[pairs[i]] = n
		}
	}
	data, err := marshal(result)
	if err != nil {
		return err
	}
	return writeFileAtomic(path, data)
}

func main() {
	if len(os.Args) >= 2 && os.Args[1] == "--job-result" {
		if err := writeJobResult(os.Args[2:]); err != nil {
			os.Stderr.WriteString(err.Error() + "\n")
			os.Exit(1)
		}
		return
	}
	setup()
	if len(os.Args) == 3 && os.Args[1] == "--run-job" {
		runJob(os.Args[2])
		return
	}
	defer func() {
		if recover() != nil {
			send(reply{Error: fail("internal", "internal agent error")}, nil)
		}
	}()
	if err := handleRequest(os.Args[1:]); err != nil {
		send(reply{Error: err}, nil)
	}
}

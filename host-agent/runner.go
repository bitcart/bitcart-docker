package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"syscall"
	"time"
)

func holdPidFile(dir string) (*os.File, error) {
	f, err := os.CreateTemp(dir, "pid.*")
	if err != nil {
		return nil, err
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX); err != nil {
		return nil, err
	}
	if _, err := f.WriteString(strconv.Itoa(os.Getpid()) + "\n"); err != nil {
		return nil, err
	}
	return f, os.Rename(f.Name(), filepath.Join(dir, "pid"))
}

func runJob(id string) {
	if detectExecutor() == "launchd" {
		defer exec.Command("launchctl", "remove", "org.bitcart.job."+id).Run()
	}
	dir := filepath.Join(jobsDir, id)
	st, err := readStatus(id)
	if err != nil {
		return
	}
	if _, err := os.Stat(filepath.Join(dir, "pid")); err == nil || st.State != "running" {
		return
	}
	pidFile, err := holdPidFile(dir)
	if err != nil {
		return
	}
	defer pidFile.Close()
	updateStatus(id, func(s *jobStatus) { s.Started = now() })
	if readHostConfig() != nil {
		return
	}
	fields, err := readRequestFile(filepath.Join(dir, "request.bin"))
	if err != nil {
		return
	}
	v, ok := verbs[fields[0]]
	if !ok {
		return
	}
	a, apiErr := parseArgs(v, fields[1:])
	if apiErr != nil {
		return
	}
	var env []string
	for key, val := range a {
		if v.envKeys != nil && v.envKeys.MatchString(key) {
			env = append(env, key+"="+val)
		}
	}
	argv := v.command(a)
	if v.loadEnv {
		argv = append(
			[]string{
				"bash",
				"-c",
				`. ./helpers.sh && load_env || exit 1; exec env "$@"`,
				"bitcart-job",
			},
			append(env, argv...)...)
		env = nil
	}
	os.Setenv("BITCART_JOB_RESULT", filepath.Join(dir, "result.json"))
	if os.Getenv("HOME") == "" {
		os.Setenv("HOME", "/root")
	}
	syscall.Umask(0o022)
	logFile, err := os.Create(filepath.Join(dir, "log"))
	if err != nil {
		return
	}
	cmd := exec.Command(argv[0], argv[1:]...)
	cmd.Dir, cmd.Env, cmd.Stdout, cmd.Stderr = base, append(os.Environ(), env...), logFile, logFile
	rc, timedOut := runGroup(cmd, time.Duration(jobSeconds)*time.Second, 30*time.Second)
	logFile.Close()
	releaseLock(id)
	updateStatus(id, func(s *jobStatus) {
		s.Finished, s.ExitCode = now(), &rc
		switch {
		case timedOut:
			s.State, s.Reason = "failed", "timeout"
		case rc == 0:
			s.State = "done"
		default:
			s.State, s.Reason = "failed", "exit"
		}
	})
}

func runGroup(cmd *exec.Cmd, limit, grace time.Duration) (rc int, timedOut bool) {
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	if cmd.Start() != nil {
		return 127, false
	}
	group := -cmd.Process.Pid
	killed := make(chan struct{})
	watchdog := time.AfterFunc(limit, func() {
		defer close(killed)
		syscall.Kill(group, syscall.SIGTERM)
		deadline := time.Now().Add(grace)
		for syscall.Kill(group, 0) == nil && time.Now().Before(deadline) {
			time.Sleep(100 * time.Millisecond)
		}
		syscall.Kill(group, syscall.SIGKILL)
	})
	cmd.Wait()
	if timedOut = !watchdog.Stop(); timedOut {
		<-killed
	}
	rc = cmd.ProcessState.ExitCode()
	if status, ok := cmd.ProcessState.Sys().(syscall.WaitStatus); ok && status.Signaled() {
		rc = 128 + int(status.Signal())
	}
	return rc, timedOut
}

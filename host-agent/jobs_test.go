package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"
)

func TestAJobRunsItsScriptOutsideTheAgentAndRecordsTheOutcome(t *testing.T) {
	a := newAgent(t)
	id := a.startJob("restart")
	a.waitJob(id)
	if a.state(id) != "done" {
		t.Fatalf("state = %s", a.state(id))
	}
	a.mustHaveLines("restart.sh", "script=restart.sh", "cwd="+a.base, "umask=0022")
	if a.exists(".agent/lock") {
		t.Error("the lock is still held")
	}
	r := a.ok(a.send("job_status", "id="+id))
	for key, want := range map[string]string{
		"id": id, "verb": "restart", "state": "done", "exit_code": "0", "result": "null", "reason": "<missing>", "log_complete": "true",
	} {
		if got := r.str(key); got != want {
			t.Errorf("%s = %s, want %s", key, got, want)
		}
	}
	if r.Data["finished"].(float64) < r.Data["created"].(float64) {
		t.Error("finished before created")
	}
	if string(r.tail) != "running restart.sh\nfinished restart.sh\n" {
		t.Errorf("log = %q", r.tail)
	}
}

func TestJobFilesArePrivate(t *testing.T) {
	a := newAgent(t)
	id := a.startJob("restart")
	a.waitJob(id)
	st, err := os.Stat(a.path(".agent/jobs", id))
	if err != nil {
		t.Fatal(err)
	}
	if st.Mode().Perm() != 0o700 {
		t.Errorf("the job directory has mode %v", st.Mode().Perm())
	}
}

func TestEachVerbRunsItsOwnScript(t *testing.T) {
	a := newAgent(t)
	for _, c := range []struct {
		request []string
		script  string
	}{
		{[]string{"reload"}, "start.sh"},
		{[]string{"cleanup"}, "cleanup.sh"},
		{[]string{"update"}, "update.sh"},
		{[]string{"update", "channel=stable"}, "update.sh"},
		{[]string{"update", "channel=staging"}, "install-master.sh"},
	} {
		os.RemoveAll(a.path("out"))
		a.waitJob(a.startJob(c.request...))
		if !a.exists("out/" + c.script) {
			t.Errorf("%v did not run %s", c.request, c.script)
		}
	}
}

func TestAFailingScriptMarksTheJobFailed(t *testing.T) {
	a := newAgent(t)
	a.write("fail", "3\n")
	id := a.startJob("cleanup")
	a.waitJob(id)
	r := a.send("job_status", "id="+id)
	if r.str("state") != "failed" || r.str("reason") != "exit" || r.str("exit_code") != "3" {
		t.Errorf("unexpected status %s", r.raw)
	}
	if a.exists(".agent/lock") {
		t.Error("the lock is still held")
	}
}

func TestOneJobAtATimeBusyNamesTheRunningJob(t *testing.T) {
	a := newAgent(t)
	a.write("hold", "")
	first := a.startJob("restart")
	r := a.fails(a.send("backup", "BACKUP_PROVIDER=local"), "busy")
	if r.Error.JobID != first {
		t.Errorf("busy names %s, want %s", r.Error.JobID, first)
	}
	if got := a.send("capabilities").str("running_job"); got != first {
		t.Errorf("running_job = %s", got)
	}
	if got := a.send("job_status", "id="+first).str("state"); got != "running" {
		t.Errorf("state = %s", got)
	}
	os.Remove(a.path("hold"))
	a.waitJob(first)
	second := a.startJob("cleanup")
	if second == first {
		t.Error("the job id was reused")
	}
}

func TestALockHeldByADeadJobIsFreedAndTheJobMarkedLost(t *testing.T) {
	a := newAgent(t)
	id := "20260923T140651Z-aaaaaa"
	a.write(".agent/lock", id+"\n")
	a.writeStatus(id, "running", "update", time.Now().Unix()-600)
	a.write(".agent/jobs/"+id+"/pid", "999999\n")
	job := a.startJob("restart")
	if a.state(id) != "lost" {
		t.Errorf("state = %s", a.state(id))
	}
	a.waitJob(job)
	if a.state(job) != "done" {
		t.Errorf("state = %s", a.state(job))
	}
}

func TestJobStatusNoticesALostJob(t *testing.T) {
	a := newAgent(t)
	id := "20260923T140651Z-bbbbbb"
	a.writeStatus(id, "running", "backup", time.Now().Unix()-600)
	a.write(".agent/jobs/"+id+"/pid", strconv.Itoa(os.Getpid())+"\n")
	if got := a.send("job_status", "id="+id).str("state"); got != "lost" {
		t.Errorf("state = %s", got)
	}
}

func TestAJobThatIsStillStartingIsNotLost(t *testing.T) {
	a := newAgent(t)
	id := "20260923T140651Z-cccccc"
	a.write(".agent/lock", id+"\n")
	a.writeStatus(id, "running", "update", time.Now().Unix())
	r := a.fails(a.send("restart"), "busy")
	if r.Error.JobID != id {
		t.Errorf("busy names %s", r.Error.JobID)
	}
}

func TestALockWithoutAJobIDIsStale(t *testing.T) {
	a := newAgent(t)
	a.write(".agent/lock", "")
	a.waitJob(a.startJob("restart"))
}

func TestADeadJobPastTheTimeLimitIsATimeout(t *testing.T) {
	a := newAgent(t)
	id := "20260923T140651Z-dddddd"
	a.writeStatus(id, "running", "update", time.Now().Unix()-7300)
	r := a.send("job_status", "id="+id)
	if r.str("state") != "failed" || r.str("reason") != "timeout" {
		t.Errorf("unexpected status %s", r.raw)
	}
}

func TestRunGroupStopsAJobThatRunsTooLong(t *testing.T) {
	t.Parallel()
	childFile := filepath.Join(t.TempDir(), "child")
	cmd := exec.Command("bash", "-c", "sleep 300 &\necho $! >\"$1\"\nwait\n", "test", childFile)
	start := time.Now()
	rc, timedOut := runGroup(cmd, 500*time.Millisecond, 10*time.Second)
	if elapsed := time.Since(start); elapsed > 5*time.Second {
		t.Errorf("runGroup returned after %v although the job exited on SIGTERM", elapsed)
	}
	if !timedOut || rc != 143 {
		t.Errorf("rc = %d, timedOut = %v", rc, timedOut)
	}
	requireGone(t, childFile)
}

func TestRunGroupKillsAChildThatIgnoresSIGTERM(t *testing.T) {
	t.Parallel()
	childFile := filepath.Join(t.TempDir(), "child")
	cmd := exec.Command(
		"bash",
		"-c",
		"(trap '' TERM; exec sleep 300) &\necho $! >\"$1\"\nwait\n",
		"test",
		childFile,
	)
	start := time.Now()
	rc, timedOut := runGroup(cmd, 500*time.Millisecond, 500*time.Millisecond)
	if elapsed := time.Since(start); elapsed < time.Second {
		t.Errorf("runGroup returned after %v, before the child was killed", elapsed)
	}
	if !timedOut || rc != 143 {
		t.Errorf("rc = %d, timedOut = %v", rc, timedOut)
	}
	requireGone(t, childFile)
}

func requireGone(t *testing.T, pidFile string) {
	t.Helper()
	raw, err := os.ReadFile(pidFile)
	if err != nil {
		t.Fatal(err)
	}
	pid, err := strconv.Atoi(strings.TrimSpace(string(raw)))
	if err != nil {
		t.Fatal(err)
	}
	for range 50 {
		if !processAlive(pid) {
			return
		}
		time.Sleep(100 * time.Millisecond)
	}
	syscall.Kill(pid, syscall.SIGKILL)
	t.Error("the job's child process survived")
}

func processAlive(pid int) bool {
	if syscall.Kill(pid, 0) != nil {
		return false
	}
	stat, err := os.ReadFile(fmt.Sprintf("/proc/%d/stat", pid))
	return err != nil || !strings.Contains(string(stat), ") Z ")
}

func TestBackupSettingsReachTheScriptVerbatimAndByteExact(t *testing.T) {
	a := newAgent(t)
	secret := "wJalr/K7MD+bPx=EX$(id)`id`;\"'"
	id := a.startJob(
		"backup",
		"BACKUP_PROVIDER=s3",
		"BACKUP_NAME=20260923-shop",
		"S3_BUCKET=shop-backups",
		"S3_PATH=daily/x",
		"S3_ACCESS_KEY_ID=AKIAEXAMPLE",
		"S3_SECRET_ACCESS_KEY="+secret,
		"S3_DEFAULT_REGION=us-east-1",
		"S3_ENDPOINT_URL=https://s3.example.com:9000/",
		"S3_STORAGE_CLASS=GLACIER",
		"BACKUP_ENCRYPTION=true",
	)
	a.waitJob(id)
	a.mustHaveLines(
		"backup.sh",
		"env BACKUP_PROVIDER=s3",
		"env BACKUP_NAME=20260923-shop",
		"env BACKUP_ENCRYPTION=true",
		"env S3_BUCKET=shop-backups",
		"env S3_PATH=daily/x",
		"env S3_SECRET_ACCESS_KEY="+secret,
		"env S3_STORAGE_CLASS=GLACIER",
		"env S3_ENDPOINT_URL=https://s3.example.com:9000/",
		"env BITCART_JOB_RESULT="+a.path(".agent/jobs", id, "result.json"),
	)
	a.mustHaveLines(
		"backup.sh",
		"env S3_ACCESS_KEY_ID=AKIAEXAMPLE",
		"env S3_DEFAULT_REGION=us-east-1",
		"env PATH="+servicePath(),
	)
	if args := a.args("backup.sh"); len(args) != 0 {
		t.Errorf("args = %v", args)
	}
	result, _ := a.send("job_status", "id="+id).Data["result"].(map[string]any)
	if result["filename"] != "20260923-shop.tar.zst" || result["size"] != float64(13336) {
		t.Errorf("result = %v", result)
	}
}

func TestRestorePassesTheArchivePath(t *testing.T) {
	a := newAgent(t)
	a.waitJob(a.startJob("restore", "name=20260923-shop.tar.zst.enc"))
	want := []string{"--delete-backup", filepath.Join(backupsDir, "20260923-shop.tar.zst.enc")}
	if got := a.args("restore.sh"); !slices.Equal(got, want) {
		t.Errorf("args = %q", got)
	}
}

func TestReconfigureKeepsExistingSettingsAndAppliesTheRequestedOnes(t *testing.T) {
	a := newAgent(t)
	a.write(".deploy", "NAME=shop\n")
	a.waitJob(
		a.startJob(
			"reconfigure",
			"BITCART_HOST=new.example.com",
			"BITCART_REVERSEPROXY=nginx",
			"BITCART_CRYPTOS=btc,ltc",
			"BITCART_INSTALL=all",
			"BITCART_ADDITIONAL_COMPONENTS=tor",
			"BTC_NETWORK=mainnet",
			"LTC_NETWORK=testnet",
			"BTC_LIGHTNING=true",
			"NEWCOIN_NETWORK=testnet",
		),
	)
	if got := a.args("setup.sh"); !slices.Equal(got, []string{"--name", "shop"}) {
		t.Errorf("args = %q", got)
	}
	a.mustHaveLines(
		"setup.sh",
		"env BITCART_HOST=new.example.com",
		"env BITCART_REVERSEPROXY=nginx",
		"env BITCART_CRYPTOS=btc,ltc",
		"env BITCART_INSTALL=all",
		"env BITCART_ADDITIONAL_COMPONENTS=tor",
		"env BTC_NETWORK=mainnet",
		"env BTC_LIGHTNING=true",
		"env LTC_NETWORK=testnet",
		"env NEWCOIN_NETWORK=testnet",
		"env BITCART_LETSENCRYPT_EMAIL=me@example.com",
	)
}

func TestJobStatusSendsTheRequestedLogTailAsRawBytes(t *testing.T) {
	a := newAgent(t)
	a.script(
		"cleanup.sh",
		"for i in 1 2 3 4 5; do echo \"line $i\"; done\nprintf 'binary \\377\\001 end\\n'\n",
	)
	id := a.startJob("cleanup")
	a.waitJob(id)
	log := []byte(a.read(".agent/jobs/" + id + "/log"))
	r := a.send("job_status", "id="+id, "log_lines=2")
	if r.str("log_bytes") != strconv.Itoa(len(r.tail)) || r.str("log_complete") != "false" {
		t.Errorf("unexpected status %s", r.raw)
	}
	if want := "line 5\nbinary \xff\x01 end\n"; string(r.tail) != want {
		t.Errorf("tail = %q", r.tail)
	}
	r = a.send("job_status", "id="+id, "log_lines=all")
	if !bytes.Equal(r.tail, log) || r.str("log_complete") != "true" {
		t.Errorf("unexpected full log %q", r.raw)
	}
	r = a.send("job_status", "id="+id, "log_lines=0")
	if r.str("log_bytes") != "0" || len(r.tail) != 0 {
		t.Errorf("unexpected reply %q", r.raw)
	}
}

func TestRetentionKeepsThe50NewestJobsAndNeverDeletesRunningOnes(t *testing.T) {
	a := newAgent(t)
	running := "20200101T000000Z-000000"
	for i := 10; i <= 69; i++ {
		a.write(
			fmt.Sprintf(".agent/jobs/20250101T0000%dZ-abcdef/status.json", i),
			`{"state":"done","verb":"restart","created":1}`+"\n",
		)
	}
	a.writeStatus(running, "running", "restart", time.Now().Unix())
	a.waitJob(a.startJob("restart"))
	if n := a.jobDirs(); n != 52 {
		t.Errorf("%d job directories", n)
	}
	for rel, want := range map[string]bool{running: true, "20250101T000069Z-abcdef": true, "20250101T000019Z-abcdef": false} {
		if a.exists(".agent/jobs/"+rel) != want {
			t.Errorf("%s exists: %v", rel, !want)
		}
	}
}

func TestAnUpdateJobSurvivesTheAgentBinaryBeingReplacedWhileItRuns(t *testing.T) {
	a := newAgent(t)
	a.script("update.sh", fmt.Sprintf(
		"cp %s %s\nmv -f %[2]s %s\necho replaced\n",
		shellQuote(
			agentBin,
		),
		shellQuote(a.path("bitcart-agent.new")),
		shellQuote(a.path("bitcart-agent")),
	))
	if err := os.Link(a.path("bitcart-agent"), a.path("bitcart-agent.v1")); err != nil {
		t.Fatal(err)
	}
	id := a.startJob("update")
	a.waitJob(id)
	before, _ := os.Stat(a.path("bitcart-agent.v1"))
	after, _ := os.Stat(a.path("bitcart-agent"))
	if os.SameFile(before, after) {
		t.Error("the binary was not replaced")
	}
	if got := a.ok(a.send("job_status", "id="+id)).str("state"); got != "done" {
		t.Errorf("state = %s", got)
	}
	if a.exists(".agent/lock") {
		t.Error("the lock is still held")
	}
	a.ok(a.send("ping"))
}

func TestConcurrentRequestsStartExactlyOneJob(t *testing.T) {
	a := newAgent(t)
	a.write("hold", "")
	outputs := make([][]byte, 12)
	var wg sync.WaitGroup
	for i := range outputs {
		wg.Go(func() {
			cmd := a.command()
			cmd.Stdin = strings.NewReader("restart\x00\x00")
			outputs[i], _ = cmd.Output()
		})
	}
	wg.Wait()
	var started []string
	for _, out := range outputs {
		r := a.parse(out)
		if r.OK {
			started = append(started, r.str("job_id"))
		} else if r.Error.Code != "busy" {
			t.Errorf("unexpected reply %s", out)
		}
	}
	a.started = append(a.started, started...)
	if len(started) != 1 || a.jobDirs() != 1 {
		t.Errorf("%d jobs started, %d job directories", len(started), a.jobDirs())
	}
	os.Remove(a.path("hold"))
}

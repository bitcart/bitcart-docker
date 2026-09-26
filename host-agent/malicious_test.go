package main

import (
	"os"
	"strings"
	"testing"
	"time"
)

func (a *testAgent) notPwned() {
	a.t.Helper()
	if a.exists("pwned") || a.exists(".agent/lock") || a.jobDirs() != 0 {
		a.t.Error("a rejected request had an effect")
	}
}

func TestArgumentsMustBeKnownForTheVerb(t *testing.T) {
	a := newAgent(t)
	if r := a.fails(a.send("restart", "channel=stable"), "invalid_argument"); r.Error.Field != "channel" {
		t.Errorf("field = %s", r.Error.Field)
	}
	if r := a.fails(a.send("backup", "BACKUP_PROVIDER=local", "host=example.com"), "invalid_argument"); r.Error.Field != "host" {
		t.Errorf("field = %s", r.Error.Field)
	}
	for _, key := range []string{"PATH", "BASH_ENV", "LD_PRELOAD", "x[$(touch pwned)]", "", "BACKUP_", "BACKUPS_X", "S3_bucket", "provider"} {
		a.fails(a.send("backup", "BACKUP_PROVIDER=local", key+"=1"), "invalid_argument")
	}
	for _, key := range []string{"BITCART_ENV_FILE", "BITCART_BASE_DIRECTORY", "BITCART_NETWORKS", "PATH", "host", "btc_network", "_NETWORK"} {
		a.fails(a.send("reconfigure", key+"=1"), "invalid_argument")
	}
	a.notPwned()
}

func TestDuplicateKeysAreRejected(t *testing.T) {
	a := newAgent(t)
	if r := a.fails(a.send("backup", "BACKUP_PROVIDER=local", "BACKUP_PROVIDER=s3"), "invalid_argument"); r.Error.Message != "duplicate argument" {
		t.Errorf("message = %s", r.Error.Message)
	}
	a.notPwned()
}

func TestFieldsWithoutEqualsAreRejected(t *testing.T) {
	a := newAgent(t)
	a.fails(a.send("backup", "BACKUP_PROVIDER"), "bad_request")
	a.notPwned()
}

func TestValuesAreSplitOnTheFirstEqualsOnly(t *testing.T) {
	a := newAgent(t)
	a.waitJob(a.startJob("backup", "BACKUP_PROVIDER=local", "BACKUP_NAME=a=b"))
	a.mustHaveLines("backup.sh", "env BACKUP_NAME=a=b")
}

func TestJobStatusOnlyAcceptsJobIDs(t *testing.T) {
	a := newAgent(t)
	a.fails(a.send("job_status"), "invalid_argument")
	for _, id := range []string{"../../etc", "20260923T140651Z-7f3a9c/../x", "20260923T140651Z-7F3A9C", "*", ""} {
		a.fails(a.send("job_status", "id="+id), "invalid_argument")
	}
	a.notPwned()
}

func TestLogLinesIsANumberOrAll(t *testing.T) {
	a := newAgent(t)
	for _, lines := range []string{"-1", "1e3", "0x10", "ten", ""} {
		a.fails(a.send("job_status", "id=20260923T140651Z-7f3a9c", "log_lines="+lines), "invalid_argument")
	}
	a.notPwned()
}

func TestControlBytesAreRejectedInValues(t *testing.T) {
	a := newAgent(t)
	r := a.fails(a.send("reconfigure", "BITCART_HOST=example.com\nBITCART_HOST=evil.com", "BITCART_REVERSEPROXY=nginx", "BITCART_CRYPTOS=btc", "BITCART_INSTALL=all"), "invalid_argument")
	if r.Error.Message != "control characters are not allowed" {
		t.Errorf("message = %s", r.Error.Message)
	}
	a.fails(a.send("backup", "BACKUP_PROVIDER=local", "BACKUP_NAME=a\x01"), "invalid_argument")
	a.fails(a.send("backup", "BACKUP_PROVIDER=s3", "S3_BUCKET=bucket", "S3_SECRET_ACCESS_KEY=abc\x7f"), "invalid_argument")
	a.fails(a.send("backup", "BACKUP_PROVIDER=s3", "S3_BUCKET=bucket", "S3_SECRET_ACCESS_KEY=abc\t"), "invalid_argument")
	a.notPwned()
}

func TestAMissingTerminatorIsAnIncompleteRequest(t *testing.T) {
	a := newAgent(t)
	for _, raw := range []string{"ping", "ping\x00", ""} {
		a.fails(a.sendRaw([]byte(raw)), "bad_request")
	}
}

func TestAnEmptyRequestIsRejected(t *testing.T) {
	a := newAgent(t)
	a.fails(a.sendRaw([]byte("\x00")), "bad_request")
}

func TestARequestAtTheSizeCapIsReadAndOneByteOverIsRejected(t *testing.T) {
	a := newAgent(t)
	prefix := "job_status\x00id="
	a.fails(a.sendRaw([]byte(prefix+strings.Repeat("a", maxRequest-len(prefix)-2)+"\x00\x00")), "invalid_argument")
	r := a.fails(a.sendRaw([]byte(prefix+strings.Repeat("a", maxRequest-len(prefix)-1)+"\x00\x00")), "bad_request")
	if r.Error.Message != "request too long" {
		t.Errorf("message = %s", r.Error.Message)
	}
}

func TestAStalledClientTimesOut(t *testing.T) {
	a := newAgent(t)
	stdin, writer, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	defer writer.Close()
	cmd := a.command()
	cmd.Stdin = stdin
	writer.WriteString("ping\x00")
	start := time.Now()
	out, _ := cmd.Output()
	stdin.Close()
	a.fails(a.parse(out), "bad_request")
	if elapsed := time.Since(start); elapsed < requestTimeout-time.Second || elapsed > requestTimeout+5*time.Second {
		t.Errorf("replied after %v", elapsed)
	}
}

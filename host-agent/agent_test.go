package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

var (
	agentBin        string
	agentBuildFlags []string
)

func TestMain(m *testing.M) {
	dir, err := os.MkdirTemp("", "bitcart-agent-bin")
	if err != nil {
		panic(err)
	}
	agentBin = filepath.Join(dir, "bitcart-agent")
	build := exec.Command("go", append(append([]string{"build"}, agentBuildFlags...), "-o", agentBin, ".")...)
	build.Stdout, build.Stderr = os.Stderr, os.Stderr
	if err := build.Run(); err != nil {
		panic(err)
	}
	warm := exec.Command(agentBin)
	warm.Stdin = strings.NewReader("ping\x00\x00")
	if out, err := warm.Output(); err != nil || len(out) == 0 {
		log, _ := os.ReadFile(filepath.Join(dir, ".agent", "agent.log"))
		panic(fmt.Sprintf("agent does not answer ping: %v\n%s", err, log))
	}
	code := m.Run()
	os.RemoveAll(dir)
	os.Exit(code)
}

const fakeScript = `#!/bin/bash
out="$BASE/out"
mkdir -p "$out"
{
    printf 'script=%s\n' "$SCRIPT"
    for arg in "$@"; do
        printf 'arg=%s\n' "$arg"
    done
    for name in BACKUP_PROVIDER BACKUP_NAME BACKUP_ENCRYPTION S3_BUCKET S3_PATH S3_STORAGE_CLASS S3_ACCESS_KEY_ID \
        S3_SECRET_ACCESS_KEY S3_DEFAULT_REGION S3_ENDPOINT_URL BITCART_HOST BITCART_REVERSEPROXY \
        BITCART_CRYPTOS BITCART_INSTALL BITCART_ADDITIONAL_COMPONENTS BTC_NETWORK BTC_LIGHTNING LTC_NETWORK NEWCOIN_NETWORK \
        BITCART_LETSENCRYPT_EMAIL BITCART_JOB_RESULT PATH; do
        if [ -n "${!name+x}" ]; then
            printf 'env %s=%s\n' "$name" "${!name}"
        fi
    done
    printf 'umask=%s\n' "$(umask)"
    printf 'cwd=%s\n' "$(pwd -P)"
} >"$out/$SCRIPT"
echo "running $SCRIPT"
while [ -f "$BASE/hold" ]; do sleep 0.1; done
if [ "$SCRIPT" = backup.sh ]; then
    "$BASE/bitcart-agent" --job-result filename "${BACKUP_NAME:-default}.tar.zst" size 13336
fi
if [ -f "$BASE/fail" ]; then
    exit "$(cat "$BASE/fail")"
fi
echo "finished $SCRIPT"
`

type testAgent struct {
	t       *testing.T
	base    string
	env     []string
	started []string
}

func newAgent(t *testing.T) *testAgent {
	t.Parallel()
	base, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	a := &testAgent{t: t, base: base, env: []string{
		"BITCART_AGENT_PROFILE_DIR=" + filepath.Join(base, "profile"),
	}}
	// A copy, not a hard link: macOS scans each new path on first launch, and deleting a test's path
	// mid-scan SIGKILLs pending launches of the same file from other tests
	binary, err := os.ReadFile(agentBin)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(a.path("bitcart-agent"), binary, 0o755); err != nil {
		t.Fatal(err)
	}
	for _, script := range []string{"restart.sh", "start.sh", "cleanup.sh", "update.sh", "install-master.sh", "backup.sh", "restore.sh", "setup.sh"} {
		a.script(script, "BASE="+shellQuote(base)+"\nSCRIPT="+script+"\n"+strings.TrimPrefix(fakeScript, "#!/bin/bash\n"))
	}
	a.write("helpers.sh", `load_env() {
    export BITCART_HOST=old.example.com BITCART_CRYPTOS=btc BITCART_LETSENCRYPT_EMAIL=me@example.com BTC_NETWORK=testnet
}
`)
	t.Cleanup(func() {
		os.Remove(a.path("hold"))
		for _, id := range a.started {
			a.waitJob(id)
		}
		if log, _ := os.ReadFile(a.path(".agent", "agent.log")); len(log) != 0 {
			t.Errorf("agent.log is not empty:\n%s", log)
		}
	})
	return a
}

func shellQuote(s string) string { return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'" }

func (a *testAgent) path(parts ...string) string {
	return filepath.Join(append([]string{a.base}, parts...)...)
}

func (a *testAgent) setEnv(kv string) { a.env = append(a.env, kv) }

func (a *testAgent) writeMode(rel, content string, mode os.FileMode) {
	path := a.path(rel)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		a.t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), mode); err != nil {
		a.t.Fatal(err)
	}
}

func (a *testAgent) write(rel, content string) { a.writeMode(rel, content, 0o644) }

func (a *testAgent) script(rel, body string) { a.writeMode(rel, "#!/bin/bash\n"+body, 0o755) }

func (a *testAgent) read(rel string) string {
	data, err := os.ReadFile(a.path(rel))
	if err != nil {
		a.t.Fatal(err)
	}
	return string(data)
}

func (a *testAgent) exists(rel string) bool {
	_, err := os.Lstat(a.path(rel))
	return err == nil
}

func (a *testAgent) command(args ...string) *exec.Cmd {
	cmd := exec.Command(a.path("bitcart-agent"), args...)
	cmd.Env = append(os.Environ(), a.env...)
	return cmd
}

type agentReply struct {
	raw, tail []byte
	V         int            `json:"v"`
	OK        bool           `json:"ok"`
	Data      map[string]any `json:"data"`
	Error     struct {
		Code    string `json:"code"`
		Message string `json:"message"`
		Field   string `json:"field"`
		JobID   string `json:"job_id"`
	} `json:"error"`
}

func (a *testAgent) parse(raw []byte) *agentReply {
	a.t.Helper()
	r := &agentReply{raw: raw}
	line, tail, found := bytes.Cut(raw, []byte("\n"))
	if !found {
		a.t.Fatalf("reply has no newline: %q", raw)
	}
	r.tail = tail
	if err := json.Unmarshal(line, r); err != nil {
		a.t.Fatalf("reply is not JSON: %q", raw)
	}
	return r
}

func (a *testAgent) sendRaw(input []byte) *agentReply {
	a.t.Helper()
	cmd := a.command()
	cmd.Stdin = bytes.NewReader(input)
	out, err := cmd.Output()
	if err != nil {
		a.t.Fatalf("agent failed: %v, reply: %q", err, out)
	}
	return a.parse(out)
}

func (a *testAgent) run(args ...string) *agentReply {
	a.t.Helper()
	out, err := a.command(args...).Output()
	if err != nil {
		a.t.Fatalf("agent failed: %v, reply: %q", err, out)
	}
	return a.parse(out)
}

func (a *testAgent) send(fields ...string) *agentReply {
	a.t.Helper()
	return a.sendRaw(encodeRequest(fields))
}

func (r *agentReply) str(key string) string {
	v, ok := r.Data[key]
	if !ok {
		return "<missing>"
	}
	if v == nil {
		return "null"
	}
	return fmt.Sprint(v)
}

func (r *agentReply) list(key string) string {
	items, _ := r.Data[key].([]any)
	var res []string
	for _, item := range items {
		res = append(res, fmt.Sprint(item))
	}
	return strings.Join(res, " ")
}

func (a *testAgent) ok(r *agentReply) *agentReply {
	a.t.Helper()
	if !r.OK || r.V != 1 {
		a.t.Fatalf("expected ok, got: %s", r.raw)
	}
	return r
}

func (a *testAgent) fails(r *agentReply, code string) *agentReply {
	a.t.Helper()
	if r.OK || r.V != 1 || r.Error.Code != code {
		a.t.Fatalf("expected error %s, got: %s", code, r.raw)
	}
	return r
}

func (a *testAgent) singleLine(r *agentReply) {
	a.t.Helper()
	if bytes.Count(r.raw, []byte("\n")) != 1 || !bytes.HasSuffix(r.raw, []byte("\n")) {
		a.t.Fatalf("expected exactly one line, got: %q", r.raw)
	}
}

func (a *testAgent) startJob(fields ...string) string {
	a.t.Helper()
	r := a.ok(a.send(fields...))
	id := r.str("job_id")
	if !reJobID.MatchString(id) {
		a.t.Fatalf("bad job id in %s", r.raw)
	}
	a.started = append(a.started, id)
	return id
}

func (a *testAgent) state(id string) string {
	a.t.Helper()
	var st jobStatus
	if err := json.Unmarshal([]byte(a.read(".agent/jobs/"+id+"/status.json")), &st); err != nil {
		a.t.Fatal(err)
	}
	return st.State
}

func (a *testAgent) writeStatus(id, state, verb string, created int64) {
	a.write(".agent/jobs/"+id+"/status.json", fmt.Sprintf(`{"state":%q,"verb":%q,"created":%d}`+"\n", state, verb, created))
}

func (a *testAgent) waitJob(id string) {
	a.t.Helper()
	for range 200 {
		if a.state(id) != "running" {
			return
		}
		time.Sleep(100 * time.Millisecond)
	}
	a.t.Fatalf("job %s is still running", id)
}

func (a *testAgent) jobDirs() int {
	entries, _ := os.ReadDir(a.path(".agent", "jobs"))
	return len(entries)
}

func (a *testAgent) outLines(script string) []string {
	return strings.Split(strings.TrimSuffix(a.read("out/"+script), "\n"), "\n")
}

func (a *testAgent) hasLine(script, line string) bool {
	for _, l := range a.outLines(script) {
		if l == line {
			return true
		}
	}
	return false
}

func (a *testAgent) mustHaveLines(script string, lines ...string) {
	a.t.Helper()
	for _, line := range lines {
		if !a.hasLine(script, line) {
			a.t.Errorf("%s output lacks %q:\n%s", script, line, a.read("out/"+script))
		}
	}
}

func (a *testAgent) args(script string) []string {
	var args []string
	for _, l := range a.outLines(script) {
		if v, ok := strings.CutPrefix(l, "arg="); ok {
			args = append(args, v)
		}
	}
	return args
}

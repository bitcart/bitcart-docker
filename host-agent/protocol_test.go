package main

import (
	"bytes"
	"os"
	"reflect"
	"strings"
	"testing"
)

const testToken = "0123456789abcdef0123456789abcdef"

func TestPingRepliesWithASingleJSONLine(t *testing.T) {
	a := newAgent(t)
	r := a.send("ping")
	a.singleLine(r)
	if string(r.raw) != `{"v":1,"ok":true,"data":{}}`+"\n" {
		t.Fatalf("unexpected reply %q", r.raw)
	}
}

func TestCapabilitiesDescribesTheAgentAndTheHost(t *testing.T) {
	a := newAgent(t)
	a.write("compose/metadata.json", `{"components": ["backend", "worker", "postgres", "redis", "nginx-https", "tor"],
 "cryptos": ["btc", "ltc"], "extra": "ignored"}`)
	a.write(".env", "BITCART_AGENT_TRANSPORT=systemd\n")
	r := a.ok(a.send("capabilities"))
	a.singleLine(r)
	host, _ := r.Data["host"].(map[string]any)
	runtimeInfo, _ := r.Data["runtime"].(map[string]any)
	hostReply := &agentReply{Data: host}
	for key, want := range map[string]string{
		"protocol":    "1",
		"transport":   "systemd",
		"executor":    detectExecutor(),
		"running_job": "null",
	} {
		if got := r.str(key); got != want {
			t.Errorf("%s = %s, want %s", key, got, want)
		}
	}
	for key, want := range map[string]string{
		"verbs":            "capabilities ping get_config job_status restart reload cleanup update backup restore reconfigure",
		"backup_providers": "local s3 scp",
		"update_channels":  "stable staging",
	} {
		if got := r.list(key); got != want {
			t.Errorf("%s = %s, want %s", key, got, want)
		}
	}
	if got := hostReply.list("components"); got != "backend worker postgres redis nginx-https tor" {
		t.Errorf("host.components = %s", got)
	}
	if got := hostReply.list("cryptos"); got != "btc ltc" {
		t.Errorf("host.cryptos = %s", got)
	}
	if len(host) != 2 {
		t.Errorf("host = %v", host)
	}
	if _, ok := r.Data["images"].(map[string]any); !ok {
		t.Errorf("images = %v", r.Data["images"])
	}
	_, hasEngine := runtimeInfo["engine"]
	_, hasVersion := runtimeInfo["version"]
	if len(runtimeInfo) != 2 || !hasEngine || !hasVersion {
		t.Errorf("runtime = %v", runtimeInfo)
	}
}

func TestCapabilitiesLeavesOutHostMetadataBeforeTheFirstGeneration(t *testing.T) {
	a := newAgent(t)
	r := a.ok(a.send("capabilities"))
	if _, ok := r.Data["host"]; ok {
		t.Error("host is present")
	}
	if r.str("transport") != "unknown" {
		t.Errorf("transport = %s", r.str("transport"))
	}
}

func TestGetConfigReturnsOnlySettingKeys(t *testing.T) {
	a := newAgent(t)
	a.write("profile/bitcart-env.sh", `#!/bin/bash
export BITCART_INSTALL="all"
export BITCART_REVERSEPROXY="nginx-https"
export BITCART_CRYPTOS="btc,ltc"
export BITCART_ADDITIONAL_COMPONENTS="tor"
export BITCART_AGENT_TOKEN="secret"
export PATH="/tmp"
`)
	a.write(".env", `BITCART_HOST=shop.example.com
BITCART_CRYPTOS=btc,ltc
BTC_NETWORK=testnet
BTC_LIGHTNING=true
NEWCOIN_NETWORK=testnet
BITCART_ADMIN_HOST=admin.example.com
BITCART_EXCLUDE_COMPONENTS=tor
CLOUDFLARE_TUNNEL_TOKEN=secret
`)
	r := a.ok(a.send("get_config"))
	settings, _ := r.Data["settings"].(map[string]any)
	want := map[string]any{
		"BITCART_ADDITIONAL_COMPONENTS": "tor", "BITCART_CRYPTOS": "btc,ltc", "BITCART_HOST": "shop.example.com",
		"BITCART_INSTALL": "all", "BITCART_REVERSEPROXY": "nginx-https", "BTC_LIGHTNING": "true", "BTC_NETWORK": "testnet",
		"NEWCOIN_NETWORK": "testnet",
	}
	if len(settings) != len(want) {
		t.Fatalf("settings = %v", settings)
	}
	for key, value := range want {
		if settings[key] != value {
			t.Errorf("%s = %v, want %v", key, settings[key], value)
		}
	}
}

func TestGetConfigReadsTheProfileOfANamedDeployment(t *testing.T) {
	a := newAgent(t)
	a.write(".deploy", "NAME=shop\n")
	a.write("profile/bitcart-env-shop.sh", "export BITCART_INSTALL=\"backend\"\n")
	a.write("profile/bitcart-env.sh", "export BITCART_INSTALL=\"all\"\n")
	r := a.ok(a.send("get_config"))
	if got := r.Data["settings"].(map[string]any)["BITCART_INSTALL"]; got != "backend" {
		t.Errorf("BITCART_INSTALL = %v", got)
	}
}

func TestGetConfigUnescapesTheProfile(t *testing.T) {
	a := newAgent(t)
	a.write("profile/bitcart-env.sh", "export BITCART_ADDITIONAL_COMPONENTS=\"tor,a\\\"b\\$c\\\\d\\`e it's\"\nexport BITCART_INSTALL=\"\"\n")
	settings := a.ok(a.send("get_config")).Data["settings"].(map[string]any)
	if got := settings["BITCART_ADDITIONAL_COMPONENTS"]; got != "tor,a\"b$c\\d`e it's" {
		t.Errorf("BITCART_ADDITIONAL_COMPONENTS = %q", got)
	}
	if got, ok := settings["BITCART_INSTALL"]; !ok || got != "" {
		t.Errorf("BITCART_INSTALL = %q", got)
	}
}

func TestGetConfigWithoutAProfileReturnsTheEnvFile(t *testing.T) {
	a := newAgent(t)
	a.write(".env", "BITCART_HOST=shop.example.com\n")
	settings := a.ok(a.send("get_config")).Data["settings"].(map[string]any)
	if len(settings) != 1 || settings["BITCART_HOST"] != "shop.example.com" {
		t.Errorf("settings = %v", settings)
	}
}

func TestGetConfigFailsOnAnUnreadableProfile(t *testing.T) {
	a := newAgent(t)
	a.write("profile/bitcart-env.sh", "export LONG=\""+strings.Repeat("x", 70<<10)+"\"\nexport BITCART_INSTALL=\"all\"\n")
	a.fails(a.send("get_config"), "internal")
}

func TestUnknownVerbsAreRejected(t *testing.T) {
	a := newAgent(t)
	r := a.fails(a.send("shutdown"), "unknown_verb")
	a.singleLine(r)
}

func TestJobStatusOfAMissingJobIsNotFound(t *testing.T) {
	a := newAgent(t)
	a.fails(a.send("job_status", "id=20260923T140651Z-7f3a9c"), "not_found")
}

func TestATokenMakesAuthMandatory(t *testing.T) {
	a := newAgent(t)
	a.write(".env", "BITCART_AGENT_TOKEN="+testToken+"\n")
	a.fails(a.send("ping"), "unauthorized")
	a.fails(a.send("ping", "auth=wrong"), "unauthorized")
	a.ok(a.send("ping", "auth="+testToken))
	a.fails(a.send("job_status", "auth="+testToken, "id=20260923T140651Z-7f3a9c"), "not_found")
}

func TestAnUnreadableDeployFailsClosed(t *testing.T) {
	a := newAgent(t)
	a.write(".deploy", "LONG="+strings.Repeat("x", 70<<10)+"\nNAME=shop\n")
	a.fails(a.send("ping"), "internal")
}

func TestAnUnreadableEnvFailsClosed(t *testing.T) {
	a := newAgent(t)
	a.write(".env", "LONG="+strings.Repeat("x", 70<<10)+"\nBITCART_AGENT_TOKEN="+testToken+"\n")
	a.fails(a.send("ping"), "internal")
	a.fails(a.send("ping", "auth="+testToken), "internal")
}

func TestArgumentsAreARequestThatNeedsNoToken(t *testing.T) {
	a := newAgent(t)
	a.write(".env", "BITCART_AGENT_TOKEN="+testToken+"\n")
	r := a.ok(a.run("ping"))
	a.singleLine(r)
	a.fails(a.run("job_status", "id=20260923T140651Z-7f3a9c"), "not_found")
	a.fails(a.run("backup", "PATH=x"), "invalid_argument")
	a.fails(a.run("nope"), "unknown_verb")
	a.fails(a.send("ping"), "unauthorized")
}

func TestImageLabelsAreParsedPerRole(t *testing.T) {
	got := parseImageLabels("backend|0.10.3.0|69d0575\nadmin|master|491de14\n\nbtc-daemon||\n")
	want := map[string]imageInfo{
		"backend":    {"0.10.3.0", "69d0575"},
		"admin":      {"master", "491de14"},
		"btc-daemon": {nil, nil},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("parseImageLabels = %v", got)
	}
}

func TestAuthIsCheckedBeforeAnythingElse(t *testing.T) {
	a := newAgent(t)
	a.write(".env", "BITCART_AGENT_TOKEN="+testToken+"\n")
	a.fails(a.send("exec id"), "unauthorized")
	a.fails(a.send("backup", "PATH=x"), "unauthorized")
}

func TestAnyTokenIsEnforced(t *testing.T) {
	a := newAgent(t)
	a.write(".env", "BITCART_AGENT_TOKEN=short\n")
	a.fails(a.send("ping"), "unauthorized")
	a.ok(a.send("ping", "auth=short"))
}

func TestAuthIsIgnoredWithoutAToken(t *testing.T) {
	a := newAgent(t)
	a.ok(a.send("ping", "auth=anything"))
}

func TestStrayErrorsNeverReachTheConnection(t *testing.T) {
	a := newAgent(t)
	cmd := a.command()
	cmd.Stdin = bytes.NewReader(encodeRequest([]string{"capabilities"}))
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatal(err)
	}
	r := a.ok(a.parse(out))
	a.singleLine(r)
}

func TestJobResultWritesAJSONObject(t *testing.T) {
	a := newAgent(t)
	a.setEnv("BITCART_JOB_RESULT=" + a.path("result.json"))
	cmd := a.command("--job-result", "filename", "20260923-shop.tar.zst.enc", "size", "13336000000", "provider", "local", "note", "-1")
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("%v: %s", err, out)
	}
	want := `{"filename":"20260923-shop.tar.zst.enc","note":"-1","provider":"local","size":13336000000}` + "\n"
	if got := a.read("result.json"); got != want {
		t.Errorf("result.json = %s", got)
	}
	if err := a.command("--job-result", "filename").Run(); err == nil {
		t.Error("an odd number of arguments was accepted")
	}
	if a.exists(".agent") {
		t.Error("--job-result touched the agent state")
	}
}

func TestJobResultDoesNothingOutsideAJob(t *testing.T) {
	a := newAgent(t)
	cmd := a.command("--job-result", "filename", "x")
	cmd.Env = append(cmd.Env, "BITCART_JOB_RESULT=")
	if out, err := cmd.CombinedOutput(); err != nil || len(out) != 0 {
		t.Fatalf("%v: %s", err, out)
	}
	entries, _ := os.ReadDir(a.base)
	for _, e := range entries {
		if strings.HasSuffix(e.Name(), ".json") {
			t.Errorf("unexpected %s", e.Name())
		}
	}
}

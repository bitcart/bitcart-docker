package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"slices"
	"strings"
)

type args map[string]string

type verb struct {
	keys    []string
	envKeys *regexp.Regexp
	loadEnv bool
	respond func(args) *apiError
	command func(args) []string
}

var (
	verbOrder = []string{
		"capabilities",
		"ping",
		"get_config",
		"job_status",
		"restart",
		"reload",
		"cleanup",
		"update",
		"backup",
		"restore",
		"reconfigure",
	}
	backupProviders = []string{"local", "s3", "scp"}
	updateChannels  = []string{"stable", "staging"}
	settingKeys     = regexp.MustCompile(
		`^(BITCART_(HOST|REVERSEPROXY|CRYPTOS|INSTALL|ADDITIONAL_COMPONENTS)|[A-Z0-9]+_(NETWORK|LIGHTNING))$`,
	)
)

func script(
	path string,
) func(args) []string {
	return func(args) []string { return []string{path} }
}

var verbs map[string]*verb

func init() {
	verbs = map[string]*verb{
		"capabilities": {respond: capabilities},
		"ping": {
			respond: func(args) *apiError { send(reply{OK: true, Data: struct{}{}}, nil); return nil },
		},
		"get_config": {respond: getConfig},
		"job_status": {keys: []string{"id", "log_lines"}, respond: jobStatusVerb},
		"restart":    {command: script("./restart.sh")},
		"reload":     {command: script("./start.sh")},
		"cleanup":    {command: script("./cleanup.sh")},
		"update": {
			keys: []string{"channel"},
			command: func(a args) []string {
				if a["channel"] == "staging" {
					return []string{"./install-master.sh"}
				}
				return []string{"./update.sh"}
			},
		},
		"backup": {
			envKeys: regexp.MustCompile(`^(BACKUP|S3|SCP)_[A-Z0-9_]+$`),
			command: script("./backup.sh"),
		},
		"restore": {keys: []string{"name"}, command: func(a args) []string {
			return []string{"./restore.sh", "--delete-backup", filepath.Join(backupsDir, a["name"])}
		}},
		"reconfigure": {
			envKeys: settingKeys,
			loadEnv: true,
			command: func(args) []string {
				if deployName != "" {
					return []string{"./setup.sh", "--name", deployName}
				}
				return []string{"./setup.sh"}
			},
		},
	}
}

func hasControl(s string) bool {
	return strings.IndexFunc(s, func(r rune) bool { return r < 0x20 || r == 0x7f }) >= 0
}

func parseArgs(v *verb, fields []string) (args, *apiError) {
	a := args{}
	for _, f := range fields {
		key, val, ok := strings.Cut(f, "=")
		if !ok {
			return nil, fail("bad_request", "argument without '='")
		}
		if key == "auth" {
			continue
		}
		if !slices.Contains(v.keys, key) && (v.envKeys == nil || !v.envKeys.MatchString(key)) {
			return nil, invalid(key, "unknown argument")
		}
		if _, dup := a[key]; dup {
			return nil, invalid(key, "duplicate argument")
		}
		if hasControl(val) {
			return nil, invalid(key, "control characters are not allowed")
		}
		a[key] = val
	}
	return a, nil
}

func commandOutput(name string, arg ...string) string {
	out, err := exec.Command(name, arg...).Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func nullable(s string) any {
	if s == "" {
		return nil
	}
	return s
}

type imageInfo struct {
	Version  any `json:"version"`
	Revision any `json:"revision"`
}

func runningImages() map[string]imageInfo {
	project := deployName
	if project == "" {
		project = "compose"
	}
	return parseImageLabels(
		commandOutput(
			"docker",
			"ps",
			"--filter",
			"label=com.docker.compose.project="+project,
			"--filter",
			"label=org.bitcart.image",
			"--format",
			`{{.Label "org.bitcart.image"}}|{{.Label "org.opencontainers.image.version"}}|{{.Label "org.opencontainers.image.revision"}}`,
		),
	)
}

func parseImageLabels(output string) map[string]imageInfo {
	images := map[string]imageInfo{}
	for line := range strings.Lines(output) {
		role, labels, _ := strings.Cut(strings.TrimSpace(line), "|")
		version, revision, _ := strings.Cut(labels, "|")
		if role != "" {
			images[role] = imageInfo{nullable(version), nullable(revision)}
		}
	}
	return images
}

func capabilities(args) *apiError {
	type runtimeInfo struct {
		Engine  any `json:"engine"`
		Version any `json:"version"`
	}
	type hostInfo struct {
		Components []string `json:"components"`
		Cryptos    []string `json:"cryptos"`
	}
	data := struct {
		Protocol        int                  `json:"protocol"`
		ScriptsVersion  any                  `json:"scripts_version"`
		Transport       string               `json:"transport"`
		Executor        string               `json:"executor"`
		Runtime         runtimeInfo          `json:"runtime"`
		Images          map[string]imageInfo `json:"images"`
		Verbs           []string             `json:"verbs"`
		BackupProviders []string             `json:"backup_providers"`
		UpdateChannels  []string             `json:"update_channels"`
		RunningJob      any                  `json:"running_job"`
		Host            *hostInfo            `json:"host,omitempty"`
	}{Protocol: protocol, Transport: transport, Executor: detectExecutor(), Verbs: verbOrder,
		BackupProviders: backupProviders, UpdateChannels: updateChannels}
	data.ScriptsVersion = nullable(
		commandOutput(
			"git",
			"-C",
			base,
			"-c",
			"safe.directory="+base,
			"rev-parse",
			"--short",
			"HEAD",
		),
	)
	version, components, _ := strings.Cut(commandOutput("docker", "version", "--format",
		"{{.Server.Version}} {{range .Server.Components}}{{.Name}},{{end}}"), " ")
	engine := ""
	if version != "" {
		engine = "docker"
		if strings.Contains(strings.ToLower(components), "podman") {
			engine = "podman"
		}
	}
	data.Runtime = runtimeInfo{nullable(engine), nullable(version)}
	data.Images = runningImages()
	data.RunningJob = nullable(runningJob())
	var meta hostInfo
	if raw, err := os.ReadFile(filepath.Join(base, "compose", "metadata.json")); err == nil &&
		json.Unmarshal(raw, &meta) == nil {
		data.Host = &meta
	}
	send(reply{OK: true, Data: data}, nil)
	return nil
}

var profileUnescaper = strings.NewReplacer(`\\`, `\`, `\$`, `$`, "\\`", "`", `\"`, `"`)

func getConfig(args) *apiError {
	settings := map[string]string{}
	parse := func(path string) error {
		return eachLine(path, func(line string) {
			key, val, ok := strings.Cut(strings.TrimPrefix(line, "export "), "=")
			if !ok || !settingKeys.MatchString(key) {
				return
			}
			if len(val) >= 2 && strings.HasPrefix(val, `"`) && strings.HasSuffix(val, `"`) {
				val = profileUnescaper.Replace(val[1 : len(val)-1])
			}
			settings[key] = val
		})
	}
	dir := profileDir
	if dir == "" && runtime.GOOS == "darwin" {
		if dir = os.Getenv("HOME"); dir == "" {
			dir = "/nonexistent"
		}
	} else if dir == "" {
		dir = "/etc/profile.d"
	}
	postfix := ""
	if deployName != "" {
		postfix = "-" + deployName
	}
	if parse(filepath.Join(dir, "bitcart-env"+postfix+".sh")) != nil ||
		parse(filepath.Join(base, ".env")) != nil {
		return fail("internal", "could not read the settings")
	}
	send(reply{OK: true, Data: map[string]any{"settings": settings}}, nil)
	return nil
}

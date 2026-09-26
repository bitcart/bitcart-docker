# shellcheck shell=bash

install_agent_binary() {
    local image=${BITCARTGEN_DOCKER_IMAGE:-bitcart/docker-compose-generator} os dir container binary
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    mkdir -p "$BITCART_BASE_DIRECTORY/.agent"
    chmod 700 "$BITCART_BASE_DIRECTORY/.agent"
    dir=$(mktemp -d "$BITCART_BASE_DIRECTORY/.agent/install.XXXXXX") || return 1
    binary="$dir/bitcart-agent-$os"
    if container=$(docker create "$image" 2>/dev/null); then
        docker cp "$container:/agent/bitcart-agent-$os" "$binary" >/dev/null 2>&1 && chmod +x "$binary"
        docker rm "$container" >/dev/null
    fi
    if [ -f "$binary" ] && printf 'ping\0\0' | "$binary" 2>/dev/null | head -n 1 | grep -q '^{"v":1,"ok":true'; then
        mv -f "$binary" "$BITCART_BASE_DIRECTORY/bitcart-agent"
        rm -rf "$dir"
        return 0
    fi
    rm -rf "$dir"
    if [ -x "$BITCART_BASE_DIRECTORY/bitcart-agent" ]; then
        echo "WARNING: could not install the host agent for $os from $image, keeping the installed one"
        return 0
    fi
    echo "Could not install the host agent for $os from $image"
    return 1
}

agent_resolve_transport() {
    local transport=${BITCART_AGENT_TRANSPORT:-auto}
    if [ "$transport" = auto ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            transport=launchd
        elif [ -d /run/systemd/system ] && command -v systemctl >/dev/null && command -v systemd-run >/dev/null &&
            command -v systemd-socket-activate >/dev/null; then
            transport=systemd
        elif [ "$BITCART_ENABLE_SSH" = true ]; then
            transport=ssh
        else
            transport=none
        fi
    fi
    echo "$transport"
}

resolve_agent_settings() {
    BITCART_AGENT_TRANSPORT=$(agent_resolve_transport)
    if [ "$BITCART_AGENT_TRANSPORT" = launchd ]; then
        BITCART_AGENT_TOKEN=${BITCART_AGENT_TOKEN:-$(openssl rand -hex 32)}
    else
        BITCART_AGENT_TOKEN=
    fi
    export BITCART_AGENT_TRANSPORT BITCART_AGENT_TOKEN
}

agent_service_name() {
    echo "bitcart-agent$SCRIPTS_POSTFIX"
}

agent_launchd_label() {
    echo "org.bitcart.agent$SCRIPTS_POSTFIX"
}

# update_authorized_keys FILE LINE COMMENT...: drops the keys with any of the given comments, then appends LINE
update_authorized_keys() {
    local file=$1 line=$2 tmp
    shift 2
    if [ ! -f "$file" ]; then
        if [ -z "$line" ]; then
            return 0
        fi
        mkdir -p "$(dirname "$file")"
        chmod 700 "$(dirname "$file")"
        touch "$file"
        chmod 600 "$file"
    fi
    tmp=$(mktemp "$file.XXXXXX")
    cp -p "$file" "$tmp"
    awk -v drop=" $* " 'index(drop, " " $NF " ") == 0' "$file" >"$tmp"
    if [ -n "$line" ]; then
        printf '%s\n' "$line" >>"$tmp"
    fi
    if cmp -s "$file" "$tmp"; then
        rm -f "$tmp"
    else
        mv -f "$tmp" "$file"
    fi
}

install_agent_systemd() {
    local service unit_file activate sh timeout chmod socket unit changed=false
    service=$(agent_service_name)
    unit_file="/etc/systemd/system/$service.service"
    socket="/run/bitcart$SCRIPTS_POSTFIX/agent.sock"
    activate=$(command -v systemd-socket-activate) || return 1
    sh=$(command -v sh) || return 1
    timeout=$(command -v timeout) || return 1
    chmod=$(command -v chmod) || return 1
    unit="[Unit]
Description=Bitcart host agent$SCRIPTS_POSTFIX
Documentation=https://github.com/bitcart/bitcart-docker#host-agent
After=network.target

[Service]
RuntimeDirectory=bitcart$SCRIPTS_POSTFIX
RuntimeDirectoryPreserve=yes
ExecStart=$activate --accept --inetd --listen=$socket $BITCART_BASE_DIRECTORY/bitcart-agent
ExecStartPost=$timeout 10 $sh -c 'until [ -S $socket ]; do sleep 0.1; done'
ExecStartPost=$chmod 0666 $socket
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target"
    if [ ! -f "$unit_file" ] || [ "$(cat "$unit_file")" != "$unit" ]; then
        printf '%s\n' "$unit" >"$unit_file"
        changed=true
    fi
    if ${SYSTEMD_RELOAD:-true}; then
        systemctl daemon-reload
        systemctl enable "$service"
        if $changed; then
            systemctl restart "$service"
        else
            systemctl start "$service"
        fi
    else
        systemctl --no-reload enable "$service"
    fi
    echo "Host agent installed as systemd service $service"
}

install_agent_launchd() {
    local label plist port content domain
    label=$(agent_launchd_label)
    plist="$HOME/Library/LaunchAgents/$label.plist"
    port=${BITCART_AGENT_PORT:-47123}
    content="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BITCART_BASE_DIRECTORY/bitcart-agent</string>
    </array>
    <key>inetdCompatibility</key>
    <dict>
        <key>Wait</key>
        <false/>
    </dict>
    <key>Sockets</key>
    <dict>
        <key>Listeners</key>
        <dict>
            <key>SockNodeName</key>
            <string>127.0.0.1</string>
            <key>SockServiceName</key>
            <string>$port</string>
        </dict>
    </dict>
</dict>
</plist>"
    mkdir -p "$(dirname "$plist")"
    domain="gui/$(id -u)"
    launchctl print "$domain" >/dev/null 2>&1 || domain="user/$(id -u)"
    if [ ! -f "$plist" ] || [ "$(cat "$plist")" != "$content" ]; then
        printf '%s\n' "$content" >"$plist"
        launchctl bootout "$domain/$label" >/dev/null 2>&1 || true
    fi
    if ! launchctl print "$domain/$label" >/dev/null 2>&1; then
        launchctl bootstrap "$domain" "$plist" || return 1
    fi
    echo "Host agent installed as launchd agent $label on 127.0.0.1:$port"
}

install_agent_ssh() {
    local dir line comment
    comment=$(agent_service_name)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "The ssh host agent transport is not supported on macOS, use launchd"
        return 1
    fi
    command -v ssh-keygen >/dev/null || return 1
    dir="$BITCART_BASE_DIRECTORY/.agent/ssh"
    mkdir -p "$dir"
    if [ ! -f "$dir/id_ed25519" ]; then
        ssh-keygen -q -t ed25519 -N "" -C "$comment" -f "$dir/id_ed25519" || return 1
    fi
    chmod 755 "$dir"
    chmod 644 "$dir/id_ed25519"
    line="restrict,command=\"$BITCART_BASE_DIRECTORY/bitcart-agent\" $(cut -d' ' -f1,2 "$dir/id_ed25519.pub") $comment"
    update_authorized_keys /root/.ssh/authorized_keys "$line" "$comment"
    echo "Host agent installed in /root/.ssh/authorized_keys"
}

install_agent_manual() {
    echo "Host agent installed at $BITCART_BASE_DIRECTORY/bitcart-agent, serve it yourself: https://github.com/bitcart/bitcart-docker#running-the-agent-yourself"
}

uninstall_host_agent() {
    local service label domain
    case "$1" in
    systemd)
        service=$(agent_service_name)
        if [ -f "/etc/systemd/system/$service.service" ]; then
            systemctl disable --now "$service" >/dev/null 2>&1 || true
            rm -f "/etc/systemd/system/$service.service"
            systemctl daemon-reload || true
            rm -rf "/run/bitcart$SCRIPTS_POSTFIX"
        fi
        ;;
    launchd)
        label=$(agent_launchd_label)
        for domain in "gui/$(id -u)" "user/$(id -u)"; do
            launchctl bootout "$domain/$label" >/dev/null 2>&1 || true
        done
        rm -f "$HOME/Library/LaunchAgents/$label.plist"
        ;;
    ssh)
        update_authorized_keys /root/.ssh/authorized_keys "" "$(agent_service_name)"
        rm -rf "$BITCART_BASE_DIRECTORY/.agent/ssh"
        ;;
    esac
}

install_host_agent() {
    local transport=$BITCART_AGENT_TRANSPORT other
    for other in systemd launchd ssh; do
        if [ "$other" != "$transport" ]; then
            uninstall_host_agent "$other"
        fi
    done
    case "$transport" in
    none)
        echo "Host agent disabled, managing this instance from the admin panel is unavailable"
        ;;
    systemd | launchd | ssh | manual)
        if ! [[ "$BITCART_BASE_DIRECTORY" =~ ^/[A-Za-z0-9._/-]+$ ]]; then
            echo "WARNING: the host agent needs the Bitcart directory path to contain only letters, digits and ._/- characters, it is not installed"
        elif ! install_agent_binary || ! "install_agent_$transport"; then
            echo "WARNING: failed to install the $transport host agent, managing this instance from the admin panel is unavailable until it installs"
        fi
        ;;
    *)
        echo "WARNING: unknown BITCART_AGENT_TRANSPORT $transport, the host agent is not installed"
        ;;
    esac
}

agent_ping_from_worker() {
    local container attempt
    container=$(container_name "worker-1")
    for attempt in $(seq 1 30); do
        if docker exec -i -u electrum "$container" python3 - ping <"$BITCART_BASE_DIRECTORY/host-agent/client.py" 2>/dev/null |
            head -n 1 | grep -q '^{"v":1,"ok":true'; then
            return 0
        fi
        sleep 2
    done
    echo "The host agent did not answer the worker after $attempt attempts"
    return 1
}

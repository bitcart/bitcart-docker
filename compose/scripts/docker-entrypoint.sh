#!/usr/bin/env sh
set -ex

# BitcartCC is configuring current instance or updating it via SSH access

# Make host.docker.internal work (on linux-based docker engines)
echo "$(/sbin/ip route|awk '/default/ { print $3 }')  host.docker.internal" >> /etc/hosts

if [ ! -z "$SSH_KEY_FILE" ] && ! [ -f "$SSH_KEY_FILE" ]; then
    echo "Creating BitcartCC SSH key File..."
    ssh-keygen -t rsa -f "$SSH_KEY_FILE" -q -P "" -m PEM -C bitcartcc > /dev/null
    if [ -f "$SSH_AUTHORIZED_KEYS" ]; then
        # Because the file is mounted, sed -i does not work
        sed '/bitcartcc$/d' "$SSH_AUTHORIZED_KEYS" > "$SSH_AUTHORIZED_KEYS.new"
        cat "$SSH_AUTHORIZED_KEYS.new" > "$SSH_AUTHORIZED_KEYS"
        rm -rf "$SSH_AUTHORIZED_KEYS.new"
    fi
fi

if [ ! -z "$SSH_KEY_FILE" ] && [ -f "$SSH_AUTHORIZED_KEYS" ] && ! grep -q "bitcartcc$" "$SSH_AUTHORIZED_KEYS"; then
    echo "Adding BitcartCC SSH key to authorized keys"
    cat "$SSH_KEY_FILE.pub" >> "$SSH_AUTHORIZED_KEYS"
fi

exec "$@"

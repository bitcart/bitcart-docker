#!/usr/bin/env sh
set -ex

# BitcartCC is configuring current instance or updating it via SSH access

# Make host.docker.internal work (on linux-based docker engines)
echo "$(/sbin/ip route|awk '/default/ { print $3 }')  host.docker.internal" >> /etc/hosts

if [ ! -z "$BITCART_SSH_KEY_FILE" ] && ! [ -f "$BITCART_SSH_KEY_FILE" ]; then
    echo "Creating BitcartCC SSH key File..."
    ssh-keygen -t rsa -f "$BITCART_SSH_KEY_FILE" -q -P "" -m PEM -C bitcartcc > /dev/null
    if [ -f "$BITCART_SSH_AUTHORIZED_KEYS" ]; then
        # Because the file is mounted, sed -i does not work
        sed '/bitcartcc$/d' "$BITCART_SSH_AUTHORIZED_KEYS" > "$BITCART_SSH_AUTHORIZED_KEYS.new"
        cat "$BITCART_SSH_AUTHORIZED_KEYS.new" > "$BITCART_SSH_AUTHORIZED_KEYS"
        rm -rf "$BITCART_SSH_AUTHORIZED_KEYS.new"
    fi
fi

if [ ! -z "$BITCART_SSH_KEY_FILE" ] && [ -f "$BITCART_SSH_AUTHORIZED_KEYS" ] && ! grep -q "bitcartcc$" "$BITCART_SSH_AUTHORIZED_KEYS"; then
    echo "Adding BitcartCC SSH key to authorized keys"
    cat "$BITCART_SSH_KEY_FILE.pub" >> "$BITCART_SSH_AUTHORIZED_KEYS"
fi

alembic upgrade head
gunicorn -c gunicorn.conf.py main:app

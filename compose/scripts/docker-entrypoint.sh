#!/usr/bin/env sh
set -ex

# BitcartCC is configuring current instance or updating it via SSH access

if [ ! -z "$SSH_KEY_FILE" ] && ! [ -f "$SSH_KEY_FILE" ]; then
    echo "Creating BitcartCC SSH key File..."
    ssh-keygen -t ed25519 -f "$SSH_KEY_FILE" -q -P "" -m PEM -C bitcartcc >/dev/null
    if [ -f "$SSH_AUTHORIZED_KEYS" ]; then
        # Because the file is mounted, sed -i does not work
        sed '/bitcartcc$/d' "$SSH_AUTHORIZED_KEYS" >"$SSH_AUTHORIZED_KEYS.new"
        cat "$SSH_AUTHORIZED_KEYS.new" >"$SSH_AUTHORIZED_KEYS"
        rm -rf "$SSH_AUTHORIZED_KEYS.new"
    fi
fi

if [ ! -z "$SSH_KEY_FILE" ] && [ -f "$SSH_AUTHORIZED_KEYS" ] && ! grep -q "bitcartcc$" "$SSH_AUTHORIZED_KEYS"; then
    echo "Adding BitcartCC SSH key to authorized keys"
    cat "$SSH_KEY_FILE.pub" >>"$SSH_AUTHORIZED_KEYS"
fi

# Fix all permissions

getent group tor || groupadd --gid 19001 tor && usermod -a -G tor electrum

for volume in $BITCART_VOLUMES; do
    if [ -d "$volume" ]; then
        # ignore authorized keys to not break ssh
        find "$volume" \! -user electrum \! -wholename '/datadir/host_authorized_keys' -exec chown electrum '{}' +
    fi
done

exec gosu electrum "$@"

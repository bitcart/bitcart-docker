#!/usr/bin/env sh
set -ex

# Fix all permissions

getent group tor || groupadd --gid 19001 tor && usermod -a -G tor electrum

for volume in $BITCART_VOLUMES; do
    if [ -d "$volume" ]; then
        find "$volume" \! -user electrum -exec chown electrum '{}' +
    fi
done

exec gosu electrum "$@"

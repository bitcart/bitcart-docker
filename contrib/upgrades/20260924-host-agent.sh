#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
# shellcheck source=helpers.sh
. helpers.sh
# shellcheck source=host-agent/helpers.sh
. host-agent/helpers.sh
load_env

authorized_keys=${BITCART_HOST_SSH_AUTHORIZED_KEYS:-$HOME/.ssh/authorized_keys}
datadir="/var/lib/docker/volumes/$(volume_name bitcart_datadir)/_data"
if [ ! -f "$datadir/host_id_rsa" ] && ! awk '$NF == "bitcart" { found = 1 } END { exit !found }' "$authorized_keys" 2>/dev/null; then
    exit 0
fi
if [ "$BITCART_AGENT_TRANSPORT" != none ] && ! agent_ping_from_worker; then
    echo "The worker cannot reach the host agent yet, keeping the old Bitcart SSH key in $authorized_keys"
    exit 1
fi
update_authorized_keys "$authorized_keys" "" bitcart
rm -f "$datadir/host_id_rsa" "$datadir/host_id_rsa.pub" "$datadir/host_authorized_keys"
echo "Removed the old Bitcart SSH key"

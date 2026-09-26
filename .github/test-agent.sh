#!/bin/bash

set -e

# shellcheck source=helpers.sh
. helpers.sh
# shellcheck source=host-agent/helpers.sh
. host-agent/helpers.sh
load_env
cd "$BITCART_BASE_DIRECTORY"

worker=$(container_name worker-1)

call() {
    docker exec -i -u electrum "$worker" python3 - "$@" <host-agent/client.py
}

echo "Host agent transport: $BITCART_AGENT_TRANSPORT"
[ "$BITCART_AGENT_TRANSPORT" = systemd ]
systemctl is-active --quiet bitcart-agent

agent_ping_from_worker
call capabilities | head -n 1 | jq -e '.ok and .data.transport == "systemd" and .data.executor == "systemd-run"
    and (.data.host.components | index("worker")) and (.data.host.cryptos | index("btc"))
    and (.data.images.backend.revision | length == 40)'
call get_config | head -n 1 | jq -e '.data.settings | .BITCART_HOST == "bitcart.local" and .BITCART_REVERSEPROXY == "nginx"
    and .BITCART_INSTALL == "all" and .BITCART_CRYPTOS == "btc,ltc" and .BTC_LIGHTNING == "true"
    and (has("BITCART_ADMIN_HOST") or has("BITCART_STORE_HOST") | not)'

job_id=$(call cleanup | head -n 1 | jq -er .data.job_id)
echo "Started cleanup job $job_id"
for _ in $(seq 1 120); do
    state=$(call job_status "id=$job_id" | head -n 1 | jq -r .data.state)
    if [ "$state" != running ]; then
        break
    fi
    sleep 1
done
call job_status "id=$job_id" log_lines=all
echo
[ "$state" = "done" ]
echo "Host agent works"

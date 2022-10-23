#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
. "${SCRIPT_DIR}/helpers.sh"
load_env

policiesupdate() {
    docker exec -i $(container_name worker-1) python3 <<EOF
import asyncio

from api import settings, utils, schemes

async def main():
    settings.settings_ctx.set(settings.Settings())
    await settings.init()
    policies = await utils.policies.get_setting(schemes.Policy)
    for key, value in $1.items():
        setattr(policies, key, value)
    await utils.policies.set_setting(policies)

asyncio.run(main())
EOF
}

sqlquery() {
    docker exec $(container_name database-1) psql -U postgres -d bitcart -c "$*"
}

case "$1" in
disable-captcha)
    policiesupdate "{\"enable_captcha\": False}"
    ;;
set-user-admin)
    sqlquery "UPDATE users SET is_superuser=true WHERE email='$2';"
    ;;
reset-server-policy)
    sqlquery "DELETE FROM settings WHERE name='policy';"
    ;;
*)
    echo "Usage: $0 [command]"
    echo
    echo "Commands:"
    echo "         disable-captcha"
    echo "         set-user-admin <email>"
    echo "         reset-server-policy"
    ;;
esac

exit 0

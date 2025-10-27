#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
. "${SCRIPT_DIR}/helpers.sh"
load_env

policiesupdate() {
    local action="$1"
    local data="$2"
    docker exec -i $(container_name worker-1) python3 <<EOF
import asyncio
import json

from dishka import Scope

from api.ioc import build_container
from api.schemas.policies import Policy
from api.services.settings import SettingService
from api.settings import Settings


async def main() -> None:
    settings = Settings()
    container = build_container(settings)
    async with container(scope=Scope.REQUEST) as request_container:
        setting_service = await request_container.get(SettingService)
        policies = await setting_service.get_setting(Policy)
        if "$action" == "update":
            updates = json.loads('$data')
            for key, value in updates.items():
                setattr(policies, key, value)
            await setting_service.set_setting(policies)
        else:
            keys = json.loads('$data')
            data = policies.model_dump()
            if keys:
                result_data = {key: value for key, value in data.items() if key in keys}
            else:
                result_data = data
            print(json.dumps(result_data, indent=2, sort_keys=True))


asyncio.run(main())
EOF
}

sqlquery() {
    docker exec $(container_name database-1) psql -U postgres -d bitcart -c "$*"
}

print_usage() {
    echo "Usage: $0 [command]"
    echo
    echo "Commands:"
    echo "         enable-captcha [provider]"
    echo "         disable-captcha"
    echo "         disable-multifactor <email>"
    echo "         set-user-admin <email>"
    echo "         reset-server-policy"
    echo "         get-server-policy [key ...]"
    echo "         edit-server-policy <key> <value>"
    echo "         edit-server-policy key1=val1 key2=val2"
    echo "         edit-server-policy '{\"key1\":\"val1\",\"flag\":false}'"
}

command="$1"

case "$command" in
enable-captcha)
    provider="${2:-cloudflare_turnstile}"
    policiesupdate update "{\"captcha_type\": \"$provider\"}"
    ;;
disable-captcha)
    policiesupdate update '{"captcha_type": "none"}'
    ;;
disable-multifactor)
    sqlquery "UPDATE users SET tfa_enabled=false, fido2_devices='{}' WHERE email='$2';"
    ;;
set-user-admin)
    sqlquery "UPDATE users SET is_superuser=true WHERE email='$2';"
    ;;
reset-server-policy)
    sqlquery "DELETE FROM settings WHERE name='policy';"
    ;;
get-server-policy)
    shift
    keys_json=$(python3 -c "import json, sys; print(json.dumps(sys.argv[1:]))" "$@")
    policiesupdate get "$keys_json"
    ;;
edit-server-policy)
    shift
    if [ $# -eq 0 ]; then
        echo "edit-server-policy requires at least one argument." >&2
        print_usage
        exit 1
    fi
    updates_json=$(python3 -c '
import json
import sys

args = sys.argv[1:]

def parse_value(raw: str):
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw

if len(args) == 1 and args[0].startswith("{"):
    data = json.loads(args[0])
else:
    data = {}
    if len(args) == 2 and "=" not in args[0]:
        key, value = args
        data[key] = parse_value(value)
    else:
        for item in args:
            key, value = item.split("=", 1)
            data[key] = parse_value(value)

print(json.dumps(data))
' "$@")
    policiesupdate update "$updates_json"
    ;;
*)
    print_usage
    if [ -z "$command" ]; then
        exit 1
    fi
    if [[ "$command" == "help" ]]; then
        exit 0
    fi
    echo "Unknown command: $command" >&2
    exit 1
    ;;
esac

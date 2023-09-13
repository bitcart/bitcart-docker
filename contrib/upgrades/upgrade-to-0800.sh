#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
. "${SCRIPT_DIR}/../../helpers.sh"
load_env

try rm /etc/profile.d/bitcartcc-env$SCRIPTS_POSTFIX.sh
try rm $HOME/bitcartcc-env$SCRIPTS_POSTFIX.sh
try systemctl disable bitcartcc$SCRIPTS_POSTFIX.service
try systemctl stop bitcartcc$SCRIPTS_POSTFIX.service
try rm /etc/systemd/system/bitcartcc$SCRIPTS_POSTFIX.service
try systemctl daemon-reload

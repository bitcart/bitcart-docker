#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
. "${SCRIPT_DIR}/../../helpers.sh"
load_env

try mv /etc/profile.d/bitcartcc-env$SCRIPTS_POSTFIX.sh /etc/profile.d/bitcart-env$SCRIPTS_POSTFIX.sh
try mv $HOME/bitcartcc-env$SCRIPTS_POSTFIX.sh $HOME/bitcart-env$SCRIPTS_POSTFIX.sh
try systemctl disable bitcartcc$SCRIPTS_POSTFIX.service
try systemctl stop bitcartcc$SCRIPTS_POSTFIX.service
try mv /etc/systemd/system/bitcartcc$SCRIPTS_POSTFIX.service /etc/systemd/system/bitcart$SCRIPTS_POSTFIX.service
try systemctl daemon-reload
try systemctl enable bitcart$SCRIPTS_POSTFIX.service
try systemctl start bitcart$SCRIPTS_POSTFIX.service

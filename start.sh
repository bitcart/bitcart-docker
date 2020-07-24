#!/usr/bin/env bash

. helpers.sh
load_env

cd "$BITCART_BASE_DIRECTORY"
# setup pipe and it's listener
mkfifo queue &> /dev/null
nohup sh -c "tail -f queue | sh" &> /dev/null &
echo $! > listener.pid
USER_UID=${UID} USER_GID=${GID} docker-compose -p "$NAME" -f compose/generated.yml up --remove-orphans -d
#!/usr/bin/env bash

if [[ "$OSTYPE" == "darwin"* ]]; then
	# Mac OS
	BASH_PROFILE_SCRIPT="$HOME/bitcartcc-env.sh"

else
	# Linux
	BASH_PROFILE_SCRIPT="/etc/profile.d/bitcartcc-env.sh"
fi

. ${BASH_PROFILE_SCRIPT}

cd "$BITCART_BASE_DIRECTORY"
# setup pipe and it's listener
mkfifo queue
nohup sh -c "tail -f queue | sh" > /dev/null &
echo $! > listener.pid
USER_UID=${UID} USER_GID=${GID} docker-compose -f compose/generated.yml up --remove-orphans -d
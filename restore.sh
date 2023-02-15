#!/usr/bin/env bash

function display_help() {
    cat <<-END
Usage:
------
Restore BitcartCC files
This script must be run as root
    -h, --help: Show help
    --delete-backup: Delete backup file after restoring. Default: false
This script will restore the database from SQL script and copy essential volumes to /var/lib/docker/volumes
extracted from tar.gz backup archive
END
}

DELETE_BACKUP=false
BACKUP_FILE=

while (("$#")); do
    case "$1" in
    -h)
        display_help
        exit 0
        ;;
    --help)
        display_help
        exit 0
        ;;
    --delete-backup)
        DELETE_BACKUP=true
        shift 1
        ;;
    --) # end argument parsing
        shift
        break
        ;;
    -* | --*=) # unsupported flags
        echo "Error: Unsupported flag $1" >&2
        display_help
        exit 1
        ;;
    *)
        if [ -z "$BACKUP_FILE" ]; then
            BACKUP_FILE="$1"
        fi
        shift
        ;;
    esac
done

if [ -z "$BACKUP_FILE" ]; then
    display_help
    exit 0
fi

. helpers.sh
load_env true
cd "$BITCART_BASE_DIRECTORY"

TEMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'mytmpdir')

tar -C $TEMP_DIR -xvf "$BACKUP_FILE"

echo "Stopping BitcartCC…"
bitcart_stop

echo "Restoring database …"
bitcart_restore_db $TEMP_DIR/database.sql
echo "Restoring docker volumes…"
cp -r $TEMP_DIR/volumes/ /var/lib/docker
cp -r $TEMP_DIR/plugins compose

echo "Restarting BitcartCC…"
bitcart_start

rm -rf $TEMP_DIR

if $DELETE_BACKUP; then
    rm -rf "$BACKUP_FILE"
fi

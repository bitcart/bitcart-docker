#!/usr/bin/env bash

function display_help() {
    cat <<-END
Usage:
------
Restore Bitcart files
This script must be run as root
    -h, --help: Show help
    --delete-backup: Delete backup file after restoring. Default: false
    --encryption-key KEY: Custom encryption key to decrypt the backup. If not provided, uses the key from .deploy file
This script will restore the database from SQL script and copy essential volumes to /var/lib/docker/volumes
extracted from tar.zst (or legacy tar.gz) backup archive
If the backup file is encrypted (.enc extension), it will be automatically decrypted using the encryption key
from the .deploy file or the custom key provided via --encryption-key
END
}

DELETE_BACKUP=false
BACKUP_FILE=
CUSTOM_ENCRYPTION_KEY=

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
    --encryption-key)
        CUSTOM_ENCRYPTION_KEY="$2"
        shift 2
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

if [[ "$BACKUP_FILE" == *.enc ]]; then
    if [ -n "$CUSTOM_ENCRYPTION_KEY" ]; then
        ENCRYPTION_KEY="$CUSTOM_ENCRYPTION_KEY"
        echo "Using custom encryption key provided via --encryption-key"
    else
        if [ -z "$BACKUP_ENCRYPTION_KEY" ]; then
            echo "Error: Backup file is encrypted but BACKUP_ENCRYPTION_KEY is not found in .deploy file"
            echo "Use --encryption-key to provide a custom encryption key"
            exit 1
        fi
        ENCRYPTION_KEY="$BACKUP_ENCRYPTION_KEY"
    fi
    echo "Decrypting backup …"
    enc_source="${BACKUP_FILE%.enc}"
    if [[ "$enc_source" == *.tar.gz ]]; then
        decrypted_file="${TEMP_DIR}/backup.tar.gz"
    else
        decrypted_file="${TEMP_DIR}/backup.tar.zst"
    fi
    openssl enc -aes-256-cbc -d -salt -pbkdf2 -in "$BACKUP_FILE" -out "$decrypted_file" -pass pass:"$ENCRYPTION_KEY"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to decrypt backup file"
        rm -rf $TEMP_DIR
        exit 1
    fi
    BACKUP_FILE="$decrypted_file"
fi

if [[ "$BACKUP_FILE" == *.tar.gz ]]; then
    tar -C $TEMP_DIR -xzvf "$BACKUP_FILE"
else
    tar_file="${TEMP_DIR}/backup.tar"
    zstdmt -d "$BACKUP_FILE" -o "$tar_file"
    tar -C $TEMP_DIR -xvf "$tar_file"
    rm "$tar_file"
fi

echo "Stopping Bitcart…"
bitcart_stop

echo "Restoring database …"
bitcart_restore_db $TEMP_DIR/database.sql
echo "Restoring docker volumes…"
cp -r $TEMP_DIR/volumes/ /var/lib/docker
cp -r $TEMP_DIR/plugins compose

echo "Restarting Bitcart…"
bitcart_start

rm -rf $TEMP_DIR

if $DELETE_BACKUP; then
    rm -rf "$BACKUP_FILE"
fi

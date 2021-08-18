#!/usr/bin/env bash

function display_help() {
    cat <<-END
Usage:
------
Backup BitcartCC files
This script must be run as root
    -h, --help: Show help
    --only-db: Backup database only. Default: false
    --restart: Restart BitcartCC (to avoid data corruption if needed). Default: false
This script will backup the database as SQL script, essential volumes and put it to tar.gz archive
It may optionally upload the backup to a remote server
Environment variables:
    BACKUP_PROVIDER: where to upload. Default empty (local). See list of supported providers below
    SCP_TARGET: where to upload the backup via scp
    S3_BUCKET: where to upload the backup via s3
    S3_PATH: path to the backup on the remote server
Supported providers:
* Local: keeps backups in backup_datadir docker volume (default)
* SCP: uploads the backup to a remote server via scp
* S3: uploads to s3://bucket/path
END
}

ONLY_DB=false
RESTART_SERVICES=false

# TODO: less duplication for args parsing

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
    --only-db)
        ONLY_DB=true
        shift 1
        ;;
    --restart)
        RESTART_SERVICES=true
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
        shift
        ;;
    esac
done

. helpers.sh
load_env true

cd "$BITCART_BASE_DIRECTORY"

deployment_name=$(container_name)
volumes_dir=/var/lib/docker/volumes
backup_dir="$volumes_dir/backup_datadir"
timestamp=$(date "+%Y%m%d-%H%M%S")
filename="$timestamp-backup.tar.gz"
dumpname="$timestamp-database.sql"

backup_path="$backup_dir/_data/${filename}"
dbdump_path="$backup_dir/_data/${dumpname}"

echo "Dumping database …"
bitcart_dump_db $dumpname

if $ONLY_DB; then
    tar -cvzf $backup_path $dbdump_path
else
    if $RESTART_SERVICES; then
        echo "Stopping BitcartCC…"
        bitcart_stop
    fi

    echo "Backing up files …"
    files=()
    for fname in bitcart_datadir tor_servicesdir; do
        files+=("$(container_name $fname)")
    done
    # put all volumes to volumes directory and remove timestamps
    tar -cvzf $backup_path -C $volumes_dir --transform "s|^$deployment_name|volumes/$deployment_name|" "${files[@]}" \
        -C "$(dirname $dbdump_path)" --transform "s|$timestamp-||" --transform "s|$timestamp||" $dumpname

    if $RESTART_SERVICES; then
        echo "Restarting BitcartCC…"
        bitcart_start
    fi
fi

delete_backup() {
    echo "Deleting local backup …"
    rm $backup_path
}

case $BACKUP_PROVIDER in
"S3")
    echo "Uploading to S3 …"
    docker run --rm -v ~/.aws:/root/.aws -v $backup_path:/aws/$filename amazon/aws-cli s3 cp $filename s3://$S3_BUCKET/$S3_PATH
    delete_backup
    ;;

"SCP")
    echo "Uploading via SCP …"
    scp $backup_path $SCP_TARGET
    delete_backup
    ;;

*)
    echo "Backed up to $backup_path"
    ;;
esac

# cleanup
rm $dbdump_path

echo "Backup done."

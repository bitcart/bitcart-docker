#!/usr/bin/env bash

volumes_dir=/var/lib/docker/volumes
backup_dir="$volumes_dir/backup_datadir"
timestamp=$(date "+%Y%m%d-%H%M%S")
filename="$timestamp-backup.tar.gz"
dumpname="$timestamp-postgres.sql"

backup_path="$backup_dir/_data/${filename}"
dbdump_path="$backup_dir/_data/${dumpname}"

. helpers.sh
load_env

cd "$BITCART_BASE_DIRECTORY"

echo "Dumping database …"
bitcart_dump_db $dumpname

if [[ "$1" == "--only-db" ]]; then
    tar -cvzf $backup_path $dbdump_path
else
    # stop docker containers, save files and restart
    echo "Stopping BitcartCC…"
    bitcart_stop

    echo "Backing up files …"
    tar --exclude="$backup_dir/*" -cvzf $backup_path $dbdump_path $volumes_dir

    echo "Restarting BitcartCC…"
    bitcart_start
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
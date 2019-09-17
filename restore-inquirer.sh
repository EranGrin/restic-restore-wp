#!/bin/bash
set -e


SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

PARENT_DIR=$(dirname "$DIR")


name=ikli
aws_repo=s3:https://s3.amazonaws.com/restic-test-server
target=/
sql_user=dev
sql_pass=DEV2323
current_dir=$(pwd)

source .restic-keys
source ${current_dir}/inquirer.sh/dist/list_input.sh

website_name=$(cat test.json | jq -j --arg c "' " --arg b "'" '$b + .[] .group_key .tags[] + $c')

echo $website_name

website=( $website_name )
list_input "Which website would you like to restore ?" website selected_website

echo "website: $selected_website"

SITE_NAME=$selected_website
BACKUP_TIMES=$(cat test.json | jq -j --arg c "' " --arg b "'" --arg p "$SITE_NAME" '.[] .snapshots[] | $b+ select(.tags[] == $p) .time + $c')
echo $BACKUP_TIMES

time_stamp=( $BACKUP_TIMES )
list_input "Which backup would you like to restore ?" time_stamp selected_time_stamp

echo "backup: $selected_time_stamp"

BACKUP_TIME=$selected_time_stamp
BACKUP_ID=$(cat test.json | jq -j --arg p "$SITE_NAME" --arg t "$BACKUP_TIME"  '.[] .snapshots[] | select(.tags[]== $p ) | select(.time == $t ) .short_id')

echo "BackId: $BACKUP_ID"

echo "Start restore - this might take a while"
restic -r $aws_repo restore $BACKUP_ID --target /. --exclude='*.sql'

# $ restic -r /srv/restic-repo dump 098db9d5 production.sql | mysql
echo "restore sql"
#mkdir -p /tmp/mysql/

restic -r $aws_repo dump $BACKUP_ID "tmp/mysql/${SITE_NAME}.sql" | mysql -u dev -p

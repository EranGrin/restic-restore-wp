#!/bin/bash
set -e

# These credential needed to be changed to a user that have access right to change the all db
sql_user=dev
sql_pass=****

# This need to be changed to the relative AWS restic repo
aws_repo=s3:https://s3.amazonaws.com/restic-test-server

current_dir=$(pwd)

#load env variables / credential need to be added to the file
source .restic-keys

# path for inquirer file
source ${current_dir}/inquirer.sh/dist/list_input.sh

echo "\n`date` - Generating snapshots Json \n"
restic -r $aws_repo snapshots --verbose --json | jq '.' > snapshots.json


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

echo "\n`date` - restore db \n"
restic -r $aws_repo dump $BACKUP_ID "tmp/mysql/${SITE_NAME}.sql" | mysql -u $sql_user -p #possibile to add the pass variable

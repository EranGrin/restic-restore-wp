#!/bin/bash
set -euo pipefail
IFS=$'\n\t'


#variables
name=ikli
base_path=
src_path=/Applications/Mamp/htdocs/ikli
current_path=$(pwd)
database_user=dev
database_pass=DEV2323
dbserver=127.0.0.1
aws_repo=s3:https://s3.amazonaws.com/restic-test-server


# add a condition to check if repositoryis already initialize
#based on this
# command restic -r /tmp/restic-repo snapshots
# if error then create a new one or ask user

#build a restic repo based on the website name
#restic init --repo /tmp/${name}/restic-repo

source .restic-keys
# export RESTIC_REPOSITORY="s3:s3.wasabisys.com/{{ ansible_hostname }}-backup"
# restic init -r s3:https://s3.amazonaws.com/restic-test-server

# echo "\n`date` - Starting backup...\n"
#
# restic -r $aws_repo backup /Applications/Mamp/htdocs/ikli
#
#
# #maybe to add a script to add a scure pass to mylogin.cnf
# #https://dev.mysql.com/doc/refman/8.0/en/mysql-config-editor.html
#
# mysqldump --defaults-file=/${current_path}/.my.cnf --databases $name -u $database_user | restic -r $aws_repo backup --stdin --stdin-filename ${name}_db_dump.sql
#
# #mysqldump --defaults-file=/${current_path}/.my.cnf --databases ikli -u dev | restic -r /tmp/ikli/restic-repo backup --verbose --stdin --stdin-filename database_dump.sql
#
# echo "\n`date` - Running forget and prune...\n"
#
# restic -r $aws_repo --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 12
#

# echo "\n`date` - Backup finished.\n"


 restic -r $aws_repo snapshots --verbose

# restic -r $aws_repo forget d1d3efd3
# restic -r $aws_repo snapshots --json | jq '.' > test.json

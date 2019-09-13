#!/bin/bash

#variables
name=ikli
path=/Applications/Mamp/htdocs/ikli
database_user=dev
database_pass=DEV2323
dbserver=127.0.0.1


# add a condition to check if repositoryis already initialize
#based on this command restic -r /srv/restic-repo snapshots
# if error then create a new one or ask user

#build a restic repo based on the website name
restic init --repo /tmp/${name}/restic-repo

source .restic-keys
# export RESTIC_REPOSITORY="s3:s3.wasabisys.com/{{ ansible_hostname }}-backup"

echo -e "\n`date` - Starting backup...\n"

restic -r /tmp/${name}/restic-repo backup /Applications/Mamp/htdocs/ikli

#add a script to add a scure pass to mylogin.cnf
mysqldump --databases $name -u $database_user | restic -r /tmp/${name}/restic-repo backup --stdin --stdin-filename database_dump.sql

# mysqldump --databases ikli -u dev | restic backup --stdin --stdin-filename database_dump.sql

echo -e "\n`date` - Running forget and prune...\n"

restic -r /tmp/${name}/restic-repo forget --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 12

echo -e "\n`date` - Backup finished.\n"

#-----------------------

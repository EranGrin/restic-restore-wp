
set -e
export BACKUP_RESTORE_BUCKET=***REMOVED***
# Check the repository for errors
crx-restic check
# Backup vhosts with static sites
while read -r vhost || [[ -n "$vhost" ]]; do
  crx-restic backup "$vhost" "/usr/local/www/apache24/noexec/$vhost"
done < /root/.crx-restic/***REMOVED***/vhosts_static
# Backup vhosts with database
dbDir="/tmp/mysql"
rm -rf $dbDir
mkdir -p $dbDir
cat >/root/.tmp-mysql <<EOL
[client]
user = admin
password = zvxndjzZ4JmURf
host = localhost
EOL
crx-restic unlock
while read -r line || [[ -n "$line" ]]; do
  IFS=';' read -r -a myarray <<< "$line"
  vhost=${myarray[0]}
  database=${myarray[1]}
  mysqldump --defaults-extra-file=/root/.tmp-mysql \
    --force \
    --quote-names --dump-date \
    --opt --single-transaction \
    --events --routines --triggers \
    --databases "$database" \
    --result-file="$dbDir/$database.sql"
  crx-restic -e /root/.crx-restic/***REMOVED***/excludes backup "$vhost" "/usr/local/www/apache24/noexec/$vhost" "$dbDir/$database.sql"
  rm "$dbDir/$database.sql"
  sleep 300
done < /root/.crx-restic/***REMOVED***/vhosts_with_db
# Backup etc
crx-restic backup etc /etc /var/db/acme
# Forget by default policy
crx-restic --group-by host,tags forget_by_policy
# Clean up
rm /root/.tmp-mysql
rm -rf "$dbDir"
exit 0

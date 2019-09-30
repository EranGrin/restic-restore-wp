
name=ikli
aws_repo=s3:https://s3.amazonaws.com/restic-test-server
target=/Applications/Mamp/htdocs/ikli
sql_user=dev
sql_pass=DEV2323

source .restic-keys

restic -r $aws_repo restore latest --target $target --tag $name

# $ restic -r /srv/restic-repo dump 098db9d5 production.sql | mysql
echo "restore sql"
#mkdir -p /tmp/mysql/

restic -r $aws_repo dump --tag $name 91bec59d "tmp/mysql/ikli.sql" | mysql -u dev -p
 #| mysql -u $sql_user -PDEV2323 --databases $name
# restic -r /srv/restic-repo dump --path /production.sql latest production.sql | mysql

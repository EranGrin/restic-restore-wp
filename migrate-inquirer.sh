#!/bin/bash


# This need to be changed to the relative AWS restic repo
aws_repo=s3:https://s3.amazonaws.com/restic-test-server

htdocs=/Applications/mamp/htdocs #absulote path to htdocs on the target server


#load env variables / credential need to be added to the file
source .restic-keys

# path for inquirer file
source ./inquirer.sh/dist/list_input.sh

echo "\n`date` - Generating snapshots Json \n"
restic -r $aws_repo snapshots --group-by tags --json | jq '.' > snapshots.json

website_name=$(cat snapshots.json | jq -j --arg c "' " --arg b "'" '$b + .[] .group_key .tags[] + $c')

echo $website_name

website=( $website_name)
list_input "Which website would you like to restore ?" website selected_website

echo "website: $selected_website"

SITE_NAME=$selected_website
BACKUP_TIMES=$(cat snapshots.json | jq -j --arg c "' " --arg b "'" --arg p "$SITE_NAME" '.[] .snapshots[] | $b+ select(.tags[] == $p) .time + $c')
echo $BACKUP_TIMES

time_stamp=( $BACKUP_TIMES)
list_input "Which backup would you like to restore ?" time_stamp selected_time_stamp

echo "backup: $selected_time_stamp"

BACKUP_TIME=$selected_time_stamp
BACKUP_ID=$(cat snapshots.json | jq -j --arg p "$SITE_NAME" --arg t "$BACKUP_TIME"  '.[] .snapshots[] | select(.tags[]== $p ) | select(.time == $t ) .short_id')

echo "BackId: $BACKUP_ID"

absulote_path=$(cat snapshots.json | jq -j --arg p "$SITE_NAME" --arg t "$BACKUP_TIME"  '.[] .snapshots[] | select(.tags[]== $p ) | select(.time == $t ) .paths[0]')
# filter the absulote path based on the chosen arguments of SITE_NAME + BACKUP_TIME

dir="$(basename $absulote_path)" #extract the last dir from absulote path

################################
##### The actual restore #######
##################################################################################################
echo "Start restore - this might take a while"
restic -r $aws_repo restore $BACKUP_ID --target $htdocs  --exclude='*.sql' --path "$absulote_path"


###################################################
### moving the absulote path to target path #######
###################################################
src_dir=$htdocs$absulote_path
target_dir="$htdocs/$dir"

echo "src-dir $src_dir"
echo "target-dir $target_dir"

echo "\n`date` - check if target-dir alerady exists and if yes then remove it\n"
if [ -d "$target_dir" ]; then
  rm -r $target_dir
    echo "$target_dir"
  mkdir -p $target_dir
else
  continue
fi

echo "\n`date` - Moveing wbesite directory to target-dir \n"
  mv -v $src_dir/* $src_dir/.*  $target_dir

echo "\n`date` - Cleanup leftovers direcotries \n"
  base_dir=$(echo "$absulote_path" | awk -F "/" '{print $2}')

if [ -z "$base_dir" ]; then
## this is a security if statment to check if the basedir var is empaty if it does
## empty and script would not exit then all the htdocs will be deleted
  echo "ERROR - could not find base-dir variable"
    exit 1
else
  rm -r $htdocs/$base_dir
fi


#############################################################
##### DB restore & migration proccess for WP website ########
#############################################################

## ? consider how to handle sql server that is not localhost ?

## ask user if he want to assign new sql credentials to the website

sql_credentials=( 'New SQL credentials' 'Orignin SQL credentials' )
list_input "would you like to assign new SQL credentials or use the origin SQL credentials ?" sql_credentials selected_sql_credentials

if [ "$selected_sql_credentials" == "New SQL credentials" ]; then
  while true
      do
        read -r -p "what is the sql user, pls enter the user name " new_sql_user

          read -r -p "what is the sql pass, pls enter the password " new_sql_pass

          echo "\n"
          echo "credentials"
          echo "new sql user $new_sql_user"
          echo "new sql pass $new_sql_pass"

          read -r -p "Are You Sure? [Y/n] " input

      	case $input in
      	    [yY][eE][sS]|[yY])
      			echo "Yes"

            echo "\n`date` - Change sql credentials at wp-config.php \n"
            wp --allow-root --path=$target_dir config set DB_USER "$new_sql_user" --raw
            wp --allow-root --path=$target_dir config set DB_PASSWORD "$new_sql_pass" --raw

                  break
      			;;
      	    [nN][oO]|[nN])
      			echo "No"
      	       		;;
      	    *)
      		echo "Invalid input..."
      		;;
      	esac
    done

fi


echo "\n`date` - Restore db \n"
db_path=$(cat snapshots.json | jq -j --arg p "$SITE_NAME" --arg t "$BACKUP_TIME"  '.[] .snapshots[] | select(.tags[]== $p ) | select(.time == $t ) .paths[1]')
# filter the db sql file path based on the chosen arguments of SITE_NAME + BACKUP_TIME


echo "For the restore proccess of the DB, mysql will need to use admin user Global privileges"
while true
    do
      read -r -p "pls enter sql admin user name " admin_sql_user

        read -r -p "pls enter sql admin password " admin_sql_pass

        echo "\n"
        echo "SQL Admin Credentials"
        echo "Admin sql user $admin_sql_user"
        echo "Admin sql pass $admin_sql_pass"

        read -r -p "Are You Sure? [Y/n] " input

      case $input in
          [yY][eE][sS]|[yY])
          echo "Yes"
                break
          ;;
          [nN][oO]|[nN])
          echo "No"
                ;;
          *)
        echo "Invalid input..."
        ;;
      esac
  done

  db_path="${db_path:1}" #remove first character from string
  echo "Restore DB in new SQL server"

restic -r $aws_repo dump $BACKUP_ID $db_path | mysql -u $admin_sql_user --password=$admin_sql_pass #possibile to add the pass variable -P with capital -P

## extract the src-url from db
## db name based on wp-config file
db_name=$(wp --allow-root --path=$target_dir eval 'echo DB_NAME;')
db_prefix=$(wp --allow-root --path=$target_dir db prefix)
echo "db-name:$db_name"
echo "db-name:$db_prefix"

siteurl=$(mysql -u $admin_sql_user -p$admin_sql_pass $db_name -N -e"SELECT option_value  FROM ${db_prefix}options WHERE option_name = 'siteurl'")
echo "url:$siteurl"
## ask for the URL_TARGET + URL_SRC
URL_SRC=$siteurl

echo "For the restore proccess of the DB, mysql will need to use admin user with global privileges"
while true
    do
      echo "examples: http://website.com or http://localhost:8888/website"

      ## read -r -p "What is the SOURCE URL, pls enter the url " URL_SRC
      read -r -p "What is the TARGET URL, pls enter the url " URL_TARGET

        echo "\n"
        echo "URL Changes - search & replace"
        echo "SOURCE URL: $URL_SRC"
        echo "TARGET URL: $URL_TARGET"

        read -r -p "Are You Sure? [Y/n] " input

      case $input in
          [yY][eE][sS]|[yY])
          echo "Yes"
                break
          ;;
          [nN][oO]|[nN])
          echo "No"
                ;;
          *)
        echo "Invalid input..."
        ;;
      esac
  done

  wp --allow-root --path=$target_dir search-replace $URL_TARGET $URL_SRC

  echo "Restore procces complited"



# using cli config set command to change the values in the wp-config.php  https://developer.wordpress.org/cli/commands/config/set/
# then  when every thing is correctly configured
# use  wp search-replace URL_SRC $URL_LOCAL

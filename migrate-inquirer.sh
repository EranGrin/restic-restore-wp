#!/bin/bash


# This need to be changed to the relative AWS restic repo
# aws_repo=s3:https://s3.amazonaws.com/restic-test-server

# load env variables / credential need to be added to the file

# aws_repo=s3:s3.amazonaws.com/***REMOVED***/restic
aws_repo=s3:https://s3.amazonaws.com/***REMOVED***/restic

htdocs=/Applications/mamp/htdocs # absulote path to htdocs on the target server

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

################################################################
### Function for moving the absulote path to target path #######
################################################################
function move_path
{
  echo "src-dir $src_dir"
  echo "\n`date` - Moveing wbesite directory to target-dir \n"
  mv -v $src_dir/* $src_dir/.*  $target_dir

  echo "\n`date` - Cleanup leftovers direcotries \n"
  if [ -z "$base_dir" ]; then
    ## this is a security if statment to check if the basedir var is empaty if it does
    ## empty and script would not exit then all the htdocs will be deleted
    echo "ERROR - could not find base-dir variable"
    exit 1
  else
    rm -r $htdocs/$base_dir
  fi

}

######################################################################
###### extract path objects & assign to variables ####################
######################################################################
absulote_path=$(cat snapshots.json | jq -j --arg p "$SITE_NAME" --arg t "$BACKUP_TIME"  '.[] .snapshots[] | select(.tags[]== $p ) | select(.time == $t )
.paths[] | select( test(".sql") | not )')
# filter the absulote path based on the chosen arguments of SITE_NAME + BACKUP_TIME + regex no object with *sql
echo "$absulote_path"

relative_path=$(restic ls -r $aws_repo $BACKUP_ID  --path "$absulote_path" | sed -n 2p)
#get the first dir from restic ls command - use to identify relative path

dir="$(basename $absulote_path)" #extract the last dir from absulote path

src_dir=$htdocs$absulote_path
target_dir="$htdocs/$dir"


echo "target-dir $target_dir"


base_dir=$(echo "$absulote_path" | awk -F "/" '{print $2}')

##############################################################################
###### check if target-dir alerady exists and if yes then remove it ##########
##############################################################################

echo "\n`date` - check if target-dir alerady exists and if yes then remove it\n"
if [ -d "$target_dir" ]; then
  echo "$target_dir"
  echo "The target dir exists and therefore it will be removed"
  rm -r $target_dir
  mkdir -p $target_dir ### need to check this with absolute but for relative it might not be needed
else
  continue
fi

################################
##### The actual restore #######
##################################################################################################
echo "Start restore - this might take a while"
restic -r $aws_repo restore $BACKUP_ID --target $htdocs  --exclude='*.sql' --path "$absulote_path"


#############################################################
###### check if the path is relative or absolute ############
###### & based on path kind use move function or continue ###
#############################################################
echo "base_dir: $base_dir"
echo "relative_path: $relative_path"
if [[ $relative_path == "/$base_dir" ]]; then # test if path is relative or absolute
  #use absolute path function
  move_path
  echo "found absolute path"
  path_is="absolute"
else
  #use relative path function
  continue
  echo "found relative path"
  path_is="relative"

fi


#############################################################
##### DB restore & migration proccess for WP website ########
#############################################################

## ? consider how to handle sql server that is not localhost ?

## ask user if he want to assign new sql credentials to the website

sql_credentials=( 'New SQL credentials' 'Orignin SQL credentials' )
list_input "would you like to assign new SQL credentials to the website or use the origin SQL credentials ?" sql_credentials selected_sql_credentials

if [ "$selected_sql_credentials" == "New SQL credentials" ]; then
  while true
      do
        read -r -p "what is the sql user, pls enter the user name " new_sql_user

          read -r -p "what is the sql pass, pls enter the password " new_sql_pass

          echo "\n"
          echo "website user sql credentials"
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
db_path=$(cat snapshots.json | jq -j --arg p "$SITE_NAME" --arg t "$BACKUP_TIME"  '.[] .snapshots[] | select(.tags[]== $p ) | select(.time == $t ) .paths[] | select( test(".sql") )')

# filter the db sql file path based on the chosen arguments of SITE_NAME + BACKUP_TIME + regex object with *sql


echo "For the restore proccess of the DB, mysql will need to use admin user with global privileges"
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

echo "check if db exiest and if it does it would be recommand to drop it"
wp db drop  --allow-root --path=$target_dir # Drop db based on the website credentials of wp-config.php
wp db create --allow-root --path=$target_dir # Create a db based on the website credentials of wp-config.php


echo "\n`date` - Restore DB in new SQL server \n"

if [[ $path_is == absolute ]]; then

  db_path="${db_path:1}" #remove first character from string
  restic --cleanup-cache -r $aws_repo dump $BACKUP_ID $db_path | mysql -u $admin_sql_user --password=$admin_sql_pass
  echo "absolute"
else
## path is relative

  db_path="$(basename $db_path)" #extract path name from a path
  restic --cleanup-cache -r $aws_repo dump $BACKUP_ID $db_path | mysql -u $admin_sql_user --password=$admin_sql_pass

fi


## strange behivor
## it seems as the sql restore got absolute path need the path of the file + file names
## but relative path need only the file name file.sql



## extract the src-url from db
## db name based on wp-config file
echo "collect data from website"
db_name=$( wp --allow-root --path=$target_dir config get DB_NAME)
db_prefix=$( wp --allow-root --path=$target_dir config get table_prefix)
echo "db-name:$db_name"
echo "prefix-name:$db_prefix"


##### experimental #############
# mysql -u $admin_sql_user --password=$admin_sql_pass -e "GRANT SELECT, INSERT, UPDATE ON $db_name.* TO '$new_sql_user'@'127.0.0.1';


siteurl=$(mysql -u $admin_sql_user -p$admin_sql_pass $db_name -N -e"SELECT option_value  FROM ${db_prefix}options WHERE option_name = 'siteurl'")
echo "url:$siteurl"
## ask for the URL_TARGET + URL_SRC
URL_SRC=$siteurl

echo "URL search & replace"
while true
    do
      echo "examples: http://website.com or http://localhost:8888/website"
      echo "SOURCE URL: $URL_SRC"
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



echo "check plugins for error"

plugin_check=$(mktemp -t PLUGINTEST)
          wp --allow-root --path=$target_dir plugin list &>$plugin_check &
          pid=$!
          wait $pid
          PLUGINTEST=$(<$plugin_check)
          rm $plugin_check

# plugin_check="$(wp --allow-root --path=$target_dir plugin list & ) & "
if [[ $PLUGINTEST =~ [^error] ]]; then
  echo "it seems like we found an error with the plugins"

  echo "we will try to disabled all plugins from db and present you the full check results"

  #if error then disabled
    mysql -u $admin_sql_user -p$admin_sql_pass $db_name -N -e"DELETE  FROM ${db_prefix}options WHERE option_name = 'active_plugins'"
    wp --allow-root --path=$target_dir plugin verify-checksums --all

    echo"you will need to activat all plugins manually as some files are mssing"

else

 echo "No Error"
 continue

fi


echo "\n`date` - Start search-replace  FROM:$URL_SRC  TO:$URL_TARGET\n"
wp --allow-root --path=$target_dir search-replace $URL_SRC $URL_TARGET

echo "Restore procces complited"


echo "\n`date` - Flush the .htaccess \n"
# create a wp-cli.yml file with apache_modules: - mod_rewrite in the root dir of the website
touch $target_dir/wp-cli.yml
chmod 666 $target_dir/wp-cli.yml
echo "apache_modules: \n - mod_rewrite" >> $target_dir/wp-cli.yml

# change .htaccess  premmissions
chmod 666 $target_dir/.htaccess

# run the wp rewrite flush --hard
cd $target_dir
wp --allow-root rewrite flush --hard
# wp --allow-root --path=$target_dir rewrite flush --hard

# change back the .htaccess permisions
chmod 644 $target_dir/.htaccess

# remove wp-cli.yml
rm $target_dir/wp-cli.yml







# using cli config set command to change the values in the wp-config.php  https://developer.wordpress.org/cli/commands/config/set/
# then  when every thing is correctly configured
# use  wp search-replace URL_SRC $URL_LOCAL

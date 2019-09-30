#!/bin/bash

###############################################
#
# Rstore restic backups
# Migration of wordpress website based on restic
#
# by Eran Grinberg <soniceran@gmail.com>
# No warranty provided, use at your own risk!
#
###############################################
# Dependencies
# 1. JQ  https://stedolan.github.io/jq/
# 2. WP-CLI https://wp-cli.org/
#
###############################################
# Flow of script
###############################################
#
#  1. Create snapshots.json group-by tags
#  2. Fetch main variable (backup_id backup_time name etc..)
#  3. Extract path objects & assign to variables
#  4. Check if target-dir exists and if does then remove it
#  5. The actual files restore
#  6. Check if the path is relative or absolute (if absolute then use the move function)
#  7. Configure WP DB Credentials in the wp-config.php
#  8. Check plugins for error
#	 9. URL search & replace
# 10. Flush the .htaccess to the new domain
#
###############################################

## TODO: add option to handle sql server that is not localhost
## TODO: add option to to triger backup on src server before starting migration
## TODO: add option to handle static websites
## TODO: if plugin error is found then run script to activate all plugins one by one

## TOTEST: restore with absolute path
## TOTEST:
###############################################
source .restic-keys # export env variable
source ./dist/list_input.sh # path for inquirer file

HTDOCS=/Applications/mamp/htdocs # absulote path to HTDOCS on the target server
DATE=$(date +'%d/%m/%Y %H:%M:%S')#


#############################################################################
####### Fetch main variable #################################################
#############################################################################
echo "\n $DATE - Generating snapshots Json \n"
restic -r $AWS_REPO snapshots --group-by tags --json | jq '.' > snapshots.json

# Filter WEBSITE_NAMES from snapshots.json
WEBSITE_NAMES=$(cat snapshots.json | jq -j --arg c "' " --arg b "'" '$b + .[] .group_key .tags[] + $c')

# WEBSITE_NAMES inquirer
WEBSITE_NAMES=( $WEBSITE_NAMES)
list_input "Which website would you like to restore ?" WEBSITE_NAMES SELECTED_WEBSITE
echo "Website: $SELECTED_WEBSITE"

# Filter BACKUP_TIMES based on SELECTED_WEBSITE
BACKUP_TIMES=$(cat snapshots.json \
| jq -j --arg c "' " --arg b "'" --arg p "$SELECTED_WEBSITE" '.[] .snapshots[]
| $b+ select(.tags[] == $p) .time + $c')

# BACKUP_TIMES inquirer
BACKUP_TIMES=( $BACKUP_TIMES)
list_input "Which backup would you like to restore ?" BACKUP_TIMES SELECTED_BACKUP_TIME
echo "Backup-time-stamp: $SELECTED_BACKUP_TIME"

# Filter BACKUP_ID based on SELECTED_WEBSITE + SELECTED_BACKUP_TIME
BACKUP_ID=$(cat snapshots.json \
| jq -j --arg p "$SELECTED_WEBSITE" --arg t "$SELECTED_BACKUP_TIME"  '.[] .snapshots[]
| select(.tags[]== $p )
| select(.time == $t ) .short_id')
echo "BackId: $BACKUP_ID"


################################################################
### Function for moving the absulote path to target path #######
################################################################
function move_path
{
	mkdir -p $TARGET_DIR
	echo "src-dir $LCL_SRC_DIR"
	echo "\n $DATE - \n Moveing wbesite directory to target-dir \n"
	mv -v $LCL_SRC_DIR/* $LCL_SRC_DIR/.*  $TARGET_DIR

	echo "\n $DATE - Cleanup leftovers direcotries \n"
	if [ -z "$BASE_DIR" ]; then
		## this is a security if statment to check if the basedir var is empaty and if it does
		## empty and script would not exit then all the HTDOCS will be deleted
		echo "ERROR - could not find base-dir variable"
		exit 1
	else
		rm -r $HTDOCS/$BASE_DIR
	fi
}


######################################################################
###### extract path objects & assign to variables ####################
######################################################################
# Filter the absulote path based on the chosen arguments of SELECTED_WEBSITE + SELECTED_BACKUP_TIME + regex no object with *sql
ABSULOTE_PATH=$(cat snapshots.json \
| jq -j --arg p "$SELECTED_WEBSITE" --arg t "$SELECTED_BACKUP_TIME"  '.[] .snapshots[]
| select(.tags[]== $p )
| select(.time == $t ) .paths[]
| select( test(".sql")
| not )')
echo "Absulote src path: $ABSULOTE_PATH"

# Filter the first dir from restic ls command - use to identify relative path
RELATIVE_PATH=$(restic ls -r $AWS_REPO $BACKUP_ID | sed -n 2p)

# Extract the last dir from absulote path
LAST_DIR="$(basename $ABSULOTE_PATH)"

# Extract the first dir from absulote path
BASE_DIR=$(echo "$ABSULOTE_PATH" | awk -F "/" '{print $2}')

LCL_SRC_DIR=$HTDOCS$ABSULOTE_PATH
TARGET_DIR="$HTDOCS/$LAST_DIR"

echo "Target-dir: $TARGET_DIR"


##############################################################################
###### check if target-dir exists and if does then remove it ##########
##############################################################################
echo "\n $DATE - Check if target-dir exists and if it does then remove it"
if [ -d "$TARGET_DIR" ]; then
	echo "\n The target-dir exists and therefore it will be removed"
	rm -r $TARGET_DIR
else
	continue
fi


######################################
##### The actual files restore #######
##################################################################################################
echo "\n $DATE - Start restore - this might take a while \n"
restic -r $AWS_REPO restore $BACKUP_ID --target $HTDOCS  --exclude='*.sql' --path "$ABSULOTE_PATH"


#############################################################
###### Check if the path is relative or absolute ############
###### & based on path kind use move function or continue ###
#############################################################
echo "Base-dir: $BASE_DIR"

if [[ $RELATIVE_PATH == "/$BASE_DIR" ]]; then # Test if path is relative or absolute
	# use absolute path function
	move_path
  	echo "Found absolute path"
		echo "Absulote-path: $ABSULOTE_PATH"
  	path_is="absolute"
else
	# use relative path function
		echo "Found relative path"
		echo "Relative-path: $RELATIVE_PATH"
  	path_is="relative"

		continue
fi

#############################################################
##### DB restore & migration proccess for WP website ########
#############################################################
##### Configure WP DB Credentials ########
##########################################
# Ask user if he want to assign new sql credentials to the website
SQL_CREDENTIALS=( 'New SQL credentials' 'Orignin SQL credentials' )
list_input "Assign New SQL credentials for the website OR use the origin SQL credentials ?" SQL_CREDENTIALS selected_sql_credentials

if [ "$selected_sql_credentials" == "New SQL credentials" ]; then
	while true
	do
		read -r -p "What is the sql user, pls enter the user name " NEW_SQL_USER
		read -r -p "What is the sql pass, pls enter the password " NEW_SQL_PASS

  		echo "\n"
  		echo "Website user sql credentials"
  		echo "New sql user $NEW_SQL_USER"
  		echo "New sql pass $NEW_SQL_PASS"

		read -r -p "Are You Sure? [Y/n] " input

		case $input in
			[yY][eE][sS]|[yY])
				echo "Yes"

				echo "\n $DATE - Change sql credentials at wp-config.php \n"
				wp --allow-root --path=$TARGET_DIR config set DB_USER "$NEW_SQL_USER" --raw
				wp --allow-root --path=$TARGET_DIR config set DB_PASSWORD "$NEW_SQL_PASS" --raw

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


#######################################################################
###### prompt sql admin credemtials ###################################
#######################################################################
echo "\n $DATE - sql admin credemtials \n"
echo "For the restore proccess of the DB, mysql will need to use admin user with global privileges"
while true
do
	read -r -p "Pls enter sql admin user name " ADMIN_SQL_USER
	read -r -p "Pls enter sql admin password " ADMIN_SQL_PASS

  	echo "\n"
  	echo "SQL Admin Credentials"
  	echo "Admin sql user $ADMIN_SQL_USER"
  	echo "Admin sql pass $ADMIN_SQL_PASS"

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


################################################################################################
###### check if db exists and if it does it would be recommended to drop it  ###################
################################################################################################
echo "Check if db exists and if it does, it would be recommended to drop it"
wp db drop  --allow-root --path=$TARGET_DIR # Drop db based on the website credentials of wp-config.php
wp db create --allow-root --path=$TARGET_DIR # Create a db based on the website credentials of wp-config.php


#######################################################################
######  Restore DB in new SQL server  #################################
#######################################################################
echo "\n $DATE - Restore DB in a new SQL server \n"

# Filter the db sql file path based on the chosen arguments of SELECTED_WEBSITE + SELECTED_BACKUP_TIME + regex object with *sql
DB_PATH=$(cat snapshots.json | \
jq -j --arg p "$SELECTED_WEBSITE" --arg t "$SELECTED_BACKUP_TIME" '.[] .snapshots[]
| select(.tags[]== $p )
| select(.time == $t ) .paths[]
| select( test(".sql") )')

if [[ $path_is == absolute ]]; then
	DB_PATH="${DB_PATH:1}" # Remove first character from string

	restic --cleanup-cache -r $AWS_REPO dump $BACKUP_ID $DB_PATH \
	| mysql -u $ADMIN_SQL_USER --password=$ADMIN_SQL_PASS
	echo "Absolute path for db restore"

else
	# Path is relative
	DB_PATH="$(basename $DB_PATH)" # Extract file.sql name from the path

	restic --cleanup-cache -r $AWS_REPO dump $BACKUP_ID $DB_PATH \
	| mysql -u $ADMIN_SQL_USER --password=$ADMIN_SQL_PASS

fi

## strange behaviour
## it seems as the sql restore with absolute path need the path of the file + file names
## but relative path need only the file name file.sql


#######################################################################
###### get db name +prefix based on wp-config file  ###################
#######################################################################
echo "Collect data from website"
DB_NAME=$( wp --allow-root --path=$TARGET_DIR config get DB_NAME)
DB_PREFIX=$( wp --allow-root --path=$TARGET_DIR config get table_prefix)
echo "DB-Name: $DB_NAME"
echo "Prefix: $DB_PREFIX"

# Fetch SITE URL
URL_SRC=$(mysql -u $ADMIN_SQL_USER -p$ADMIN_SQL_PASS $DB_NAME -N -e"SELECT option_value  FROM ${DB_PREFIX}options WHERE option_name = 'siteurl'")
echo "Source URL: $URL_SRC"


#######################################################################
###### URL search & replace  ##########################################
#######################################################################
echo "\n $DATE - URL search & replace \n"
while true
do
	echo "Examples: http://website.com or http://localhost:8888/website"
	echo "SOURCE URL: $URL_SRC"

	# Read -r -p "What is the SOURCE URL, pls enter the url " URL_SRC / Fetch from DB
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


#######################################################################
############ check plugins for error  #################################
#######################################################################

echo "\n $DATE - Check plugins for error \n"
PLUGIN_CHECK=$(mktemp -t PLUGINTEST)
	wp --allow-root --path=$TARGET_DIR plugin list &>$PLUGIN_CHECK &
	pid=$!
	wait $pid
	PLUGINTEST=$(<$PLUGIN_CHECK)
	rm $PLUGIN_CHECK

if [[ $PLUGINTEST =~ [^error] ]]; then
	echo "It seems like we found an error with the plugins"
	echo "We will try to disable all plugins from db and present you the full check results"

	mysql -u $ADMIN_SQL_USER -p$ADMIN_SQL_PASS $DB_NAME -N -e"DELETE  FROM ${DB_PREFIX}options WHERE option_name = 'active_plugins'"

	wp --allow-root --path=$TARGET_DIR plugin verify-checksums --all

	echo"You will need to activate all plugins manually as some files are mssing"

else

	echo "No Error"
	continue

fi


#######################################################################
############ Start search-replace   ###################################
#######################################################################

echo "\n $DATE - Start search-replace  FROM:$URL_SRC  TO:$URL_TARGET\n"
wp --allow-root --path=$TARGET_DIR search-replace $URL_SRC $URL_TARGET

echo "Restore process completed"


#######################################################################
############ Flush the .htaccess to the new domain ####################
#######################################################################

echo "\n $DATE - Flush the .htaccess \n"
# Create a wp-cli.yml file with apache_modules: - mod_rewrite in the root dir of the website
touch $TARGET_DIR/wp-cli.yml
chmod 666 $TARGET_DIR/wp-cli.yml
echo "apache_modules: \n - mod_rewrite" >> $TARGET_DIR/wp-cli.yml

# Change .htaccess  premmissions
chmod 666 $TARGET_DIR/.htaccess

# Run the wp rewrite flush --hard
cd $TARGET_DIR
wp --allow-root rewrite flush --hard

# Change back the .htaccess permisions
chmod 644 $TARGET_DIR/.htaccess

# Remove wp-cli.yml
rm $TARGET_DIR/wp-cli.yml

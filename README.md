# Restic Restore/Migration WP

The aim of this project is to provide an "easy to use" restore/migration for Restic backups of Wordpress websites

## Getting Started
#### Restore  
  - The restore script will only restore the chosen restic backup as it is on the same server 
#### Migration
  - The migration script would restore a chosen restic backup into a new server (local or remote)


## Prerequisites
#### Dependencies 
* [JQ](https://stedolan.github.io/jq/)
* [WP-CLI](https://wp-cli.org/)
* [Restic](https://restic.net/)

#### Restic backup configuration dependencies
- The restore/migration scripts whare originally written for restic repo with multiple websites 
-  \+ the use of tags as a website identification name
```
"tags": [ "Website_name" ]
```
- Therefore one will have to follow the same concept of tag as identification either for one website or for multiple 


## Installing
- Install all dependencies 
- Clone the repo into any folder under home  ~/*
- Add credentials into .restic-keys file 
  - In the .restic-keys one should enter all needed credentials, such as: REPO ,RESTIC_PASSWORD, AWS_ACCESS_KEY_ID etc..
- Add HTDOCS (Public folder) target path in .restic-keys file (relevant only for migration) 


## How To Use 

Migration script 
```
sudo sh ./migrate-inquirer.sh
```

Restore script

```
sudo sh ./restore-inquirer.sh
```

1. Chose website 
2. Chose backup timestamp 
3. Follow the rest of the script ;-)

----------------

### ToKnow
- The script will need to use Sudo 
- For the MySQL changes, an admin user will be needed 

### ToDo 
- rebuild the restore script (as it is doesn't work at the moment) 
- add an option to handle SQL server that is not localhost
- add an option to trigger backup on src server before starting the migration
- add an option to handle static websites
- if plugin error is found then run a script to activate all plugins one by one

### ToTest 
- restore with absolute path

## Built With

* [Inquirer.sh](https://github.com/tanhauhau/Inquirer.sh) - Bash interative terminal prompts

#! /bin/bash
#chmod +x /c/wamp64/www/testdfwp/
#chmod +x /d/WEB2013/WP_CLI/Scripts/uninstall-wp.sh
#bash /d/WEB2013/WP_CLI/Scripts/dfwp/uninstall.sh "testdfwp"
# Include the config file
source config.sh

#if [ $# -ne 1 ]; then
#    echo $0: usage: Installation name
#    exit 1
#fi

DEST=$foldername

read -p "Are you sure you want to delete the files and DB for '$DEST'?" -n 1 -r
echo    # Move to new line
if [[ $REPLY =~ ^[Yy]$ ]]
then

    echo 'Deleting files...'

    # Delete files
    rm -rf $rootpath/$DEST/

    # Delete the database.
    DB_NAME=$(echo $DEST | sed -e 's/-/_/g')
    echo "Deleting database $dbname..."

    mysql -u$dbuser -p$dbpass -e"DROP DATABASE $dbname"

    echo 'WordPress install deleted successfully.'
fi
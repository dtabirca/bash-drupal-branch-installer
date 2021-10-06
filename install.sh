#!/bin/bash

PROJECT="project"
BRANCH=$1
FOLDER=$PROJECT-$BRANCH
GITHUB_USER="githubuser"
GITHUB_TOKEN="githubtoken"
GITHUB_LINK="github.com/path/to/project.git"
DATABASE_FILE="/path/to/mysql/dump.sql"
DRUPALUSER="drupaluser"
DRUPALPASS="drupalpass"
GROUP="group"
OWNER="owner"

cd /opt/lampp/htdocs
if [[ -d $FOLDER ]]
then
    echo "${FOLDER} already exists."
	read -p "Do you want to continue?" -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]] # || $REPLY = "" 
	then
	    rm -rf $FOLDER
	else
		exit
	fi
fi

echo "1. cloning from GitHub"
git clone https://${GITHUB_USER}:${GITHUB_TOKEN}@${GITHUB_LINK} ${FOLDER}
cd /opt/lampp/htdocs/${FOLDER}
echo "2. composer install --no-interaction"
composer install

echo "3. setup local settings"
cp /opt/lampp/htdocs/bin/$PROJECT.settings.local.php /opt/lampp/htdocs/$FOLDER/web/sites/default/settings.local.php
DATABASENAME=${FOLDER//-/_}
sed -i -e "s/DRUPALDATABASE/$DATABASENAME/g" /opt/lampp/htdocs/$FOLDER/web/sites/default/settings.local.php

echo "4. create tmp folder"
mkdir /opt/lampp/htdocs/$FOLDER/web/sites/default/files/tmp
chmod 0777 /opt/lampp/htdocs/$FOLDER/web/sites/default/files/tmp

echo "5. fix footer menu php version conflict"
sudo cp /opt/lampp/htdocs/bin/$PROJECT.footer--menu.twig /opt/lampp/htdocs/$FOLDER/web/themes/custom/compony/components/footer/footer--menu.twig

echo "6. change ownership"
chown -R $OWNER:$GROUP /opt/lampp/htdocs/${FOLDER}

echo "7. create mysql user and database"
/opt/lampp/bin/mysql -u root --password="" -e "
CREATE DATABASE IF NOT EXISTS $DATABASENAME;
USE $DATABASENAME;
CREATE USER IF NOT EXISTS '$DATABASENAME'@'localhost' IDENTIFIED BY '$DATABASENAME';
GRANT ALL PRIVILEGES ON *.* TO '$DATABASENAME'@'localhost' IDENTIFIED BY '$DATABASENAME' WITH GRANT OPTION;
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER, CREATE VIEW, SHOW VIEW, TRIGGER ON $DATABASENAME.$DATABASENAME TO '$DATABASENAME'@'localhost';
FLUSH PRIVILEGES;"

echo "8. import database"
/opt/lampp/bin/mysql -u root --password="" $DATABASENAME < $DATABASE_FILE

echo "9. drush commands"
cd /opt/lampp/htdocs/${FOLDER}
./vendor/bin/drush cr
./vendor/bin/drush en devel
./vendor/bin/drush user-password $DRUPALUSER $DRUPALPASS 
./vendor/bin/drush sset cron_safe_threshold 0
./vendor/bin/drush status

echo "10. edit vhosts & restart apache"
cp /opt/lampp/htdocs/bin/httpd-vhosts.conf /opt/lampp/etc/extra/httpd-vhosts.conf
sed -i -e "s/DRUPALFOLDER/$FOLDER/g" /opt/lampp/etc/extra/httpd-vhosts.conf
sudo /opt/lampp/lampp stop
sudo /opt/lampp/lampp start

#/usr/bin/firefox --new-window URL
#!/bin/bash

sleep 10
 #if wp-config.php doesn't exists
wp config create --allow-root \
				--dbname=$MDB_DB \
				--dbuser=$MDB_USR \
				--dbpass=$MDB_PSSWRD \
				--dbhost=mariadb:3306 --path='/var/www/wordpress'

wp core install
#try to connect to mariadb in a loop til mariadb is ready and wordpress can connect?
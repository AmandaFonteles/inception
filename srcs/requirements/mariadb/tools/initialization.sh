#!/bin/bash

service mysql start;

mysql -e "CREATE DATABASE IF NOT EXISTS \`${MDB_DB}\`;"

mysql -e "CREATE USER IF NOT EXISTS \`${MDB_USR}\`@'localhost' IDENTIFIED BY '${MDB_PASSWORD}';"

mysql -e "GRANT ALL PRIVILEGES ON \`${MDB_DB}\`.* TO \`${MDB_USR}\`@'%' IDENTIFIED BY '${MDB_PASSWORD}';"

# do I need that?
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MDB_PASSWORD}';"

mysql -e "FLUSH PRIVLEGES;"

mysqladmin -u -p $MDB_PASSWORD shutdown

exec mysqld_safe

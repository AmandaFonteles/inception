#!/bin/bash
# MariaDB entrypoint. Runs as root (needed for chown), then hands the
# process over to mysqld, which drops to the mysql user itself.

# -e  exit on any command failure
# -u  error on unset variables — catches a missing .env entry immediately
# -o pipefail  a pipeline fails if any stage fails, not just the last
set -euo pipefail

# $( ) strips the trailing newline if the host file has one.
DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"
DB_PASSWORD="$(cat /run/secrets/db_password)"

# Recreated on every start because /run is not persisted across restarts.
# -R flag is used to apply the ownership change recursively to all files and directories within /run/mysqld
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql

if [ ! -d /var/lib/mysql/mysql ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
fi

# --bootstrap: mysqld reads SQL from stdin, applies it, exits. Single-user
# mode, no networking, no daemon.
if [ ! -f /var/lib/mysql/.inception_seeded ]; then
    mysqld --bootstrap <<EOF
FLUSH PRIVILEGES;
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
EOF
    touch /var/lib/mysql/.inception_seeded
fi

# exec replaces this shell with mysqld, so mysqld becomes PID 1 and receives
# SIGTERM from `docker stop` directly.
# Foreground, no loop, no background job.
exec mysqld
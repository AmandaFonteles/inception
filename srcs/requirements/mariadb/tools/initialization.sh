#!/bin/bash
# MariaDB entrypoint. Runs as root (needed for chown), then hands the
# process over to mysqld, which drops to the mysql user itself.

# -e  exit on any command failure
# -u  error on unset variables — catches a missing .env entry immediately
# -o pipefail  a pipeline fails if any stage fails, not just the last
set -euo pipefail

# --- Secrets -------------------------------------------------------------
# Docker mounts each granted secret as a read-only file at
# /run/secrets/<declared-name>. Not an env var, and not available at build
# time. $( ) strips the trailing newline if the host file has one.
DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"
DB_PASSWORD="$(cat /run/secrets/db_password)"

# --- Runtime directories -------------------------------------------------
# Recreated on every start because /run is not persisted across restarts.
# -R flag is used to apply the ownership change recursively to all files and directories within /run/mysqld
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld

# The datadir is a volume backed by a host directory owned by afontele.
# A chown in the Dockerfile would have touched the image's empty
# /var/lib/mysql, which the volume then hides. It has to happen here.
chown -R mysql:mysql /var/lib/mysql

# --- First-run initialisation -------------------------------------------
# Two separate guards, because these two steps can fail independently.
# Guarding both on one condition means a failure in the second step leaves
# a datadir that passes the guard forever and is never seeded.

# /var/lib/mysql/mysql is the system schema. Its absence means the datadir
# has never been laid down.
if [ ! -d /var/lib/mysql/mysql ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
fi

# Own flag file, written only after the SQL has actually applied.
# --bootstrap: mysqld reads SQL from stdin, applies it, exits. Single-user
# mode, no networking, no daemon.
# --bootstrap implies --skip-grant-tables, so account statements are
    # rejected with error 1290. FLUSH PRIVILEGES loads the grant tables into
    # memory and re-enables privilege checking for the rest of this batch.
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

# --- Hand over -----------------------------------------------------------
# exec replaces this shell with mysqld, so mysqld becomes PID 1 and receives
# SIGTERM from `docker stop` directly — a clean shutdown, no data loss.
# Foreground, no loop, no background job.
exec mysqld
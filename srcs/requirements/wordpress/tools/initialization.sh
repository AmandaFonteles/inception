#!/bin/bash

# Runs as root: it has to write into the volume and
# chown it, then hands the process over to php-fpm.

# -e  exit on any command failure
# -u  error on unset variables — catches a missing .env entry immediately
# -o pipefail  a pipeline fails if any stage fails, not just the last
set -euo pipefail

DB_PASSWORD="$(cat /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/wp_adm_password)"
WP_USER_PASSWORD="$(cat /run/secrets/wp_user_password)"

# wp-settings.php is a core file: its absence proves the volume is unpopulated.
if [ ! -f /var/www/html/wp-settings.php ]; then
	# The trailing /. copies the contents of the directory, dotfiles included.
	cp -r /var/www/wordpress/. /var/www/html/
fi

# depends_on only waits for the container to start, not for mysqld to accept
# connections. Bounded to 30 attempts: no infinite loop, and if the database
# is genuinely down this container exits and Docker restarts it.
DB_READY=0
for i in $(seq 30); do
	# mariadb client connection test: it uses mariadb_client to try
	# to connect to amke sure mariadb is accepting connections
	if mariadb -h mariadb -u "${MYSQL_USER}" -p"${DB_PASSWORD}" -e "SELECT 1;" > /dev/null 2>&1; then
		DB_READY=1
		break
	fi
	sleep 1
done

if [ "${DB_READY}" -eq 0 ]; then
	echo "mariadb did not answer after 30 attempts" >&2
	exit 1
fi

# config of the connection between mariadb and wordpress
if [ ! -f /var/www/html/wp-config.php ]; then
	wp config create \
		--path=/var/www/html \
		--dbname="${MYSQL_DATABASE}" \
		--dbuser="${MYSQL_USER}" \
		--dbpass="${DB_PASSWORD}" \
		--dbhost=mariadb:3306 \
		--allow-root
fi

# check if wordpress is already installed and config of wordpress is already done
#  if not we install and config wordpress and create the second user
if ! wp core is-installed --path=/var/www/html --allow-root; then
	wp core install \
		--path=/var/www/html \
		--url="https://${DOMAIN_NAME}" \
		--title="${WP_TITLE}" \
		--admin_user="${WP_ADMIN_USER}" \
		--admin_password="${WP_ADMIN_PASSWORD}" \
		--admin_email="${WP_ADMIN_EMAIL}" \
		--skip-email \
		--allow-root

	wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
		--role=author \
		--user_pass="${WP_USER_PASSWORD}" \
		--path=/var/www/html \
		--allow-root
fi

chown -R www-data:www-data /var/www/html

# -F (--nodaemonize) keeps php-fpm in the foreground. Without it php-fpm
# forks, the parent exits, and the container stops immediately.
# exec replaces this shell, so php-fpm becomes PID 1 and receives SIGTERM
# from `docker stop` directly. Foreground, no loop, no background job.
exec php-fpm8.2 -F
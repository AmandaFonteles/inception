# Dockerfile Wordpress
# Build context: srcs/requirements/wordpress

FROM debian:bookworm

# wget            : downloads WordPress and WP-CLI
# ca-certificates : needed by wget
# php-fpm         : the FastCGI process manager NGINX forwards .php requests to
# php-cli         : provides /usr/bin/php — WP-CLI is a PHP script and cannot run without it
# php-mysql       : the driver PHP uses to talk to MariaDB
# mariadb-client  : provides mariadb-admin, used by the entrypoint to test if the DB is up
RUN apt-get update && apt-get install -y --no-install-recommends \
	ca-certificates \
	wget \
	php8.2-fpm \
	php8.2-cli \
	php8.2-mysql \
	mariadb-client \
	&& rm -rf /var/lib/apt/lists/*

# Download, unpack to staging, delete the archive.
# -P is where wget saves it, -C is where tar unpacks it.
RUN mkdir -p /var/www \
	&& wget https://wordpress.org/wordpress-7.0.2.tar.gz -P /tmp \
	&& tar -xzf /tmp/wordpress-7.0.2.tar.gz -C /var/www \
	&& rm /tmp/wordpress-7.0.2.tar.gz

# Download WP-CLI, make it executable, and move it to a directory in the PATH.
RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
RUN chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

COPY tools/initialization.sh /usr/local/bin/initialization.sh
RUN chmod +x /usr/local/bin/initialization.sh

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/initialization.sh"]
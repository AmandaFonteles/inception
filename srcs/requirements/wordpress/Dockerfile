# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: afontele <afontele@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/07/15 13:50:19 by afontele          #+#    #+#              #
#    Updated: 2026/07/28 16:32:17 by afontele         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM debian:bookworm

RUN apt-get update && apt-get install -y wget\
php\
php-fpm\
php-mysql\
mariadb-client\
&& rm -rf /var/lib/apt/lists/*

RUN wget https://wordpress.org/wordpress-6.9.4.tar.gz -P /var/www

RUN cd /var/www && tar -xzf wordpress-6.9.4.tar.gz && rm wordpress-6.9.4.tar.gz

RUN chown -R root:root /var/www/wordpress #or data-www:data-wwww ?

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

RUN chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp

COPY initialization.sh /initialization.sh

RUN chmod +x /initialization.sh

EXPOSE 9000

ENTRYPOINT ["/initialization.sh"]
# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Dockerfile                                         :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: afontele <afontele@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2026/07/10 16:28:32 by afontele          #+#    #+#              #
#    Updated: 2026/07/15 16:57:17 by afontele         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

FROM debian:bookworm

# install  nginx
RUN apt-get update && apt-get install -y nginx

# install OpenSSL
RUN apt-get install -y OpenSSL

# create a folder for key and certificate
RUN mkdir -p /etc/nginx/ssl

# generate the SSL(TSL) certificate (since is local, we can generate key and certificate together (?))
# recheck this cmd!!!!
RUN OpenSSL req -x509 -nodes -out /etc/nginx/ssl/nginxincep.ctr -keyout /etc/nginx/ssl/nginxincep.key -subj "/C=FR/ST=IDF/L=Paris/O=42/OU=42/CN=afontele.42.fr/UID=afontele"

# copy config to the container (CHECK THE CONFIG PATH BEFORE PUSH)
COPY  --from=srcs/requirements/nginx/conf /nginx.conf /etc/nginx/

EXPOSE 433

# setting nginx to run in the foreground
CMD [ "nginx", "-g", "daemon off;" ]
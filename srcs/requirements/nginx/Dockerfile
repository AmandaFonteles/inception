# nginx Dockerfile
# Build context: srcs/requirements/nginx

FROM debian:bookworm

# install  nginx and openssl
RUN apt-get update && apt-get install -y nginx openssl \
	&& rm -rf /var/lib/apt/lists/*

# create a folder for key and certificate
# generate the SSL(TSL) certificate (since is local, we can generate key and certificate together)
# - req -x509: generate a self-signed certificate
# - nodes: do not encrypt the private key
# - days 365: set the validity of the certificate to 365 days
# - newkey rsa:2048: generate a new RSA key with 2048 bits
# -out: specify the output file for the certificate
# -keyout: specify the output file for the private key
# - subj: set the subject of the certificate (C=country, ST=state, L=locality, O=organization, OU=organizational unit, CN=common name, UID=user id)
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out /etc/nginx/ssl/nginxincep.crt -keyout /etc/nginx/ssl/nginxincep.key \
	-subj "/C=FR/ST=IDF/L=Paris/O=42/OU=42/CN=afontele.42.fr/UID=afontele"

# copy config to the container (copy from build context to the container filesystem root)
COPY conf/nginx.conf /etc/nginx/nginx.conf

EXPOSE 443

# setting nginx to run in the foreground
CMD [ "nginx", "-g", "daemon off;" ]
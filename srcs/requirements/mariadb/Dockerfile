# Dockerfile MariaDB (database)

FROM debian:bookworm

RUN apt-get update && apt-get install -y mariadb-server

COPY conf/50=server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

# EXPOSE 3306
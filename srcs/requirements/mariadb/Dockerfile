# Dockerfile MariaDB (database for WordPress)
# Build context: srcs/requirements/mariadb

# Base image
FROM debian:bookworm

# Install MariaDB server
RUN apt-get update && apt-get install -y mariadb-server && rm -rf /var/lib/apt/lists/*

# Copy the custom MariaDB server configuration file to the appropriate location
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

# Entrypoint script. Copied into /usr/local/bin because that is the
# conventional location for localy-installed executables and is on PATH.
COPY tools/initialization.sh /usr/local/bin/initialization.sh

RUN chmod +x /usr/local/bin/initialization.sh

# it records that this image listens on 3306 for anyone reading `docker inspect`.
# Reachability between containers comes from the shared `inception` network, not from this line.
EXPOSE 3306

# Start the MariaDB server using the entrypoint script - is PID 1 (receives signals)
ENTRYPOINT ["/usr/local/bin/initialization.sh"]
*This project has been created as part of the 42 curriculum by afontele.*

# Inception

## Description

Inception builds a small web infrastructure from scratch inside a virtual
machine, orchestrated with Docker Compose. Three services, three containers,
three Dockerfiles:

| Service     | Role                                                        |
|-------------|-------------------------------------------------------------|
| `mariadb`   | The database holding the WordPress tables.                   |
| `wordpress` | WordPress plus php-fpm. Executes PHP. No web server inside.  |
| `nginx`     | The only entrypoint. Terminates TLS on 443, proxies to php-fpm. |

Every image is built locally from `debian:bookworm` (the penultimate stable
Debian). No pre-built service images are pulled, no `latest` tag is used
anywhere. The containers talk to each other over a user-defined bridge
network named `inception`; only NGINX publishes a port to the host, and only
443, TLSv1.2/TLSv1.3.

Two named volumes hold all persistent state — the database files and the
WordPress site files — and both are backed by `/home/afontele/data/`, so the
site survives `docker compose down` and a VM reboot.

The site is served at **https://afontele.42.fr**. Plain HTTP is not served
at all: NGINX has no `listen 80` directive and port 80 is not published.

## Instructions

Full setup from a clean clone is in **DEV_DOC.md**. Day-to-day usage is in
**USER_DOC.md**. The short version:

- make — create host data dirs, build the images, start the stack
- make down — stop and remove the containers
- make ps — show container state
- make logs — show service logs
- make fclean — remove containers, volumes, images, and the host data dirs
- make re — fclean followed by a full rebuild

Prerequisites that live on the host, not in this repository, and must exist
before `make` will work:

- Docker Engine and the `docker compose` v2 plugin.
- `srcs/.env`, copied from `srcs/.env.example`.
- The four password files under `secrets/`.
- A `127.0.0.1 afontele.42.fr` line in `/etc/hosts`.

DEV_DOC.md walks through each one.

## Project description

### Use of Docker

Each service runs as one process in one container, built from a Dockerfile in
`srcs/requirements/<service>/`. Compose builds all three, wires them onto a
shared network, attaches the volumes, and injects the secrets. The Makefile
never calls `docker` directly for the services — it calls `docker compose`,
which reads `srcs/docker-compose.yml`, which references the Dockerfiles.

### Sources included

- `srcs/docker-compose.yml` — service, network, volume, and secret definitions.
- `srcs/.env.example` — non-secret configuration: domain, database name,
  database user, WordPress usernames, emails, site title.
- `srcs/requirements/mariadb/` — Dockerfile, `conf/50-server.cnf`,
  `tools/initialization.sh`.
- `srcs/requirements/wordpress/` — Dockerfile, `conf/www.conf`,
  `tools/initialization.sh`.
- `srcs/requirements/nginx/` — Dockerfile, `conf/nginx.conf`.
- `secrets/` — `.example` templates only. The real password files are
  gitignored.

### Main design choices

**No service daemonizes.** A daemon forks a background copy and the original
process exits — in a container that kills the container instantly, because the
container's lifetime is PID 1's lifetime. NGINX runs with `daemon off;`,
php-fpm with `-F`, and the MariaDB entrypoint ends in `exec mysqld` so mysqld
replaces the shell and becomes PID 1 itself. No `tail -f`, no `sleep infinity`,
no background job anywhere.

**WordPress is staged outside the volume.** The tarball is unpacked at build
time to `/var/www/wordpress`. The volume mounts over `/var/www/html` and would
hide anything the image had written there, so the entrypoint copies the staged
files into the web root only when the volume is empty. This is what makes the
first run work and the second run leave existing data alone.

**Both entrypoints are idempotent.** MariaDB skips `mariadb-install-db` when
`/var/lib/mysql/mysql` exists, and skips seeding when its own flag file exists.
WordPress skips `wp config create` when `wp-config.php` exists and skips
`wp core install` when the database already reports an install. The container
is disposable; the volume is not.

**The readiness wait is bounded.** `depends_on` waits for the MariaDB
*container* to start, not for mysqld to accept connections. The WordPress
entrypoint retries the connection 30 times, then exits non-zero. It is a
bounded loop, not an infinite one — if the database is genuinely down the
container exits and the restart policy retries the whole thing.

### Virtual Machines vs Docker

A VM virtualizes hardware and boots its own kernel: a whole second computer.
A container is an isolated process sharing the host kernel. That makes
containers far cheaper to start and to ship, at the cost of weaker isolation —
a container cannot run a different kernel from its host. This project uses
both, and the reason is instructive: the VM gives me a Debian machine I can
break and rebuild without touching the school's Fedora host, and inside it
Docker gives me three services I can tear down and recreate in seconds.

### Secrets vs Environment Variables

Environment variables are visible in `docker inspect`, in the process
environment of every child process, and often in logs. They are the right
place for configuration that is not sensitive — domain name, database name,
usernames — which is what `.env` holds here.

Docker secrets arrive as read-only files at `/run/secrets/<name>`, mounted
into only the containers that declare them. They are never environment
variables. Every password in this project is a secret; the entrypoints read
them with `$(cat /run/secrets/db_password)` and equivalents. `mariadb` gets
`db_root_password` and `db_password`; `wordpress` gets `db_password` and the
two WordPress passwords; `nginx` gets none, because it needs none.

### Docker Network vs Host Network

`network: host` would drop the containers straight onto the VM's network
stack: no isolation, port collisions between services, and every container
port reachable from outside.

Instead the three containers sit on a user-defined bridge network,
`inception`. Docker's embedded DNS resolves service names on it, which is why
`fastcgi_pass wordpress:9000` and `--dbhost=mariadb:3306` work without a
single IP address anywhere in the configuration. Only NGINX publishes a port
to the host. MariaDB's 3306 and php-fpm's 9000 are reachable from inside the
network and nowhere else.

### Docker Volumes vs Bind Mounts

A bind mount attaches a host path to a container path. It is declared inline
on the service, Docker manages nothing about it, and it has no existence
independent of the service definition.

A named volume is a first-class object Docker creates and manages, with its
own lifecycle, visible in `docker volume ls`. Both stores here are named
volumes, declared in the top-level `volumes:` section.

The subject also requires the data to land in `/home/afontele/data`. I get
both by passing `driver_opts` to the default `local` driver — `type: none`,
`o: bind`, `device: /home/afontele/data/<service>` — so the driver reaches the
host path I chose. The bind is the plumbing; the volume is still the object.
What the subject forbids is the inline bind-mount object model, not the bind
mechanism. The consequence is that the host directories must exist before
`docker compose up`, which is why the Makefile's `up` target runs `mkdir -p`
first.

## Resources

- Docker documentation — Dockerfile reference, Compose file reference,
  volumes, secrets, networking.
- MariaDB documentation — `mariadb-install-db`, `mysqld --bootstrap`,
  server system variables.
- WordPress.org — release downloads; WP-CLI handbook for `config create`,
  `core install`, `user create`.
- NGINX documentation — `ssl_protocols`, `try_files`, `fastcgi_pass`.
- The 42 Inception subject PDF.

### Use of AI

AI was used as a helper tool, in a question-and-answer mode:

- correcting English documentation
- finding relevant sources
- providing detailed explanation
- reviewing specific parts of code and helping with debug
# DEV_DOC — Inception

How to set this project up from nothing, build it, and work on it.
For day-to-day operation see USER_DOC.md.

Everything here is done inside the Debian virtual machine, not on the host
that runs VirtualBox.

## 1. Prerequisites

### On the VM

| Requirement | Why |
|---|---|
| Debian (VM guest) | The subject requires the project to run in a VM. |
| Docker Engine | Builds and runs the containers. |
| `docker compose` v2 plugin | Reads `srcs/docker-compose.yml`. Invoked as `docker compose`, two words. |
| `make` | Not installed by default on a minimal Debian. `make` is the required entry point of the project, so without it nothing starts. |
| `git` | To clone the repository. |

`make` is genuinely missing on a fresh Debian install — this is not a
theoretical prerequisite:

```bash
sudo apt update
sudo apt install make
```

Docker Engine is installed from Docker's own apt repository, not from the
`docker.io` Debian package, so that `docker compose` v2 is available.
Follow the official instructions:
https://docs.docker.com/engine/install/debian/

After installing, add your user to the `docker` group so `docker` works
without `sudo`:

```bash
sudo usermod -aG docker $USER
```

Log out and back in for the group change to take effect. Note that membership
of the `docker` group is effectively root on the machine — acceptable here
because this VM is single-user and disposable, and worth knowing rather than
doing blindly.

Check the three tools:

```bash
docker --version
docker compose version
make --version
```

### On the VM's hosts file

The domain has to resolve to the VM itself. Add this line to `/etc/hosts`:

```
127.0.0.1 afontele.42.fr
```

```bash
sudo nano /etc/hosts
```

Verify:

```bash
getent hosts afontele.42.fr     # expect: 127.0.0.1  afontele.42.fr
```

Without this, the browser cannot resolve the domain and nothing is reachable,
even with all three containers healthy.

## 2. Setup from scratch

```bash
git clone <repository-url> inception
cd inception
```

The repository deliberately does **not** contain any credential. Two things
have to be created by hand before the first build. Both are gitignored, and
`make` fails without them.

### 2.1 The environment file

```bash
cp srcs/.env.example srcs/.env
```

`srcs/.env` holds non-secret configuration only: the domain name, the database
name, the database user, the two WordPress usernames and emails, and the site
title. It contains no password.

The committed `.env.example` already carries working values for this project,
so the copy is usually enough. Edit `srcs/.env` if you are deploying under a
different login or domain — and if you change `DOMAIN_NAME`, change it in
three other places too: `server_name` in `srcs/requirements/nginx/conf/nginx.conf`,
the `-subj` and `-addext` arguments of the `openssl` command in the NGINX
Dockerfile, and `/etc/hosts`.

The WordPress administrator username must not contain `admin`, `Admin`,
`administrator` or `Administrator` as a substring. The subject rejects the
project otherwise.

### 2.2 The secret files

Four files, one password each, under `secrets/`. Only `.example` templates are
committed; the real files never are.

```bash
cd secrets
echo -n 'CHOOSE_A_ROOT_PASSWORD'  > db_root_password.txt
echo -n 'CHOOSE_A_DB_PASSWORD'    > db_password.txt
echo -n 'CHOOSE_AN_ADMIN_PASSWORD' > wp_adm_password.txt
echo -n 'CHOOSE_A_USER_PASSWORD'  > wp_user_password.txt
cd ..
```

`echo -n` suppresses the trailing newline. A newline would become part of the
password, since the entrypoints read the whole file with `cat`.

Restrict the permissions:

```bash
chmod 600 secrets/*.txt
```

Check what you have, without printing the contents:

```bash
ls -l secrets/
wc -c secrets/*.txt     # byte counts must match your password lengths exactly
```

If a count is one byte larger than expected, a newline slipped in — rewrite
that file with `echo -n`.

### 2.3 Confirm nothing sensitive is tracked

```bash
git check-ignore -v srcs/.env secrets/db_password.txt
git status --short
```

The first command must print a matching `.gitignore` rule for each path. The
second must not list `.env`, any `secrets/*.txt`, or `NOTES.md`.

## 3. Build and launch

```bash
make
```

That is the whole build. The `up` target does two things, in order:

```make
up:
	mkdir -p ${DATAS}
	${COMPOSE} up -d --build
```

- `mkdir -p /home/afontele/data/mariadb /home/afontele/data/wordpress` —
  the two named volumes are backed by these host directories through
  `driver_opts`, and a bind cannot point at a path that does not exist.
  Compose fails outright if they are missing, which is why this line is part
  of `up` and not a manual step.
- `docker compose -f srcs/docker-compose.yml up -d --build` — builds the three
  images if needed, creates the network, the volumes and the secrets, and
  starts the containers detached.

Every other Makefile target wraps the same `docker compose` invocation:

| Target | Runs | Effect |
|---|---|---|
| `make` / `make all` | `up` | Build if needed and start. |
| `make build` | `compose build` | Build the images without starting. |
| `make down` | `compose down` | Stop and remove containers and network. Volumes and data untouched. |
| `make start` / `make stop` | `compose start` / `stop` | Stop and restart existing containers. |
| `make restart` | `down` then `up` | |
| `make ps` | `compose ps -a` | Container state, including exited ones. |
| `make logs` | `compose logs` | All services. |
| `make clean` | `compose down -v --rmi all` | Also removes the volumes and the images. |
| `make fclean` | `clean` + `sudo rm -rf` the data dirs | Also deletes the host data. |
| `make re` | `fclean` then `all` | Full rebuild from nothing. |

`fclean` needs `sudo` because the database files inside
`/home/afontele/data/mariadb` are owned by the container's `mysql` user, not
by `afontele`.

Running Compose directly is equivalent, as long as you point at the file:

```bash
docker compose -f srcs/docker-compose.yml ps
docker compose -f srcs/docker-compose.yml build --no-cache nginx
docker compose -f srcs/docker-compose.yml up -d --build wordpress
```

The project name is set to `inception` by the `name:` key at the top of the
Compose file, so it does not depend on the directory name and `-p` is never
needed.

## 4. Managing containers, images, volumes and network

### Containers

```bash
make ps                                  # state of all three
docker logs nginx                        # one container's logs
docker logs -f wordpress                 # follow
docker exec -it mariadb bash             # shell inside a container
docker inspect wordpress                 # full configuration as JSON
docker compose -f srcs/docker-compose.yml restart nginx   # one service
```

Confirm the right process is PID 1 in each container:

```bash
docker exec mariadb   cat /proc/1/cmdline | tr '\0' ' '; echo
docker exec wordpress cat /proc/1/cmdline | tr '\0' ' '; echo
docker exec nginx     cat /proc/1/cmdline | tr '\0' ' '; echo
```

Expect `mysqld`, `php-fpm: master process ...`, and `nginx -g daemon off;`.
Reading `/proc/1/cmdline` works in every container; `ps` needs the `procps`
package, which these images do not all install.

### Images

```bash
docker images
```

Three images, all tagged `:inception` — `mariadb:inception`,
`wordpress:inception`, `nginx:inception`. The tag is deliberate: it proves the
images are built locally, since no such tag exists on Docker Hub. `latest` is
never used, explicitly or implicitly.

### Volumes

```bash
docker volume ls
docker volume inspect inception_mariadb_vol
docker volume inspect inception_wordpress_vol
```

Compose prefixes top-level volume names with the project name, which is why
`mariadb_vol` in the Compose file appears as `inception_mariadb_vol` on disk.
Each `inspect` shows the driver options, including the `device` pointing under
`/home/afontele/data/`.

### Network

```bash
docker network ls
docker network inspect inception_inception
```

One user-defined bridge network, again prefixed with the project name. The
inspect output lists the three containers attached to it.

Name resolution between containers is Docker's embedded DNS:

```bash
docker exec nginx getent hosts wordpress
docker exec wordpress getent hosts mariadb
```

Each returns the other container's address on the bridge. This is what makes
`fastcgi_pass wordpress:9000` and `--dbhost=mariadb:3306` work with no IP
address written anywhere.

## 5. Where the data lives and how it persists

Two named volumes, declared in the top-level `volumes:` section of the Compose
file:

| Volume | Mounted at | Backed by | Contains |
|---|---|---|---|
| `mariadb_vol` | `/var/lib/mysql` in `mariadb` | `/home/afontele/data/mariadb` | The database files. |
| `wordpress_vol` | `/var/www/html` in `wordpress` and in `nginx` | `/home/afontele/data/wordpress` | WordPress core, `wp-config.php`, themes, plugins, uploads. |

`wordpress_vol` is mounted into two containers on purpose: php-fpm executes
the PHP files, and NGINX serves the static assets and needs the same files on
disk to do it.

The host path is reached by passing `driver_opts` to the default `local`
driver:

```yaml
volumes:
  mariadb_vol:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/afontele/data/mariadb
```

These are still named volumes — first-class Docker objects with their own
lifecycle, listed by `docker volume ls`. The bind is only the driver's
mechanism for reaching the directory the subject mandates. What the subject
forbids is the inline bind-mount declared on a service, which is a different
object model.

### What survives what

| Action | Data |
|---|---|
| Container crash, `restart: unless-stopped` kicks in | kept |
| `make stop` / `make start` | kept |
| `make down` (containers removed) | kept |
| VM reboot | kept |
| `make clean` (`down -v`) | volume objects removed; see below |
| `make fclean` | deleted |

Persistence works because the containers hold no state. Both entrypoints
detect an already-initialised store and skip the seeding: MariaDB skips
`mariadb-install-db` when `/var/lib/mysql/mysql` exists and skips the SQL
bootstrap when its `.inception_seeded` flag file exists; WordPress skips
`wp config create` when `wp-config.php` exists and skips `wp core install`
when the database already reports an installation. The container is
disposable; the volume is not.

Verifying persistence:

```bash
# make a visible change on the site first, then:
sudo reboot
# after the VM comes back:
cd inception && make
```

The site must come back with the change still there, and the logs must show
no re-seeding.

### Backup and restore

The data is plain files on the host, so a backup is a copy:

```bash
sudo tar czf ~/inception-backup.tar.gz -C /home/afontele/data .
```

`sudo` for the same reason as `fclean`: the MariaDB files belong to the
container's `mysql` user. Restore by stopping the stack, extracting into the
same location, and starting again.

## 6. Changing a service's configuration

Changing the port php-fpm listens on from 9000 to 9500.

1. `srcs/requirements/wordpress/conf/www.conf` — `listen = 9500`.
2. `srcs/requirements/wordpress/Dockerfile` — `EXPOSE 9500` (documentation
   only, but it should not contradict reality).
3. `srcs/requirements/nginx/conf/nginx.conf` — `fastcgi_pass wordpress:9500;`.
4. Rebuild and restart:

```bash
make down
make
```

Both images have to be rebuilt because both config files are baked in at build
time with `COPY`; `--build` in the `up` target handles that. Then check the
site still loads:

```bash
curl -kI https://afontele.42.fr
```

Changing the *published* port is different: NGINX's `443:443` in
`docker-compose.yml` is the only port exposed to the host, and changing the
host side of it means the site moves to `https://afontele.42.fr:<newport>`.
Changing the container side means changing `listen` in `nginx.conf` and
`EXPOSE` too.
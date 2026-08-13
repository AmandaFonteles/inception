# USER_DOC — Inception

Day-to-day operation of the stack. For setting the project up from a clean
clone, see DEV_DOC.md.

## What the stack provides

Three containers on one Docker network, `inception`:

| Container   | What it does                                              | Reachable from |
|-------------|-----------------------------------------------------------|----------------|
| `nginx`     | Serves the site over HTTPS on port 443. Terminates TLS.    | the host and the browser |
| `wordpress` | WordPress + php-fpm. Executes the PHP, listens on 9000.    | the `inception` network only |
| `mariadb`   | The database, listening on 3306.                           | the `inception` network only |

Two named volumes hold everything that must survive a restart:

- the database files, at `/home/afontele/data/mariadb` on the VM;
- the WordPress site files, at `/home/afontele/data/wordpress` on the VM.

Stopping or deleting the containers does not touch either directory.

## Starting and stopping

All commands are run from the repository root, on the VM.

```bash
make          # build the images if needed and start all three containers
make stop     # stop the containers, keep them
make start    # start stopped containers again
make down     # stop and remove the containers (volumes and data untouched)
make restart  # down, then up
```

`make` is the normal entry point. It creates the two host data directories if
they are missing, then runs `docker compose up -d --build`.

Destructive, in increasing order:

```bash
make clean    # down, plus remove the volumes and the images
make fclean   # clean, plus delete /home/afontele/data/* (needs sudo)
make re       # fclean, then a full rebuild from scratch
```

`make fclean` deletes the database and the site. Everything is re-seeded from
`.env` and `secrets/` on the next `make`, so the site comes back empty, with
the two users recreated and no posts.

## Accessing the site

Open **https://afontele.42.fr** in the VM's browser.

The certificate is self-signed, so the browser shows a warning. Accept it —
that is expected.

Plain HTTP is not served. `http://afontele.42.fr` fails to connect; there is
no redirect, because NGINX has no `listen 80` block and port 80 is not
published to the host.

## Accessing the administration panel

**https://afontele.42.fr/wp-admin**

Two accounts exist:

| Username   | Role          | Password file                   |
|------------|---------------|---------------------------------|
| `afontele` | Administrator | `secrets/wp_adm_password.txt`   |
| `amanda`   | Author        | `secrets/wp_user_password.txt`  |

`amanda` can write and publish her own posts and leave comments, but cannot
reach Settings, Plugins, or Users. That separation is the point: the subject
requires two users, only one of them the administrator.

The administrator username deliberately contains no `admin`, `Admin`,
`administrator`, or `Administrator` substring.

## Locating and managing credentials

### Where they live

Nothing sensitive is in the repository. Passwords live in four files under
`secrets/`, on the host:

```
secrets/db_root_password.txt     MariaDB root password
secrets/db_password.txt          MariaDB password for the wpuser account
secrets/wp_adm_password.txt      WordPress administrator password
secrets/wp_user_password.txt     WordPress author password
```

The files are created by hand;
DEV_DOC.md explains how.

Non-secret configuration — domain, database name, database user, WordPress
usernames, emails, site title — is in `srcs/.env`.

### How the containers see them

Docker mounts each granted secret as a read-only file inside the container,
under `/run/secrets/`. They are never environment variables, so they do not
appear in `docker inspect` or in any process environment.

```bash
docker exec mariadb ls -l /run/secrets/
docker exec wordpress ls -l /run/secrets/
```

`mariadb` receives `db_root_password` and `db_password`. `wordpress` receives
`db_password`, `wp_adm_password`, and `wp_user_password`. `nginx` receives
none — it holds no credential of any kind.

### Changing a password

Editing a file under `secrets/` and restarting is **not** sufficient. The
values were consumed once, at first run, and now live in the database.

**A WordPress user's password** — change it in the admin panel under Users,
or from the command line:

```bash
docker exec wordpress wp user update afontele \
  --user_pass='NEW_PASSWORD' --path=/var/www/html --allow-root
```

Then update `secrets/wp_adm_password.txt` so the file and reality agree.

**The database password** is stored in three places: the MariaDB grant
tables, `wp-config.php` inside the WordPress volume, and
`secrets/db_password.txt`. Changing one alone breaks the site. The reliable
way to change it is `make fclean && make`, which rebuilds everything from the
current secret files — at the cost of destroying the site's content.

## Checking that the services are running

### Container state

```bash
make ps
```

All three must show `Up`. `Restarting` means a container is crash-looping —
check its logs.

### The right process is PID 1

```bash
docker exec mariadb ps -o pid,cmd -p 1
docker exec wordpress ps -o pid,cmd -p 1
docker exec nginx ps -o pid,cmd -p 1
```

Expect `mysqld`, `php-fpm: master process`, and `nginx -g daemon off;`
respectively. If PID 1 were a shell or a `tail`, the container would not be
tied to the service it is supposed to run.

### The site answers over TLS, and only over TLS

```bash
curl -kI https://afontele.42.fr        # expect HTTP/1.1 200 OK
curl -I  http://afontele.42.fr         # expect a connection failure
```

`-k` accepts the self-signed certificate; `-I` requests headers only.

Protocol versions:

```bash
openssl s_client -connect afontele.42.fr:443 -tls1_2 </dev/null
openssl s_client -connect afontele.42.fr:443 -tls1_3 </dev/null
openssl s_client -connect afontele.42.fr:443 -tls1   </dev/null
```

The first two complete a handshake and print the certificate. The third fails.

### The database is reachable and not empty

```bash
docker exec -it mariadb mariadb -u wpuser -p wordpress
```

Enter the contents of `secrets/db_password.txt` at the prompt. Then:

```sql
SHOW TABLES;
SELECT user_login, user_email FROM wp_users;
```

`SHOW TABLES` lists the WordPress tables — `wp_posts`, `wp_users`, and the
rest. The second query returns two rows, `afontele` and `amanda`. `exit` to
leave.

### Volumes and network exist

```bash
docker volume ls
docker volume inspect inception_mariadb_vol
docker volume inspect inception_wordpress_vol
docker network ls
```

Each `inspect` must show a device path under `/home/afontele/data/`, which is
what the subject requires.

### Logs

```bash
make logs                      # everything
docker logs nginx              # one container
docker logs -f wordpress       # follow
```
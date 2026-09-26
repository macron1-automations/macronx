# Docker

MacronX runs as a set of containers with Docker Compose: the Rails app, the
background job worker, the Tailwind watcher, and PostgreSQL.

This runs the app in **development mode** inside the container: code reloading,
Rails error pages, and the Tailwind watcher all work, and the working tree is
bind-mounted so edits on the host apply immediately without a rebuild.

For production deployment see [Kamal](#production) at the bottom.

## Quick start

```sh
docker compose up -d --build
docker compose logs -f web
```

The app is then on <http://localhost:3000>. The first boot creates the
databases, loads the schema, and runs the seeds, printing the admin login in
the web logs.

To pick your own login before the first boot, set these in `.env`:

```sh
POSTGRES_PASSWORD=choose-a-database-password
SEED_ADMIN_EMAIL=you@example.com
SEED_ADMIN_PASSWORD=choose-a-login-password
```

## Services

| Service | Runs | Notes |
| --- | --- | --- |
| `db` | `postgres:18` | Data in the `pg_data` volume. Not published to the host. |
| `web` | `bin/rails server` | Serves the app on port 3000 and runs `db:prepare` on boot. |
| `jobs` | `bin/jobs` | Solid Queue worker. Runs the recurring jobs in `config/recurring.yml`, including the daily feed digest. |
| `css` | `bin/rails tailwindcss:watch[always]` | Rebuilds `app/assets/builds/tailwind.css` when stylesheets change. The `always` argument puts Tailwind in polling mode, which is what keeps the watcher alive on a bind-mounted filesystem. |

All three Ruby services share the same image (`Dockerfile.dev`) and the same
bind mount, so a code change applies to all of them. Only `web` touches the
database on boot; `jobs` waits for the web health check so the two never race to
create the same database.

The image carries the tools the jobs shell out to: `ffmpeg` for audio, and
ImageMagick with libheif for `Image::ConvertHeicToJpegJob`, which mini_magick
needs for its `convert` binary.

## Persistence

Everything that matters survives restarts, `docker compose down`, container
recreates, and image rebuilds:

- **Database** — the named volume `macronx_pg_data`.
- **Uploaded files** — `storage/` in the working tree, shared through the bind
  mount. This is the same `config.active_storage.service = :local` path used
  outside Docker, and it is already in `.gitignore`.
- **Login sessions** — `tmp/local_secret.txt`, generated on boot in the bind
  mounted `tmp/`.

The volume is only destroyed by an explicit request:

```sh
docker compose down        # keeps the data
docker compose down -v     # deletes the database
```

### Why the volume is mounted at `/var/lib/postgresql`

Postgres 18 sets `PGDATA` to `/var/lib/postgresql/18/docker`, and the image
declares `/var/lib/postgresql` as its volume. Mounting the older
`/var/lib/postgresql/data` path leaves the real data directory in the
container's writable layer instead of the volume, so the database appears to
reset every time the container is recreated. If you port this setup to a
Postgres 17 or older image, mount `/var/lib/postgresql/data` instead.

### Backup and restore

`--no-owner` matters: the dump is restored by a different role than the one
that owns the local database, and ownership statements would otherwise fail.

```sh
docker compose exec db pg_dump -U postgres --no-owner macron_x_development > backup.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U postgres -d macron_x_development < backup.sql
```

The queue database (`macron_x_development_queue`) holds pending and recurring
jobs, and `db/queue_schema.rb` recreates it from scratch if needed, so a single
dump of the main database is normally enough.

## Configuration

### Database connection

`config/database.yml` reads the standard libpq variables:

| Variable | In Docker | On the host |
| --- | --- | --- |
| `PGHOST` | `db` | unset, so the local unix socket is used |
| `PGUSER` | `postgres` | unset, so the current OS user is used |
| `PGPASSWORD` | `POSTGRES_PASSWORD` from `.env` | unset |

All three are unset by default, so running `bin/dev` on the host keeps using
your local PostgreSQL exactly as before. The same settings apply to the
`macron_x_development_queue` database, and the test database keeps its own
`macron_x_test` name, so the specs never touch your development data.

### LLM and transcription services

`dotenv-rails` loads `.env` from the working tree, so the variables documented
in [SETUP.md](SETUP.md) are picked up unchanged. Services on the host are
reachable at `host.docker.internal`, which `compose.yaml` maps for you. If
`.env` points Ollama or Whisper at `localhost`, change it:

```sh
OLLAMA_API_BASE=http://host.docker.internal:11434/v1
WHISPER_API_BASE=http://host.docker.internal:9000
```

### Accessing from other devices

Rails allows any IP address in development, so `http://<your-lan-ip>:3000`
works without extra configuration. For a hostname such as an ngrok domain, set
it in `.env`:

```sh
RAILS_DEVELOPMENT_HOSTS=your-domain.ngrok-free.app
```

## Everyday commands

```sh
docker compose logs -f web         # follow the app logs
docker compose restart web         # restart after an environment change
docker compose up -d --build       # rebuild after a Gemfile change
docker compose run --rm web bash   # shell in the container
```

Rails console and database console:

```sh
docker compose exec web bin/rails console
docker compose exec db psql -U postgres -d macron_x_development
```

Run the test suite against the containerized database:

```sh
docker compose exec web bundle exec rspec
```

There is no `bin/rspec` in this repository, and `RAILS_ENV` is intentionally not
set in the image: the suite sets it to `test` itself, so the specs run against
`macron_x_test` and never touch your development data. Passing `-e development`
to `bundle exec rspec` would run them against `macron_x_development` and wipe it.

## Importing existing local data

To start from the database you already have on the host rather than a fresh
one, dump it and restore it into the container. Stop the app first so nothing
writes while the import runs.

```sh
# On the host
pg_dump --no-owner --no-privileges -d macron_x_development > backup.sql
pg_dump --no-owner --no-privileges -d macron_x_development_queue > queue-backup.sql

# Into the container
docker compose up -d db
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U postgres -d macron_x_development < backup.sql
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U postgres -d macron_x_development_queue < queue-backup.sql
docker compose up -d
```

Uploaded files need no import: `storage/` is the same directory on the host and
in the container.

## Notes

- **File watching works on Linux hosts only.** Rails reloads on bind-mounted
  file changes through inotify, which does not cross the file-sharing layer used
  by Docker Desktop on macOS and Windows. On those platforms restart the affected
  container after editing code, or use the native `bin/dev` setup instead.
- **Port 3000 must be free.** Change the left-hand side of the `3000:3000`
  mapping in `compose.yaml` if something else on the host already uses it.
- **Port 5432 is not published**, because a local PostgreSQL server usually
  already holds it.
- **Gems live outside the bind mount** at `/usr/local/bundle`, so editing the
  working tree cannot break the bundle. Do not add a volume mount over that path.
- **`tmp/cache`** is shared with the host. If the host has a bootsnap cache from
  a different gem path, delete `tmp/cache` to force a rebuild.

## Production

The default `Dockerfile` and `config/deploy.yml` target production and are
unchanged by any of this. Production runs in `RAILS_ENV=production`, which needs
`SECRET_KEY_BASE` and precompiled assets, and expects an external PostgreSQL
server rather than the `db` service here. Use Kamal for that:

```sh
bin/kamal setup
bin/kamal deploy
```

One gap worth knowing about: the production image installs `libvips` but not
ImageMagick, so `Image::ConvertHeicToJpegJob` cannot shell out to `convert`
there the way it does here. Add `imagemagick libheif-examples` to the package
list in `Dockerfile` if IMINT runs in production.

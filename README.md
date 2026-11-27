# Certfy

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Identidade visual

The interface and account e-mails read their identity from `Certfy.Branding`.
The defaults below keep the original Certfy identity; every customization must
be set explicitly through the environment:

| Variable | Default | Purpose |
| --- | --- | --- |
| `BRAND_NAME` | `Certfy` | Product name in titles, navigation, copy and e-mails |
| `BRAND_THEME` | `certfy` | Palette key applied as `data-brand` (`certfy` for the default green, `certifique` for the alternative orange/navy palette) |
| `BRAND_MARK` | `certfy` | Mark asset: `certfy` (inline SVG) or `seal` (image assets `brand-mark.png` and `favicon.png`) |
| `BRAND_FROM_EMAIL` | `no-reply@certfy.local` | Sender address for account e-mails |

Both palettes and both marks ship in the same image, so one build serves every
deployment; only the variables change. Certificate e-mails keep using
`CERTIFICATE_FROM_NAME` and `CERTIFICATE_FROM_EMAIL`.

A deployment that wants the alternative identity sets, for example:

```
BRAND_NAME=Certifique
BRAND_THEME=certifique
BRAND_MARK=seal
BRAND_FROM_EMAIL=no-reply@certifique.local
CERTIFICATE_FROM_NAME=Certifique
CERTIFICATE_FROM_EMAIL=no-reply@certifique.local
```

## Access model

- There is no public sign-up. Admins invite people from the **Usuários** page (`/users`).
- Login is passwordless: enter your email at `/users/log-in` and open the link sent to your inbox.
- The first admin is created by `mix run priv/repo/seeds.exs` (email from `CERTFY_ADMIN_EMAIL`, default `admin@certfy.local`).
- In development, sent emails are available at `/dev/mailbox`.
- Admins can deactivate/reactivate users and change roles between `USER` and `ADMIN`.

## Object storage and certificates

Certificate PDFs are stored in RustFS, an S3-compatible service. Each event has a
`.pptx` template (up to 20 MB) uploaded on its template page; tags like
`{{participante.nome}}` are replaced in Elixir and the presentation is converted
to PDF by Gotenberg/LibreOffice.

Start the local services with:

```bash
docker compose up -d
```

The services include PostgreSQL, RustFS and Gotenberg (LibreOffice). The app
uses `GOTENBERG_URL` (default `http://localhost:3000`) to convert templates.
The template page also exposes a static preview, a preview with participant
data and a catalog of available tags/values.

RustFS defaults match `docker-compose.yml`: `http://localhost:9000`,
`rustfsadmin`/`rustfsadmin`, bucket `certfy-templates`. They can be overridden
with `RUSTFS_SCHEME`, `RUSTFS_HOST`, `RUSTFS_PORT`, `RUSTFS_REGION`,
`RUSTFS_ACCESS_KEY`, `RUSTFS_SECRET_KEY` and `RUSTFS_BUCKET`.

## Participant import

Participants can be imported from CSV or XLSX at `/participants/import` (also
reachable from the batch page). Files are limited to 5 MB. Name and e-mail
columns are detected automatically, the mapping can be adjusted in the preview,
and the remaining columns become `extra_data` keys.

Every valid row is imported without deduplication. Name is required (up to 160
characters); an invalid e-mail is cleared instead of rejecting the row.

## Certificate e-mail

Certificate delivery needs an SMTP server. Configure it with `SMTP_HOST`,
`SMTP_PORT` (default `587`), `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_TLS`
(`always`, `if_available` or `never`), `CERTIFICATE_FROM_EMAIL` and
`CERTIFICATE_FROM_NAME`. Without `SMTP_HOST` the mailer keeps the local adapter
from `config/config.exs`.

## Background jobs

Certificate generation and e-mail delivery run through Oban. The queues are
started with the application; in development the Oban dashboard is available at
`/dev/dashboard`.

Certificates can be validated publicly at `/validar` (or `/validar/:code`).
The QR code contains only the 10-character certificate code.

Ready to run in production? Please [check our deployment guides](https://phoenix.hexdocs.pm/deployment.html).

## Production deploy (Dokploy)

The production stack lives in `docker-compose.prod.yml` and **pulls** the image
`CERTFY_IMAGE` (default `docker.io/carloscardoso05/certfy:latest`); it never
builds on the server. The image comes from `Dockerfile` (Elixir release on
Debian slim, running as a non-root user). Copy `.env.example` to `.env` for the
local variables or fill the same names in the Dokploy **Environment** tab.

Services:

- `app` — Phoenix release on port `4000`, internal only; Dokploy injects the
  Traefik router/labels when you add a domain to this service.
- `migrate` — one-shot `Certfy.Release.migrate()`; `app` only starts after it
  succeeds.
- `postgres`, `rustfs`, `gotenberg` — internal services with named volumes.
- `/health` is a public, database-free liveness endpoint used by the container
  healthcheck (and excluded from `force_ssl` redirects).

### Required environment variables

| Variable | Notes |
|---|---|
| `CERTFY_IMAGE` | Optional image reference; defaults to `docker.io/carloscardoso05/certfy:latest` |
| `APP_HOST` | Public hostname used by Phoenix (`PHX_HOST`) |
| `SECRET_KEY_BASE` | Generate with `mix phx.gen.secret` |
| `POSTGRES_PASSWORD` | Password for the internal database |
| `RUSTFS_ACCESS_KEY` | Object storage access key |
| `RUSTFS_SECRET_KEY` | Object storage secret key |

Optional: `POSTGRES_USER`, `POSTGRES_DB`, `POOL_SIZE`, `RUSTFS_BUCKET`,
`RUSTFS_REGION`, `CERTIFICATE_FROM_EMAIL`, `CERTIFICATE_FROM_NAME`,
`CERTFY_ADMIN_EMAIL`, `SMTP_*` (see `config/runtime.exs`) and the branding
variables described in **Identidade visual**.

`POSTGRES_PASSWORD` is interpolated into `DATABASE_URL`, so use a URL-safe
password (letters, digits and `-_.~`) or set `DATABASE_URL` explicitly.

### Building and publishing the image

Build on a machine with the same architecture as the server (the current
deployment targets `linux/amd64`) and push to a public registry. The current
image is published on Docker Hub:

```bash
docker login docker.io -u carloscardoso05
docker build -t docker.io/carloscardoso05/certfy:0.1.0-<sha> .
docker push docker.io/carloscardoso05/certfy:0.1.0-<sha>
docker tag docker.io/carloscardoso05/certfy:0.1.0-<sha> docker.io/carloscardoso05/certfy:latest
docker push docker.io/carloscardoso05/certfy:latest
```

Docker Hub repositories are public by default. GHCR (`ghcr.io/<owner>/certfy`)
also works, but the package must be published with a token that has
`write:packages` and its visibility changed to public once.

Keep one image per release and use the branding variables to change the
identity; never build one image per branch.

### Steps in Dokploy

1. Create a **Compose** application pointing to this repository and to
   `docker-compose.prod.yml`.
2. Fill the environment variables above in the Dokploy **Environment** tab
   (set `CERTFY_IMAGE` only to pin a specific tag instead of `latest`).
3. Add a domain to the `app` service (container port `4000`). Dokploy/Traefik
   handles TLS and the network; no labels, `ports:` or `networks:` are needed in
   the compose file.
4. Deploy. The image is pulled, the `migrate` service runs first and the app
   starts afterwards.

Dokploy manages the network and project naming, so two deployments can share
the same server without changes to this file.

To build and run the same compose locally:

```bash
CERTFY_IMAGE=certfy:local docker compose \
  -f docker-compose.prod.yml -f docker-compose.build.yml up --build
```

### First admin

After the first deploy, create the admin user once:

```bash
docker compose -f docker-compose.prod.yml run --rm app \
  bin/certfy eval "Certfy.Release.seed()"
```

Set `CERTFY_ADMIN_EMAIL` before running it (defaults to `admin@certfy.local`).

### Backups

`postgres_data` and `rustfs_data` are named volumes. Back them up with
`pg_dump` and by copying/exporting the object storage bucket. Note that
PostgreSQL 19 stores data in `/var/lib/postgresql/19/docker`, which is why the
volume is mounted at `/var/lib/postgresql`.

### Local smoke test of the production image

```bash
docker build -t certfy:local .
docker run --rm -p 4000:4000 --env-file .env.prod certfy:local
```
## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

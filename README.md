# Certifique

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Identidade visual

The interface and account e-mails read their identity from `Certfy.Branding`.
Each deployment can override the defaults at runtime:

| Variable | Default | Purpose |
| --- | --- | --- |
| `BRAND_NAME` | `Certifique` | Product name in titles, navigation, copy and e-mails |
| `BRAND_THEME` | `certifique` | Palette key applied as `data-brand` (`certifique` or `certfy`) |
| `BRAND_MARK` | `fadesp` | Mark asset: `fadesp` (institutional seal, circle only) or `certfy` (original C) |
| `BRAND_FROM_EMAIL` | `no-reply@certifique.local` | Sender address for account e-mails |

The `certifique` palette is inspired by FADESP (orange `#DD6B3B`, navy
`#00264C`, blue `#0C4DA2`). The primary orange is darkened to `#B84E22` for
AA-contrast text and buttons, while the mark keeps the original `#DD6B3B`.
Set `BRAND_THEME=certfy` to render the original green identity. Certificate
e-mails keep using `CERTIFICATE_FROM_NAME` and `CERTIFICATE_FROM_EMAIL`.

The `fadesp` mark uses the institutional seal (circle only), shared by the
sidebar, login, public validation page and favicon. `BRAND_MARK=certfy` uses
the original green C mark instead.

## Access model

- There is no public sign-up. Admins invite people from the **Usuários** page (`/users`).
- Login is passwordless: enter your email at `/users/log-in` and open the link sent to your inbox.
- The first admin is created by `mix run priv/repo/seeds.exs` (email from `CERTIFIQUE_ADMIN_EMAIL`; `CERTFY_ADMIN_EMAIL` is still accepted, default `admin@certifique.local`).
- In development, sent emails are available at `/dev/mailbox`.
- Admins can deactivate/reactivate users and change roles between `USER` and `ADMIN`.

## Active Directory (planned)

Authentication stays on magic links and admin invitations for now. The
migration to LDAP/Active Directory is documented but not implemented; see
[`docs/ldap-migration.md`](docs/ldap-migration.md) for the architecture, the
configuration matrix, the database migration and the rollout checklist. That
plan is pinned to commit `9ea75d0d66fa86e07d3c0d527b35f59a35ce3f62`.


## Object storage and certificates

Certificate PDFs are stored in RustFS, an S3-compatible service. Each event has a
`.pptx` template (up to 20 MB) uploaded on its template page; tags like
`{{participant.name}}` are replaced in Elixir and the presentation is converted
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

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

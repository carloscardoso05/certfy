# Certfy

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Access model

- There is no public sign-up. Admins invite people from the **Usuários** page (`/users`).
- Login is passwordless: enter your email at `/users/log-in` and open the link sent to your inbox.
- The first admin is created by `mix run priv/repo/seeds.exs` (email from `CERTFY_ADMIN_EMAIL`, default `admin@certfy.local`).
- In development, sent emails are available at `/dev/mailbox`.
- Admins can deactivate/reactivate users and change roles between `USER` and `ADMIN`.

## Object storage (RustFS)

Event templates are stored in RustFS, an S3-compatible service. Start the local
services with:

```bash
docker compose up -d
```

The defaults match `docker-compose.yml`: `http://localhost:9000`,
`rustfsadmin`/`rustfsadmin`, bucket `certfy-templates` (created on the first
upload). They can be overridden with `RUSTFS_SCHEME`, `RUSTFS_HOST`,
`RUSTFS_PORT`, `RUSTFS_REGION`, `RUSTFS_ACCESS_KEY`, `RUSTFS_SECRET_KEY` and
`RUSTFS_BUCKET`.

Ready to run in production? Please [check our deployment guides](https://phoenix.hexdocs.pm/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

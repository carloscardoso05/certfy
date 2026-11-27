# LDAP / Active Directory migration plan

> **Status:** planned, not implemented. Authentication currently uses magic
> links and admin invitations.
>
> **Baseline commit:** `9ea75d0d66fa86e07d3c0d527b35f59a35ce3f62`
> (`chore: remove handoff`, 2026-11-27T10:12:49-03:00).
>
> Branch from this commit when implementing. If `main` has moved, run
> `git diff 9ea75d0d66fa86e07d3c0d527b35f59a35ce3f62..HEAD -- lib/certfy_web/user_auth.ex lib/certfy/accounts lib/certfy_web/router.ex lib/certfy_web/live/user_live`
> first and adjust the steps below.

## 1. Why this document

The deployment at FADESP should reuse the Windows/Active Directory credentials
instead of sending magic links. This document records the agreed design, the
decisions taken with the product owner, and a file-by-file checklist so the
migration can be implemented later without redoing the analysis.

The goal is to keep a **single codebase**. Branding is already parameterised
through `Certfy.Branding`; authentication will follow the same pattern with a
provider list, so the existing magic-link flow stays available and unchanged
for the main deployment and for future external users.

## 2. Current authentication at the baseline

- No public sign-up. Admins invite people from `/users` (`Certfy.Accounts.Admin`).
- Login is passwordless: `/users/log-in` sends a magic link; the link lands on
  `/users/log-in/:token` and `UserSessionController.create/2` exchanges it for a
  session token.
- `users` has no password column (removed by
  `priv/repo/migrations/20261126213718_remove_password_from_users.exs`).
- Sessions use `users_tokens` (`context = "session"`), with a signed
  remember-me cookie valid for 14 days (`CertfyWeb.UserAuth`).
- `current_scope` is assigned by `:fetch_current_scope_for_user` for
  controllers and by the `UserAuth` `on_mount` hooks for LiveViews.
- Roles are `:USER` and `:ADMIN`; `deactivated_at` blocks access. Admins see
  every record through `Certfy.Accounts.Scope.owned/2`, while regular users
  only see their own.
- Account e-mails are sent by `Certfy.Accounts.UserNotifier`; certificate
  e-mails by `Certfy.Certificates.Notifier`.

## 3. Goals and non-goals

**Goals**

- Authenticate staff with their AD username and password; the app never stores
  AD passwords.
- Provision a local user record on the first successful login.
- Keep magic-link login available as a provider (needed later for external
  users and useful for rollback).
- Allow an emergency local admin when AD is unavailable.
- Switch profiles through environment variables, not a code fork.

**Non-goals (this migration)**

- Open self-registration for external users.
- Event sharing/permissions between accounts (records are already scoped;
  admins see everything).
- Periodic AD revalidation of existing sessions.
- Replacing magic links for external users.

## 4. Target architecture

```
Certfy.Auth                      facade used by the web layer
├── Certfy.Auth.Directory        behaviour + %Identity{}
├── Certfy.Auth.LDAP             :eldap implementation
├── Certfy.Auth.BreakGlass       emergency account from env
└── Certfy.Auth.Throttle         in-memory attempt limiter (ETS)

Certfy.Accounts                  owns users, sessions, roles
CertfyWeb.UserLive.Login         renders the form for enabled providers
CertfyWeb.UserAuth               unchanged: session creation/validation
```

`Certfy.Auth` exposes `providers/0`, `enabled?/1` and
`authenticate(provider, credentials)`. The login LiveView branches on
`providers/0`; the router keeps both route sets but guards the magic-link ones
with a plug that returns 404 when the provider is disabled.

Use the Erlang `:eldap` module (OTP application `eldap`, already installed with
Erlang/OTP). No new Hex dependency is required. Add `:eldap` to
`extra_applications` in `mix.exs`.

### 4.1 Directory behaviour

```elixir
defmodule Certfy.Auth.Directory do
  @type identity :: %Certfy.Auth.Identity{
          username: String.t(),
          email: String.t(),
          name: String.t(),
          dn: String.t(),
          guid: String.t() | nil,
          groups: [String.t()]
        }

  @callback authenticate(username :: String.t(), password :: String.t()) ::
              {:ok, identity()} | {:error, :invalid_credentials | :not_found |
                                    :disabled | :forbidden | :unavailable}
end
```

The concrete module is selected by `config :certfy, :directory,
Certfy.Auth.LDAP` (tests replace it with a stub).

### 4.2 Login flow (LDAP)

1. Read `username` and `password` from the form (password never logged).
2. `Certfy.Auth.Throttle.hit(username, ip)`; reject with the generic message
   after N failures in the window.
3. Open the connection:
   - `LDAPS`: `:eldap.open([host], port: 636, ssl: true, sslopts: tls_opts())`
   - `StartTLS` (default): `:eldap.open([host], port: 389, timeout: t)`,
     then `:eldap.start_tls(handle, tls_opts(), t)`.
   - Plaintext is rejected by default (`LDAP_ENCRYPTION=none` must be explicit).
4. Bind with the service account (`LDAP_BIND_DN` / `LDAP_BIND_PASSWORD`).
5. Search under `LDAP_BASE_DN` (subtree) for the user:

```elixir
:eldap.search(handle, [
  base: String.to_charlist(base_dn),
  scope: :eldap.wholeSubtree(),
  filter:
    :eldap.and([
      :eldap.equalityMatch(~c"objectCategory", ~c"person"),
      :eldap.or([
        :eldap.equalityMatch(~c"sAMAccountName", username),
        :eldap.equalityMatch(~c"userPrincipalName", username)
      ]),
      :eldap.not(
        :eldap.extensibleMatch(~c"2",
          type: ~c"userAccountControl",
          matchingRule: ~c"1.2.840.113556.1.4.803"
        )
      )
    ]),
  attributes: [~c"sAMAccountName", ~c"userPrincipalName", ~c"mail", ~c"displayName",
               ~c"memberOf", ~c"objectGUID"]
])
```

   `:eldap.search/2` returns `{:ok, {:eldap_search_result, entries, referrals,
   controls}}`; read entries with `Record.extract/2` from `eldap.hrl`.
   The example matches `sAMAccountName`; use `LDAP_UID_ATTRIBUTE` when it is
   configured differently. If there is no entry, fail with the generic error.
6. If `LDAP_REQUIRED_GROUP_DN` is set, verify membership. For nested AD groups,
   search with base = user DN and the in-chain matching rule:

```elixir
:eldap.search(handle, [
  base: user_dn,
  scope: :eldap.baseObject(),
  filter:
    :eldap.extensibleMatch(String.to_charlist(group_dn),
      type: ~c"memberOf",
      matchingRule: ~c"1.2.840.113556.1.4.1941"
    ),
  attributes: [~c"distinguishedName"]
])
```

7. Bind again with the **user DN** and the submitted password. A successful
   bind proves the credentials; this is the only password validation step.
8. Close the connection and return an `%Identity{}`.
9. `Certfy.Accounts.upsert_ldap_user/1`:
   - match by `ldap_guid`, then `ldap_dn`, then `lower(username)`, then `email`;
   - insert with `auth_provider: :ldap`, `confirmed_at: now`;
   - update `name`, `email`, `username`, `ldap_dn`, `ldap_guid`.

   If the e-mail already belongs to a `:magic_link` user, do not create a
   second record: link the AD fields to that user and switch `auth_provider` to
   `:ldap` only after an explicit admin decision (log a warning and surface it
   in the users page).
10. Role: when `LDAP_ADMIN_USERS` is non-empty it is authoritative for LDAP
    users — listed logins become `:ADMIN`, the others `:USER`. When the list is
    empty, keep the role stored in the database. Never touch the role of
    `:magic_link` or `:break_glass` users during an LDAP login.
11. Refuse deactivated users (`deactivated_at`).
12. `UserAuth.log_in_user(conn, user, params)` — session, remember-me and
    redirect behaviour stay exactly as they are.

### 4.3 Break-glass access

- Enabled only when both `AUTH_BREAK_GLASS_USER` and
  `AUTH_BREAK_GLASS_PASSWORD` are set.
- Compare with `Plug.Crypto.secure_compare/2`; no password in logs.
- On success, upsert a user with `auth_provider: :break_glass`, role `:ADMIN`,
  `confirmed_at`, and log in through the normal session flow.
- Log a warning at boot when enabled in production.
- Rotating the password requires only an application restart (the account is
  not stored in the database beyond its user row).

### 4.4 Throttling

`Certfy.Auth.Throttle` uses an ETS table owned by a small GenServer started in
`Certfy.Application`. Key: `{username, remote_ip}`. Default: 5 failures per 10
minutes; configurable with `AUTH_LOGIN_THROTTLE_ATTEMPTS` and
`AUTH_LOGIN_THROTTLE_WINDOW_SECONDS`. This protects both the emergency account
and AD from accidental lockouts.

## 5. Data model

### 5.1 Migration

Generate with `mix ecto.gen.migration add_auth_provider_to_users`, then:

```elixir
alter table(:users) do
  add :auth_provider, :string, null: false, default: "magic_link"
  add :username, :string
  add :ldap_dn, :string
  add :ldap_guid, :string
end

create constraint(:users, :auth_provider_allowed,
         check: "auth_provider IN ('magic_link', 'ldap', 'break_glass')")

execute """
CREATE UNIQUE INDEX users_username_lower_index
ON users (lower(username))
WHERE username IS NOT NULL
"""

execute """
CREATE UNIQUE INDEX users_ldap_guid_index
ON users (ldap_guid)
WHERE ldap_guid IS NOT NULL
"""
```

Existing rows become `magic_link`, which matches their current behaviour.

### 5.2 Schema changes

- `auth_provider`, `Ecto.Enum, values: [:magic_link, :ldap, :break_glass]`.
- `username`, `ldap_dn`, `ldap_guid` as `:string`.
- New changeset `ldap_changeset/2` (internal; never cast from user input).
- `User.auth_provider/0` helper for templates instead of boolean flags.

## 6. Configuration

Runtime variables (read in `config/runtime.exs`, never committed):

| Variable | Default | Notes |
| --- | --- | --- |
| `AUTH_PROVIDERS` | `magic_link` | Comma-separated: `ldap`, `magic_link`, or both |
| `LDAP_HOST` | — | Domain controller host name |
| `LDAP_PORT` | `389` | Use `636` with `ldaps` |
| `LDAP_ENCRYPTION` | `start_tls` | `start_tls`, `ldaps` or `none` |
| `LDAP_BASE_DN` | — | e.g. `DC=fadesp,DC=local` |
| `LDAP_BIND_DN` | — | Read-only service account DN |
| `LDAP_BIND_PASSWORD` | — | Service account password |
| `LDAP_UID_ATTRIBUTE` | `sAMAccountName` | Match this before falling back to UPN |
| `LDAP_MAIL_ATTRIBUTE` | `mail` | Fallback: `userPrincipalName` |
| `LDAP_NAME_ATTRIBUTE` | `displayName` | Fallback: `cn` |
| `LDAP_REQUIRED_GROUP_DN` | — | Optional; restricts access to a group |
| `LDAP_ADMIN_USERS` | — | Comma-separated logins; authoritative for LDAP users |
| `LDAP_CA_CERT_FILE` | — | PEM file for a private CA; otherwise OS trust store |
| `LDAP_TIMEOUT_MS` | `5000` | Connection and search timeout |
| `AUTH_BREAK_GLASS_USER` | — | Emergency account; disabled when empty |
| `AUTH_BREAK_GLASS_PASSWORD` | — | Emergency password |
| `AUTH_LOGIN_THROTTLE_ATTEMPTS` | `5` | Failures before blocking |
| `AUTH_LOGIN_THROTTLE_WINDOW_SECONDS` | `600` | Throttle window |

TLS options:

```elixir
[
  verify: :verify_peer,
  cacerts: :public_key.cacerts_get(),
  cacertfile: System.get_env("LDAP_CA_CERT_FILE"),
  server_name_indication: String.to_charlist(host),
  customize_hostname_check: [
    match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
  ]
]
```

Omit `cacertfile` when empty.

## 7. Web UI and routes

- `/users/log-in` renders one section per enabled provider. With both enabled,
  show “Equipe — usuário e senha da rede” and “Externo — receber link por
  e-mail”. Never guess the provider from a single field.
- Magic-link routes (`/users/log-in/:token`, `/users/register/:token`) stay in
  the router but are wrapped by a plug that returns 404 when `magic_link` is
  disabled.
- `/users` hides the invitation form when `magic_link` is disabled; role and
  activation controls remain.
- `/users/settings` shows name and e-mail as read-only for `:ldap` and
  `:break_glass` accounts, with a note that AD manages them. Magic-link users
  keep the current forms.
- Login errors are always “Usuário ou senha inválidos.” — never reveal whether
  the account exists, is disabled or belongs to a group.
- Keep `UserAuth.log_in_user/3` untouched so redirect, remember-me and session
  rotation behave the same for every provider.

## 8. Security requirements

- Passwords are only used for the bind and discarded; never logged, stored or
  sent to telemetry.
- TLS with peer verification is the default; `none` must be an explicit,
  documented exception.
- The service account should be read-only and scoped to the base DN.
- Throttle before calling AD to avoid account lockouts.
- A disabled AD account is refused on the next login, but an existing session
  remains valid for up to 14 days. Reduce `@max_cookie_age_in_days` or add a
  revalidation job if that becomes a requirement.
- The emergency account must be rotated after use and should be disabled in
  environments where AD availability is guaranteed.

## 9. Testing

- Unit tests with a stub directory (`config :certfy, :directory, ...` in
  `config/test.exs`) covering: success, invalid password, unknown user,
  disabled AD user, group restriction, admin allowlist, role preservation for
  magic-link users, deactivated local user, unavailable AD.
- LiveView tests for the login page with each provider combination and for the
  404 guard on disabled magic-link routes.
- Settings tests for read-only AD accounts.
- A `mix certfy.ldap.check --username <login>` task that opens the connection,
  binds the service account and prints the found DN/attributes. It must not
  ask for or print a user password.
- Manual acceptance on the corporate network: one regular account, one admin
  account, one account outside `LDAP_REQUIRED_GROUP_DN`, one wrong password,
  and one login with AD unreachable (break-glass only).

## 10. Rollout

1. Deploy the migration with `AUTH_PROVIDERS=magic_link`; behaviour is
   unchanged and the new columns stay empty.
2. Configure the LDAP variables and validate connectivity with
   `mix certfy.ldap.check`.
3. Set `AUTH_PROVIDERS=ldap` and keep a break-glass account configured.
4. Pilot with two or three staff accounts; confirm name/e-mail/role sync.
5. Announce the change and keep magic links disabled. Re-enable only if a
   rollback is needed.

**Rollback:** set `AUTH_PROVIDERS=magic_link` and restart. No data migration is
needed; LDAP columns remain populated but unused.

## 11. Future: external users without AD

- Enable `AUTH_PROVIDERS=ldap,magic_link` and configure SMTP.
- Keep invitations (`/users/register/:token`) as the only way in; no open
  sign-up.
- External users are created with `auth_provider: :magic_link` and role
  `:USER`. They can manage their own events; admins already see every record.
- Do not add an “external” boolean yet. If sharing/permissions become a
  requirement, model it explicitly (event collaborators or an account kind),
  not through `auth_provider`.

## 12. Implementation checklist

1. `mix.exs`: add `:eldap` to `extra_applications`.
2. `config/config.exs`: defaults for `:auth` (providers, directory, ldap,
   break-glass, throttle).
3. `config/runtime.exs`: read and validate the variables above; warn on
   plaintext LDAP and on break-glass in production.
4. `lib/certfy/auth.ex`, `lib/certfy/auth/identity.ex`,
   `lib/certfy/auth/directory.ex`, `lib/certfy/auth/ldap.ex`,
   `lib/certfy/auth/break_glass.ex`, `lib/certfy/auth/throttle.ex`.
5. `lib/certfy/application.ex`: start the throttle.
6. Migration + `lib/certfy/accounts/user.ex` (`auth_provider`, new fields,
   `ldap_changeset/2`).
7. `lib/certfy/accounts.ex`: `get_user_by_username/1`, `upsert_ldap_user/1`,
   `ensure_break_glass_user/1`.
8. `lib/certfy_web/live/user_live/login.ex`: provider sections and submit
   handlers.
9. `lib/certfy_web/controllers/user_session_controller.ex`: LDAP submit path
   (or keep the form in the LiveView and reuse `UserAuth.log_in_user/3`).
10. `lib/certfy_web/router.ex`: provider guard plug for magic-link routes.
11. `lib/certfy_web/live/user_live/index.ex` and `settings.ex`: provider-aware
    UI.
12. `lib/certfy_web/live/user_live/confirmation.ex`: hide/guard when
    `magic_link` is disabled.
13. Tests and the `certfy.ldap.check` Mix task.
14. `README.md`: replace this section's link with operational instructions once
    implemented.

## 13. Open questions

- Does IT provide a read-only service account, or should the app bind with the
  user UPN directly? The latter prevents reading name/e-mail/groups and is not
  recommended.
- Is there an AD group for certificate administrators, or should
  `LDAP_ADMIN_USERS` remain the source of truth?
- Should sessions be revalidated against AD (nightly job or shorter
  remember-me)? Current decision: no, revisit after rollout.
- If externals need access to events created by staff, define the sharing model
  first; authentication alone does not solve it.

# 11 — `phx.gen.auth` Autopsy & Shipping a Release

## Goal

Close the loop on auth: run the official generator on a branch and systematically compare it with your doc-05 hand-rolled version — then ship the app as a self-contained OTP release with runtime configuration. After this doc you'll know exactly what the generator buys, what it assumes, and how an Elixir app actually deploys.

## Requirements

### R1 — Generate on a branch

1. New git branch `auth-generator-study`. Run `mix phx.gen.auth Accounts User users` — accept the conflict pain with your existing `Accounts`/`User` deliberately, or generate into a parallel context (`AuthStudy Account accounts`) if collision is unworkable; the first option teaches more, the second is acceptable. Note which you chose and why.
2. Phoenix 1.8 default: **magic links** (passwordless) with optional password. Generate with defaults; run its migrations; click through the full flow in the browser (register → magic link in dev mailbox → sudo mode → settings).

### R2 — Structured comparison

In `NOTES.md` (or `docs/auth-comparison.md` in the repo), a comparison with at minimum these axes — for each: what the generator did, what you did in doc 05, which is better and why:

1. **Token storage** — DB-backed `users_tokens` table vs your `Phoenix.Token`. Revocation, multiple sessions, "log out everywhere". Why does the generator hash tokens *in the DB*?
2. **Magic link flow** — token lifecycle, single-use enforcement, expiry tiers (different `validity` per token context — find the table).
3. **Session handling** — `renew_session`, disconnecting LiveView sockets on logout (`live_socket_id`) — did your doc-08 logout do that? Should it?
4. **Sudo mode** — `require_sudo_mode` plug: what it protects and how recency is checked.
5. **Scopes** — how 1.8 generators thread `current_scope` through routes, LiveViews, and context functions; line it up against your hand-built `Scope` from doc 05.
6. **Rate limiting / abuse** — what does the generator do about login attempts and enumeration? Compare with your doc-05 constant-time work and doc-10 limiter.
7. **Test helpers** — its `register_and_log_in_user`, fixtures, token helpers vs yours from doc 07.
8. **What you'd adopt** — pick at least two concrete improvements and port them into your hand-rolled auth on main (e.g., DB-backed revocable tokens, `live_socket_id` disconnect, sudo mode for account deletion). This is required, not optional: the autopsy must change your code.

### R3 — Port the improvements

1. Implement the ≥ 2 adopted improvements on main, with tests, hand-written (no copying generated files wholesale — re-derive them into your existing structure).
2. Delete or keep the study branch; if `phx.gen.auth` was generated into the real context and you stay with your hand-rolled version, ensure main is clean of leftovers.

### R4 — Release

1. Produce an OTP release: `mix phx.gen.release` (inspect what it adds: `Release` module, `migrate`/`rollback` scripts, optional Dockerfile — generate **with** `--docker` and read the Dockerfile even if you don't use Docker), then `MIX_ENV=prod mix release`.
2. Make prod config honest in `runtime.exs`: `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`, `PORT` from env vars; generate a real `SECRET_KEY_BASE` (`mix phx.gen.secret`). Understand `config/prod.exs` vs `runtime.exs` split — which is baked into the release, which is read at boot.
3. Run the release locally against a `task_hive_prod` database: `bin/task_hive eval "TaskHive.Release.migrate"`, then `bin/task_hive start`. The app must fully work: web UI, API with tokens, LiveView board (websocket through the release), digest worker ticking, `/api/health` reporting the release version.
4. No `mix` available inside a release — verify (try `bin/task_hive rpc` vs remembering `iex -S mix` doesn't exist there); learn `bin/task_hive remote` for a production shell, and use it once to inspect the supervision tree.
5. Asset pipeline for prod: `mix assets.deploy`, digested assets, `cache_static_manifest` — confirm CSS/JS load in the release.
6. NOTES.md: short deployment-options survey (Fly.io, render, bare VM with systemd, Docker) — one paragraph, pick what you *would* use; actual cloud deploy is optional stretch.
7. Pointer-level only (no implementation): read what `libcluster` does and what changes when two release nodes run (PubSub across nodes — revisit your doc-10 R3.5 answer about the rate limiter).

## Constraints

- The comparison must be done by reading the generated code, not blog summaries of it.
- Ported improvements: tests first or alongside — they meet the doc-07 bar (`ci.sh` green).
- The release must run with `MIX_ENV=prod` semantics for real: no `debug_errors`, forced SSL config at least reviewed (`force_ssl`/HSTS — research; enabling locally is awkward, understanding it is required).

## Concepts to research

- `mix phx.gen.auth` (1.8): magic links, `UserToken` design, hashed tokens, token contexts & validity periods
- Session fixation, `renew_session`, `live_socket_id` and LiveView socket disconnect on logout
- `require_sudo_mode`, re-authentication recency patterns
- Phoenix 1.8 scopes in generated code (`current_scope` end-to-end)
- `mix release`: release anatomy (`bin/`, ERTS inclusion, `vm.args`), `eval` vs `rpc` vs `remote`
- `mix phx.gen.release`, `Release` migrate module pattern, Dockerfile anatomy (multi-stage builds, build vs runtime image)
- `runtime.exs` vs `prod.exs`, `config_env()`, env var handling, `System.fetch_env!/1`
- `mix phx.gen.secret`, `secret_key_base` rotation implications
- `mix assets.deploy`, static manifest, asset digesting
- `force_ssl`, HSTS, `url` vs `http` endpoint config, `PHX_HOST` and websocket origin checks (`check_origin`)
- Hot code upgrades (know they exist and that nobody uses them for web apps — know why)
- `libcluster`, distributed Erlang, PubSub adapters across nodes

## Architecture notes

- The generator's `UserToken` schema (one table, a `context` column discriminating session/magic-link/email-change tokens, hashed at rest, per-context validity) is a production-grade design worth memorizing — it's the answer to "how do I do revocable, multi-device, multi-purpose tokens" in any stack.
- Generated code is the Phoenix team's opinion of best practice, refreshed each release — reading generator output on every major Phoenix upgrade is a legitimate, efficient way to keep your practices current. That's the meta-lesson of this doc.
- Releases are self-contained (ERTS included): the target machine needs no Elixir/Erlang. The trade: configuration must flow through env vars at boot (`runtime.exs`) because compile-time config is frozen at build. When something "works in dev but not in the release", stale compile-time config is suspect #1.
- Keep `Release` tasks (migrate/rollback/seed) in `lib/task_hive/release.ex` — they're core, not web, and they must not depend on Mix.

## Done when

- [ ] Comparison doc complete across all 8 axes
- [ ] ≥ 2 generator-inspired improvements live on main with tests; `ci.sh` green
- [ ] Release boots from `bin/`, migrates via `eval`, serves web+API+LiveView locally in prod mode with digested assets
- [ ] You've held a `remote` shell into the running release and inspected the tree
- [ ] You can answer: why DB-hashed tokens, why `runtime.exs` exists, why releases don't ship `mix`

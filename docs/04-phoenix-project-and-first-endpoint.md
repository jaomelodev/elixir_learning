# 04 — Phoenix Project & First Resource (REST API)

## Goal

The real app begins. A Phoenix 1.8 project `task_hive` with PostgreSQL, a guided tour of what `phx.new` generated, and a fully hand-written `/api/users` CRUD: migration, schema, changeset, context, controller, JSON rendering, tests. No generators for the resource — every file typed by you.

## Requirements

### R1 — Project creation & tour

1. Create with `mix phx.new task_hive` (defaults: HTML + assets stay in — the web UI comes in phase 2). Get `mix ecto.create` and `mix phx.server` working against local Postgres.
2. Written tour (a `NOTES.md` in the repo, bullet points are fine): trace one request end-to-end through the generated code. Identify and describe in one line each: `endpoint.ex`, `router.ex` (pipelines `:browser` and `:api`), a controller, `task_hive/application.ex` (recognize the supervision tree from doc 03 — name every child and guess its job), `repo.ex`, `config/*.exs` files and which runs when (compile-time vs runtime).
3. Find where `Plug` appears in the endpoint and router. Answer in NOTES.md: what is a plug, in one sentence, after reading the Plug hexdocs intro.

### R2 — Health endpoint (your first hand-made route)

1. `GET /api/health` → `200` `{"status":"ok","app":"task_hive","version":"<from mix.exs>"}`.
2. Hand-write: route in the `:api` pipeline scope, `HealthController`, JSON rendering. No Ecto involved.
3. A `ConnCase` test asserting status and body.

### R3 — Users: migration & schema (by hand)

1. Hand-write a migration (`mix ecto.gen.migration create_users` is allowed — it only creates an empty timestamped file; the contents are yours): table `users` with `name` (string, not null), `email` (citext or string, not null, **unique index**), `bio` (text, nullable), timestamps. Research `citext` vs `LOWER()` index for case-insensitive email uniqueness and choose; note the decision in NOTES.md.
2. Hand-write `TaskHive.Accounts.User` schema with matching fields.
3. Run, rollback, re-run the migration (`mix ecto.migrate`, `mix ecto.rollback`). Migrations must be reversible — research when `change/0` is enough vs when you need `up/down`.

### R4 — Changeset & context

1. `User.changeset(user, attrs)`: casts `name`, `email`, `bio`; validates required `name`+`email`, name max 100, email format, email uniqueness via the **constraint** (know the difference between `validate_*` (in-memory) and `*_constraint` (DB-backed) — both layers must be present).
2. Context `TaskHive.Accounts` with: `list_users/0`, `get_user/1` (returns `nil` or struct), `get_user!/1`, `create_user/1`, `update_user/2`, `delete_user/1`. Returns follow Ecto convention: `{:ok, user}` / `{:error, changeset}`.
3. Spot the doc-02 parallel: your `Member.new/1` was a poor man's changeset. In NOTES.md, map your old fields/rules/errors to their changeset equivalents.

### R5 — Controller & JSON

1. Routes via `resources "/users", UserController, except: [:new, :edit]` inside `/api`. Look at `mix phx.routes` output and understand every line.
2. `UserController` actions: `index`, `show`, `create`, `update`, `delete`. Controllers contain **no business logic** — parse params, call context, render.
3. JSON shape (hand-written `UserJSON` module): `{"data": {...}}` envelope; user exposes `id`, `name`, `email`, `bio`, `inserted_at`. Never render the raw struct — explicit field maps only (you'll add fields like password hashes soon; leaking-by-default is the bug).
4. Status codes: `201` + `Location` header on create, `200` on show/update/index, `204` no body on delete, `404` as `{"errors":{"detail":"Not Found"}}` for missing ids, `422` with field-keyed errors for invalid changesets: `{"errors":{"email":["has already been taken"]}}`.
5. Implement `404`/`422` via `action_fallback` + a `FallbackController` — no `case` statements repeated per action. Error JSON for changesets uses `Ecto.Changeset.traverse_errors/2` (find how the generated `CoreComponents`/error helpers do message interpolation).
6. PATCH vs PUT: support both on update, know what the semantic difference is supposed to be; the *"users can only PATCH their own name"* rule needs auth and arrives in doc 05 — for now `update` accepts `name` and `bio` but must **never** allow `email` updates (changeset-level enforcement, with a test proving email in the payload is ignored or rejected — pick a policy and note it).

### R6 — Tests

1. Context tests (`DataCase`): every context function, happy + invalid paths; unique-email violation tested at both validation and constraint level (hint: insert twice).
2. Controller tests (`ConnCase`): every action, including 404 and 422 bodies, the `Location` header, and the email-update rejection.
3. Write a test fixture helper `user_fixture(attrs \\ %{})` in `test/support/fixtures/accounts_fixtures.ex` — Phoenix generators have an idiom for this; copy its shape.
4. Understand why these tests can run `async: true` despite hitting the DB — research the Ecto SQL sandbox; one paragraph in NOTES.md.

## Constraints

- **Forbidden this doc:** `phx.gen.json`, `phx.gen.context`, `phx.gen.schema`. Allowed: `ecto.gen.migration` (empty file only).
- All Repo calls live in the context. `Repo` must not appear in any controller. Self-check: `grep -rn "Repo\." lib/task_hive_web/` returns nothing.
- JSON rendering by explicit maps in `UserJSON`; no `Jason.Encoder` derivation on the schema.

## Concepts to research

- `mix phx.new` options (`--no-html`, `--database`, etc. — know what you didn't use)
- Plug (the spec), `Plug.Conn`, function plugs vs module plugs, the plug pipeline
- `Phoenix.Endpoint`, `Phoenix.Router`, pipelines, scopes, `resources` macro, `mix phx.routes`
- Phoenix controllers, `action_fallback`, `FallbackController` pattern
- Phoenix contexts (read the official Contexts guide — non-negotiable)
- `Ecto.Repo`, `Ecto.Schema`, `schema` macro, field types, timestamps
- `Ecto.Migration`: `change/0` vs `up/0`/`down/0`, `create table`, `unique_index`, null constraints, citext extension
- `Ecto.Changeset`: `cast/4`, `validate_required/2`, `validate_length/3`, `validate_format/3`, `unique_constraint/2`, `traverse_errors/2`
- Validations vs constraints (in-memory vs database)
- Phoenix JSON rendering (`MyAppJSON` modules, `render/3`), `Jason`
- REST semantics: PATCH vs PUT, 201/204/404/422, `Location` header
- `Phoenix.ConnCase`, `Ecto.Adapters.SQL.Sandbox`, `DataCase`
- `config/config.exs` vs `dev.exs` vs `runtime.exs` vs `test.exs`

## Architecture notes

- Layering, the standard Phoenix answer (vs controller→service→repo): **controller → context → schema/Repo**. The context *is* the service layer and owns the Repo. There is no repository-pattern wrapper around Ecto — Ecto's `Repo` already is one.
- File map for this doc:
  ```
  priv/repo/migrations/XXXX_create_users.exs
  lib/task_hive/accounts.ex               # context
  lib/task_hive/accounts/user.ex          # schema
  lib/task_hive_web/controllers/health_controller.ex
  lib/task_hive_web/controllers/user_controller.ex
  lib/task_hive_web/controllers/user_json.ex
  lib/task_hive_web/controllers/fallback_controller.ex
  test/task_hive/accounts_test.exs
  test/task_hive_web/controllers/user_controller_test.exs
  test/support/fixtures/accounts_fixtures.ex
  ```
- Contexts are plural-noun modules grouping a domain slice (`Accounts`, not `UserService`). When unsure where a function goes, ask "which domain owns this rule?" not "which entity does it touch?".
- `update_user/2` taking the *struct* (not the id) as first arg is the Phoenix convention — the controller fetches, then updates. Keep it; it makes authorization (doc 05) natural.

## Done when

- [ ] `mix test` green (≥ 25 new tests), `mix format --check-formatted` passes
- [ ] `curl` through the full CRUD manually once — including a 422 and a 404 — and the bodies match R5.4
- [ ] Migration rolls back cleanly
- [ ] NOTES.md tour complete; you can name every child in `application.ex`'s supervision tree
- [ ] `grep -rn "Repo\." lib/task_hive_web/` is empty

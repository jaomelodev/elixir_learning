# 05 — Hand-Rolled Authentication & Authorization (API)

## Goal

Registration, login, and token authentication for the JSON API — built by hand (the `phx.gen.auth` comparison comes in doc 11). At the end, the signature rule of the curriculum is enforced: **a user can only PATCH their own user, and only the `name` field**.

## Requirements

### R1 — Password storage

1. Add a password hashing dependency: research `bcrypt_elixir` vs `argon2_elixir`, pick one, note why in NOTES.md (cost factors, memory-hardness).
2. Migration (hand-written): add `hashed_password` (string, not null) to `users`.
3. Extend `User` with a `password` **virtual field** and a separate `registration_changeset/2`: requires password, length 8..72 (find out where 72 comes from if you chose bcrypt), hashes into `hashed_password`, and never persists the plaintext. The plain `changeset/2` from doc 04 must not touch passwords.
4. `hashed_password` must never appear in any JSON or in `inspect` output — research `redact: true` on schema fields (doc 02's `Inspect` kata, now provided by Ecto). Test the JSON part.

### R2 — Registration & login (context)

1. `Accounts.register_user(attrs)` — replaces public `create_user/1` usage for self-signup.
2. `Accounts.authenticate_user(email, password)` → `{:ok, user}` or `{:error, :invalid_credentials}`. Same error for unknown email and wrong password (research user enumeration). It must also burn ~constant time when the email doesn't exist — your hashing library has a function for exactly this (`no_user_verify` or similar); find it.

### R3 — Tokens

1. Use `Phoenix.Token` (sign/verify) for API tokens — before writing code, read and note the trade-offs: `Phoenix.Token` vs DB-stored opaque token vs JWT. (You will see `phx.gen.auth`'s DB-token answer in doc 11; knowing why it does that is the goal.)
2. `POST /api/auth/register` → 201 with user JSON. `POST /api/auth/login` with email+password → `200` `{"data":{"token":"...","user":{...}}}`; wrong creds → `401` `{"errors":{"detail":"Invalid email or password"}}`.
3. Tokens expire (pick max_age, e.g. 7 days) — test expiry by signing with a back-dated timestamp (`signed_at` option).

### R4 — Authentication plug

1. Write a **module plug** `TaskHiveWeb.Plugs.AuthenticateAPI`: reads `Authorization: Bearer <token>`, verifies, loads the user, puts it in `conn.assigns.current_user`; on failure halts with `401` JSON. Hand-written — no library.
2. New router pipeline `:api_authenticated` = `:api` + the plug. Restructure routes: register/login/health stay public; all `/api/users` routes require auth. Decide and document whether `GET /api/users/:id` of *another* user is allowed (recommendation: yes for now, teams will scope it in doc 06).
3. `GET /api/me` returns the current user.
4. Tests: missing header, garbage token, expired token, valid token — all four paths, against `/api/me`.

### R5 — Authorization: the own-name rule

1. `PATCH /api/users/:id`:
   - `id` ≠ current user → `403` `{"errors":{"detail":"Forbidden"}}` (research 403 vs 404 information-leak trade-off; pick and document)
   - own id, payload contains only `name` → 200, updated
   - own id, payload contains `email`, `bio`, or anything else → policy from doc 04 R5.6 still holds for email; `bio` now allowed too or not — **decide**: the spec is *only `name` via PATCH*; so `bio` updates must get their own route or be rejected. Reject them. Test it.
2. Enforce in two layers: controller/plug refuses the request (403), and the context function used here (`Accounts.update_user_name(user, attrs)`) is *incapable* of changing other fields (dedicated changeset casting only `name`). Defense in depth: even if the web layer breaks, the context can't be misused.
3. `DELETE /api/users/:id`: only own account. Same 403 pattern. (Cascade worries arrive with teams in doc 06.)

### R6 — Scope groundwork

1. Read the Phoenix 1.8 "scopes" guide on hexdocs (Phoenix guides → Scopes). Then create your own minimal version: a struct `TaskHive.Accounts.Scope` with field `user`, built by the auth plug and assigned as `conn.assigns.current_scope`, and change `update_user_name` to `update_user_name(%Scope{} = scope, attrs)` — the function operates on `scope.user`, making "whose data?" impossible to forget at the call site. Doc 06 threads this through everything; doc 11 shows the generators doing the same.

## Constraints

- No auth libraries (no Guardian, no Pow). Only the hashing lib + `Phoenix.Token`.
- The auth plug is hand-written; halting behavior (`halt/1`) must be understood, not cargo-culted — test that a halted conn stops the pipeline (e.g., controller action never runs).
- Plaintext passwords: never logged, never in JSON, never in changeset errors. Check `filter_parameters` config — Phoenix has one; find it and confirm `password` is covered.

## Concepts to research

- Password hashing: bcrypt vs argon2, cost/work factors, why not SHA-256
- Virtual fields in Ecto schemas, `redact: true`
- Timing attacks, constant-time comparison, user enumeration
- `Phoenix.Token` (`sign/4`, `verify/4`, `max_age`, `signed_at`), `secret_key_base`
- JWT pros/cons, opaque DB tokens (revocability), session vs token auth
- Module plugs (`init/1`, `call/2`), `Plug.Conn.halt/1`, `register_before_send/2`
- `conn.assigns`, `assign/3`
- Router pipelines composition, multiple scopes with different pipelines
- `Authorization` header conventions, `get_req_header/2`
- 401 vs 403 semantics, `WWW-Authenticate`
- Authentication vs authorization
- Phoenix 1.8 scopes (the official guide)
- `Plug.Parsers` `filter_parameters` / `Phoenix` logger param filtering

## Architecture notes

- File placement:
  ```
  lib/task_hive_web/plugs/authenticate_api.ex
  lib/task_hive/accounts/scope.ex
  lib/task_hive_web/controllers/auth_controller.ex
  lib/task_hive_web/controllers/me_controller.ex     # or fold into auth/user controller — your call, note it
  ```
- Authorization granularity rule of thumb: *route-level* checks (logged in at all?) live in plugs/pipelines; *record-level* checks (is it mine?) live in contexts, expressed through scope-taking functions. Avoid authorization libraries until pain demands them.
- Dedicated changesets per use case (`registration_changeset`, `name_changeset`) instead of one mega-changeset with conditionals is the idiom — changesets are cheap; ambiguity is not.
- Convention you'll keep forever: context functions that need an actor take the scope/user as **first** argument: `update_user_name(scope, attrs)`, `list_projects(scope)`.

## Done when

- [ ] `mix test` green; ≥ 20 new tests (auth plug paths, 401s, 403s, own-name rule both layers)
- [ ] Full manual flow via curl: register → login → `/api/me` with token → PATCH own name (200) → PATCH someone else (403) → PATCH own email (rejected)
- [ ] Password absent from logs (provoke a registration log line and look at it)
- [ ] NOTES.md: token strategy trade-offs, 403-vs-404 decision, bcrypt-vs-argon2 decision
- [ ] You can explain `halt/1` and prove the pipeline stops

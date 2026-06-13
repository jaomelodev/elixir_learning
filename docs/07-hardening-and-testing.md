# 07 — Hardening, Error Contract & Testing Depth

## Goal

Make the API trustworthy: one consistent error contract, exhaustive boundary validation, a real test strategy (not just "tests exist"), static analysis, and seeds. This doc adds few features — it raises the bar on everything built so far.

## Requirements

### R1 — Unified error contract

1. Document (in `NOTES.md` or `docs/api-errors.md` in the repo) the complete error JSON contract; every error the API can emit fits one of:
   - `401` `{"errors":{"detail":"..."}}`
   - `403` `{"errors":{"detail":"Forbidden"}}`
   - `404` `{"errors":{"detail":"Not Found"}}`
   - `422` `{"errors":{"<field>":["msg", ...]}}`
   - `500` `{"errors":{"detail":"Internal Server Error"}}`
2. Audit every controller/fallback path against it. The FallbackController must handle: `{:error, %Ecto.Changeset{}}`, `{:error, :not_found}`, `{:error, :unauthorized}`, `{:error, :forbidden}` — contexts return these atoms; controllers never build error JSON inline.
3. What happens on a raised exception mid-request? Find where Phoenix turns exceptions into 404/500 (`Plug.Exception`/`Phoenix.ActionClauseError`, `debug_errors`, `render_errors` config), and make prod-mode 500s match the contract (test with `@tag :capture_log` and a route that raises — a temporary `/api/boom` route in dev/test only is acceptable).
4. Malformed JSON body → what does it currently do? Make it a clean `400`, not a 500 (research `Plug.Parsers` errors).

### R2 — Boundary validation sweep

1. Every endpoint that takes params validates them at the edge (schemaless changesets from doc 06 R5 generalize: extract a small helper `TaskHiveWeb.Params.validate(params, types, opts)` if repetition emerged).
2. IDs from the URL: what happens for `/api/tasks/banana`? `Ecto.Query.CastError` → must be 404, not 500. Test every resource.
3. Add request payload size awareness: find the `Plug.Parsers` `length` limit default; note it. (No change needed unless you disagree with the default.)

### R3 — Test architecture

1. Reorganize/confirm the three test layers, and know what belongs where:
   - **Schema/changeset tests** — pure, fast, no DB writes where possible (`Changeset` assertions)
   - **Context tests** (`DataCase`) — business rules, scoping, transactions
   - **Controller tests** (`ConnCase`) — status codes, JSON shapes, auth plumbing; do *not* re-test business rules exhaustively here
2. Fixtures: consolidate `*_fixtures.ex` modules; fixtures compose (`task_fixture/1` creates its own team/project/user chain if not given). Research fixtures vs factories (ex_machina) — stay with fixtures, note the trade-off.
3. Auth test helper: `register_and_log_in_user(%{conn: conn})` setup pattern (steal the shape from what `phx.gen.auth` would generate — peek at its docs/source without running it; running it comes in doc 11).
4. Async: every test module that can be `async: true` is; document the two reasons a module can't (shared global state — name them concretely in your suite).
5. Coverage: run `mix test --cover` (or add `excoveralls`); establish ≥ 85% line coverage on `lib/task_hive/` (core), and **know** which uncovered lines you're consciously accepting.

### R4 — Property-based testing (taster)

1. Add `stream_data`. Write property tests for two pure functions you already own, e.g.:
   - doc 01's `Money.split/2`: ∀ total, n → parts sum to total, length n, max-min ≤ 1
   - the task `sort` param parser: ∀ junk strings → either valid sort tuple or error, never a crash
2. One property test against a changeset: generated maps with random key subsets never raise, only return valid/invalid changesets.

### R5 — Static analysis & style

1. `mix format --check-formatted` in CI mindset (see R6).
2. Add `credo` (strict mode); fix or consciously disable findings — each disable gets a comment why.
3. Elixir 1.20 type checking: `mix compile --warnings-as-errors` clean. Read the warnings you *did* get along the way; pick one, write in NOTES.md what the inference caught.
4. Optional but recommended: add `dialyxir`, run it once, compare its findings with the built-in checker; decide whether to keep it (note the decision).

### R6 — Seeds & dev ergonomics

1. `priv/repo/seeds.exs`: idempotent seed (running twice doesn't duplicate or crash) creating 2 users (known passwords), 2 teams with crossed memberships, projects with ~30 tasks in mixed statuses, comments. Use your contexts, not raw `Repo.insert` — seeds are also a smoke test of your public API.
2. A `mix` alias `mix setup` already exists — read it; extend ecosystem aliases so `mix ecto.reset` (drop, create, migrate, seed) works.
3. Write a `ci.sh` (or Makefile target): format check, compile with warnings-as-errors, credo, test. It must exit non-zero on any failure. Run it; it's your pre-push habit now.

## Constraints

- No new web features. Resist.
- Coverage target applies to `lib/task_hive/` (core); the web layer is exercised via controller tests but doesn't need a number.

## Concepts to research

- `Plug.Exception` / how Phoenix renders errors, `debug_errors`, `render_errors` (`formats:` option), custom `ErrorJSON`
- `Plug.Parsers` (`:length`, JSON decode errors → `Plug.Parsers.ParseError`)
- `Ecto.Query.CastError`, UUID vs integer ids (just research; switching is stretch)
- ExUnit: `setup` vs `setup_all`, contexts/`%{conn: conn}` pattern matching in setup, `@tag`, `@describetag`, `capture_log`, `assert_receive` timeouts
- `Ecto.Adapters.SQL.Sandbox` modes (`:shared` vs ownership), why `setup_all` + DB is a trap
- Test pyramid in Phoenix terms; what ConnCase should and shouldn't test
- ex_machina vs fixture modules
- `mix test --cover`, `excoveralls`
- StreamData: `check all`, generators (`StreamData.integer/0`, `map_of`, `one_of`), shrinking
- Credo (strict), common checks; `# credo:disable-for-next-line`
- `mix compile --warnings-as-errors`; Elixir 1.20 type-checker warnings; Dialyzer success typing vs set-theoretic checking
- Mix aliases (`mix.exs` `aliases/0`)
- Idempotency in seeds (`Repo.get_by` + create-if-missing, or upserts `on_conflict`)

## Architecture notes

- The FallbackController is your single rendering point for *all* non-happy paths — when an error shape needs changing, it changes in one file. If you find error JSON being built in two places, that's the smell to fix this doc.
- Contexts returning `{:error, :forbidden | :not_found}` atoms (instead of raising) keeps authorization decisions testable without HTTP. Raising versions (`get_task!`) are for "impossible unless bug" paths. Be deliberate about which each call site uses.
- `test/support/` is compiled only in test env (check `elixirc_paths` in `mix.exs` — find it) — that's where cases, fixtures, helpers live. Never `import` test helpers from `lib/`.
- A passing `ci.sh` is the definition of "done" for every subsequent doc, even where not restated.

## Done when

- [ ] `ci.sh` green end-to-end (format, warnings-as-errors, credo, tests)
- [ ] Error contract documented; `/api/tasks/banana` → 404; malformed JSON → 400; prod-shape 500 JSON verified
- [ ] Core coverage ≥ 85% and you can name the accepted gaps
- [ ] ≥ 3 property tests, one of which caught (or you made it catch) a real edge case — write down which
- [ ] `mix ecto.reset` rebuilds a seeded dev DB in one command

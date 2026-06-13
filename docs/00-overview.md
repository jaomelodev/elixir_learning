# 00 — Curriculum Overview

A learn-by-doing path through Elixir and Phoenix. You will build **TaskHive**: a team task tracker with a JSON REST API, a server-rendered web UI, and a real-time LiveView board.

These documents are **requirement specs, not tutorials**. Each one tells you *what* to build and *which concepts* it exercises. Looking the concepts up, reading hexdocs, and figuring out the implementation is your job — that's the point. The only thing the docs explain is architecture: where files go, what the community standard is, and why.

## Toolchain (pinned to your machine)

| Tool | Version | Notes |
|------|---------|-------|
| Elixir | 1.20.0 | First "gradually typed" release — full type inference, no annotations required |
| Erlang/OTP | 29 | Installed via asdf |
| Phoenix | 1.8.x (installer 1.8.7) | Scopes, magic-link auth generator, daisyUI bundled |
| LiveView | 1.1 | Colocated hooks, keyed comprehensions |
| PostgreSQL | any recent | Default Ecto adapter |

Canonical references — prefer these over blog posts, which are often outdated:

- https://hexdocs.pm/elixir — language + stdlib
- https://elixir-lang.org/getting-started/introduction.html — official guides
- https://hexdocs.pm/phoenix — framework guides live here too, not just API docs
- https://hexdocs.pm/phoenix_live_view
- https://hexdocs.pm/ecto
- `iex` + `h Module.function` — docs in your terminal; learn this reflex early

## The app you're building

**TaskHive** features by the end:

- Users register, log in (token auth for API, session auth for web)
- Users belong to teams; teams own projects; projects contain tasks; tasks have comments
- A user can only update their **own** profile, and only the `name` field via PATCH
- All data access is scoped to the requesting user's teams — no leaking across tenants
- JSON REST API with pagination, filtering, sorting, consistent error contract
- Server-rendered web UI (forms, sessions, flash)
- Real-time LiveView task board — two browsers see each other's changes live
- Background work: daily digest, CSV task import, API rate limiting
- Shipped as a `mix release`

## Phases

| Phase | Docs | What | Phoenix? |
|-------|------|------|----------|
| 0 | 01–03 | Pure Elixir: language, data, errors, processes/OTP | No |
| 1 | 04–07 | REST API: Ecto, CRUD, hand-rolled auth, domain, testing | Yes |
| 2 | 08–09 | Web UI: controllers/HEEx, then LiveView | Yes |
| 3 | 10–11 | Concurrency in production shape, generator comparison, release | Yes |
| — | 99 | Stretch goals | — |

Do them in order. Each doc assumes the previous ones are done.

## Doc anatomy

Every doc follows this skeleton:

- **Goal** — what exists when you're done
- **Requirements** — numbered, testable statements. Treat them like acceptance criteria.
- **Constraints** — what must be hand-written vs what you may generate this step
- **Concepts to research** — a bare list of terms and module names. Search them on hexdocs / elixir-lang guides. No explanations on purpose.
- **Architecture notes** — the one explanatory section: file placement and conventions
- **Done when** — a checklist; always includes green tests

## Architecture primer (read once, applies everywhere)

**Single app, not umbrella.** Umbrella projects exist for splitting large systems; you don't need one. Worth reading about, not worth using here.

**Two top-level namespaces.** A Phoenix app named `task_hive` gives you:

```
lib/
  task_hive/        # "core" — business logic, Ecto schemas, contexts. No web concepts.
  task_hive_web/    # "web" — router, controllers, views/components, LiveViews, plugs.
```

The dependency arrow points one way: `task_hive_web` calls `task_hive`, never the reverse. If a module in `lib/task_hive` mentions `conn` or anything HTTP, it's in the wrong place.

**There is no service/repo layer.** If you come from controller → service → repository stacks: Phoenix's answer is **contexts**. A context (e.g. `TaskHive.Accounts`, `TaskHive.Projects`) is a plain module that is the public API of a slice of the domain. Controllers stay thin (parse request, call context, render response). Schemas stay dumb (struct definition + changesets, no business logic). `Repo` is only called from inside contexts — never from controllers. Read the official "Contexts" guide on hexdocs (under Phoenix guides) before doc 04.

**File placement cheat sheet** (you'll meet each of these when its doc arrives):

```
lib/task_hive/accounts.ex              # context module
lib/task_hive/accounts/user.ex         # schema
lib/task_hive_web/router.ex
lib/task_hive_web/controllers/         # controllers + JSON/HTML rendering modules
lib/task_hive_web/plugs/               # custom plugs (you create this dir)
lib/task_hive_web/live/                # LiveViews
lib/task_hive_web/components/          # shared function components, layouts
priv/repo/migrations/                  # migrations
test/                                  # mirrors lib/ structure
```

**Naming:** modules `PascalCase`, files `snake_case.ex`, one module per file, file path mirrors module name (`TaskHive.Accounts.User` → `lib/task_hive/accounts/user.ex`). `mix format` is non-negotiable; run it always.

## Rules of engagement

1. **No copy-pasting solutions.** When stuck, read hexdocs and the generated code already in your project — it's the best Phoenix style guide you own.
2. **Generators are allowed only where a doc says so.** First migration, first schema, first auth: by hand. Later docs deliberately make you generate a resource and study the diff.
3. **`iex -S mix` (or `iex -S mix phx.server`) is your laboratory.** Poke at every module you write.
4. **Write the tests the docs demand.** They're how you'll know a requirement is actually met.
5. When a "Concepts to research" term seems irrelevant, research it anyway — it's listed because it will bite you in that step.

Start with `01-elixir-foundations.md`.

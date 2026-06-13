# 99 — Stretch Goals

Optional extensions, roughly ordered by value-per-effort. Each lists the requirement sketch + concepts; same rules as always — requirements only, discovery is yours. Pick what interests you; none are prerequisites for the others unless noted.

## S1 — Keyset pagination

Replace offset pagination on the task list (doc 06 R5) with cursor/keyset pagination (`after`/`before` cursors encoding `(due_on, id)` tuples). Keep the offset version on a query-param switch and benchmark both at 100k seeded tasks.
Concepts: keyset pagination, composite ordering with tiebreakers, opaque cursor encoding (`Base.url_encode64`), `Repo.insert_all` seeding at scale, `EXPLAIN ANALYZE` via `Ecto.Adapters.SQL.explain/3`.

## S2 — File uploads on tasks (LiveView)

Attachments on tasks: drag-and-drop upload on the board (LiveView's first-class uploads), stored on local disk behind a storage behaviour (doc 10 Mailer pattern — an S3 implementation stays a stub), with download routes that enforce scope rules.
Concepts: `allow_upload/3`, `live_file_input`, `consume_uploaded_entries/3`, upload validations (size/type), `Plug.Conn.send_file/3`, content-type sniffing vs trusting extensions, storage behaviours.

## S3 — Soft delete & audit log

Tasks get soft delete (`deleted_at`) with restore endpoint; plus an `audit_logs` table recording who did what to which record (insert via `Ecto.Multi` alongside every write in `Projects` — find a way that doesn't require remembering it at every call site: wrap the Multi, or a `Repo` wrapper, or context-level composition. Compare approaches).
Concepts: partial indexes (`WHERE deleted_at IS NULL`), default query scoping pitfalls, `prepare_query/3` Repo callback, polymorphic references (and why Ecto discourages them), JSONB columns (`:map` field) for change diffs.

## S4 — GraphQL API (Absinthe)

A `/api/graphql` endpoint exposing the same domain read-side (teams → projects → tasks) plus one mutation, with dataloader to kill N+1, reusing contexts untouched.
Concepts: Absinthe schema/types/resolvers, `absinthe_plug`, Dataloader + Ecto source, GraphQL vs REST trade-offs, query complexity limits.

## S5 — Distributed TaskHive

Two release nodes clustered locally; prove PubSub crosses nodes (board updates between browsers connected to different nodes), then fix the doc-10 rate limiter for multi-node (move to the database, or accept per-node limits and document, or research `:global`/CRDT counters).
Concepts: distributed Erlang, node names/cookies, `libcluster` gossip strategy, `Phoenix.PubSub` adapters, distributed state strategies, split-brain basics.

## S6 — Telemetry & observability for real

Build on doc 10's taster: LiveDashboard wired with custom metrics (request duration percentiles, digest run time, import row throughput, rate-limit rejections), plus structured JSON logging in prod.
Concepts: `Telemetry.Metrics`, `telemetry_poller`, `Phoenix.LiveDashboard`, reporter anatomy, `Logger` backends/formatters, log correlation with request ids (`Plug.RequestId`).

## S7 — Internationalization

The web UI in en + pt-BR, including changeset error messages (you already met `traverse_errors` interpolation in doc 04 — now you'll learn where those `msgid`s live).
Concepts: Gettext, locale plugs, domain-based message files, plural forms, `Gettext` backend module, dates/number localization (`Cldr`).

## S8 — Umbrella discussion (reading, not doing)

Write a one-page position: should TaskHive become an umbrella (core app + web app), a single app with enforced boundaries (`boundary` library), or stay as is? Research real-world experience reports before answering.
Concepts: umbrella projects, `boundary` hex package, Poncho projects, mono-repo vs umbrella, compile-time dependency graphs (`mix xref graph`).

## S9 — Interop: ports & NIFs (taster)

Make slug generation (doc 01) call out once each way: a Port to an external command and a Rust NIF via Rustler doing the same job; benchmark both against pure Elixir and write down when each is worth the operational cost (NIF crash = VM crash — verify the claim safely with the dirty scheduler docs, don't actually crash prod).
Concepts: Ports, `System.cmd/3`, NIFs, Rustler, dirty schedulers, BEAM safety model implications.

## S10 — Deploy it

Actually ship the doc-11 release to a platform (Fly.io is the path of least resistance for Phoenix). Custom domain optional; running migrations on deploy, secrets management, and reading production logs are the requirements.
Concepts: `fly launch` anatomy, release commands on deploy, health checks, secrets vs env vars, IPv6 DB connections (a classic Fly+Ecto gotcha), zero-downtime deploys vs LiveView reconnects.

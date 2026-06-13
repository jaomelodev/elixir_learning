# 10 — Concurrency Inside the App (OTP in Production Shape)

## Goal

Phase 0's OTP skills return inside Phoenix: a scheduled digest worker, a concurrent CSV import behind an upload endpoint, and an ETS-based rate limiter plug. Everything supervised, everything in `application.ex`, everything tested.

## Requirements

### R1 — Daily digest worker (GenServer + timers)

1. `TaskHive.Digest.Worker`, a GenServer in the supervision tree: every interval (configurable; minutes in dev, daily in prod via config — runtime vs compile-time config, doc 04 callback) it gathers, per user, tasks due in the next 48h across their teams, and "sends" a digest.
2. "Sending" = a `TaskHive.Mailer` behaviour (doc 02 payoff) with two implementations: a Logger-backed one for dev/test and a `Swoosh` one (Phoenix ships Swoosh — use the local/dev mailbox adapter; real SMTP is out of scope, but the wiring is real). The behaviour lives in core; config decides the adapter per env.
3. The worker must not blow up the app if digest generation raises (one bad user's data ≠ no digests for anyone): isolate per-user work (`Task.Supervisor.async_stream_nolink` or try/rescue per user — research, choose, justify), log failures, continue.
4. A `mix task_hive.digest` Mix task (research custom Mix tasks) that triggers one digest run manually.
5. Tests: time-based GenServers are painful to test on real time — restructure so the *logic* (`Digest.build_for_user/2`) is a pure, directly-tested function and the GenServer only schedules. Test the scheduling part by sending the tick message yourself.
6. **Build-vs-buy paragraph** in NOTES.md: read Oban's README. When does this hand-rolled approach break down (persistence across restarts, retries, uniqueness, observability)? At what point would you reach for Oban? This curriculum hand-rolls deliberately; production usually shouldn't.

### R2 — CSV task import (streams + Task.Supervisor + uploads)

1. Endpoint `POST /api/projects/:project_id/tasks/import` accepting a CSV upload (`multipart/form-data`; research `Plug.Upload`) with columns `title;description;status;assignee_email;due_on`.
2. Processing requirements:
   - Stream the file (doc 02 R1.3 pattern) — no full read into memory
   - Validate rows via changesets; assignee resolved by email *within the team* (scope rules hold)
   - Insert valid rows in **batches** (`Repo.insert_all` — research what it skips: changesets? timestamps? — handle both consciously)
   - Response: `{"data":{"imported":n,"failed":[{"line":4,"errors":{...}}, ...]}}`
   - A failing row never aborts the batch (policy: import the good, report the bad)
3. Add a row-count cap (e.g. 10k) and reject larger files cleanly.
4. Bonus integration: imported tasks appear on the doc-09 board live (they will, if the import broadcasts — decide: one broadcast per task vs one `:tasks_imported` bulk event. Bulk. Why? Note it, and handle it in the board).
5. Concurrency decision to make and document: is parallelizing row *validation* worth it (CPU-bound vs IO-bound — measure with ~5k rows before deciding)? Insert stays batched regardless.

### R3 — Rate limiter (ETS + plug)

1. `TaskHiveWeb.Plugs.RateLimit`, applied to the `:api` pipeline: per-user (fallback per-IP for unauthenticated routes) sliding or fixed window, e.g. 100 req/min (configurable). Over limit → `429` with `retry-after` header, matching the doc-07 error contract (add 429 to it).
2. Storage: ETS table owned by a small GenServer started in the supervision tree (doc 03 R4.3 pattern: writes through the owner or atomic `:ets.update_counter` — research the atomic option; it may make the GenServer write-path unnecessary, keeping it only as table owner + sweeper).
3. Periodic cleanup of stale buckets (the owner GenServer ticks — `Process.send_after` again).
4. Tests: limit boundary (100th ok, 101st → 429), window reset, isolation between users. Time control: inject a clock function or make the window short in test config — no `Process.sleep(60_000)` in tests.
5. NOTES.md: what breaks when you run two nodes of this app? (ETS is per-node — the answer leads to Redis/distributed counters; just articulate the limit, don't fix it.)

### R4 — Supervision tree review

1. Draw (text art in NOTES.md is fine) the full tree now: endpoint, repo, PubSub, telemetry, digest worker, rate-limit owner, Task.Supervisor(s), presence.
2. For each child: restart strategy and what user-visible effect its crash+restart has. Verify two of them empirically (kill, observe app behavior, confirm restart in logs).
3. Ordering question: why must the Repo start before anything that queries it? What does `:rest_for_one` vs `:one_for_one` at the top level imply here? Phoenix's default tree answers this — read it.

## Constraints

- No Oban, no Quantum, no Redis, no rate-limit libraries — hand-rolled is the assignment; the build-vs-buy notes are where you acknowledge the real world.
- All new processes live in the supervision tree (no orphan `spawn`); `mix test` must not leak processes between tests (research `start_supervised!/1` — required for the worker and limiter tests).
- Digest queries must not N+1 across users (one pass of grouped queries; verify like doc 06 R4.4).

## Concepts to research

- `Application` env config: compile-time vs `runtime.exs`, `Application.fetch_env!/2`, config per environment
- Swoosh, adapters, `Swoosh.Adapters.Local` mailbox
- Custom Mix tasks (`Mix.Task`, `use Mix.Task`, `@shortdoc`)
- `Task.Supervisor.async_stream_nolink/4` vs `async_stream/3`, `:max_concurrency`, `on_timeout: :kill_task`
- `start_supervised!/1` in ExUnit
- `Plug.Upload`, multipart parsing, temp file lifecycle
- `Repo.insert_all/3`: timestamps, `on_conflict`, returning, no changesets — implications
- Batching strategies, `Stream.chunk_every/2`
- `:ets.update_counter/4` (atomicity), ETS table ownership & heir, `read_concurrency`/`write_concurrency`
- Fixed vs sliding window rate limiting; `retry-after`
- Injecting time/clock for testability (passing a function or module as dependency)
- `Logger` metadata, structured logging for background jobs
- Oban (read-only research: queues, retries, uniqueness, cron)
- Telemetry: emit one custom event (`:telemetry.execute`) from the importer; attach a logger handler — minimal taster

## Architecture notes

- Placement: process modules live in core, namespaced by feature:
  ```
  lib/task_hive/digest/worker.ex
  lib/task_hive/digest.ex                 # the pure logic + public API
  lib/task_hive/mailer.ex                 # behaviour
  lib/task_hive/mailer/log.ex, swoosh.ex  # impls
  lib/task_hive/rate_limit.ex             # core logic + ETS owner
  lib/task_hive_web/plugs/rate_limit.ex   # thin plug calling core
  ```
  The plug calls `TaskHive.RateLimit.check(key)` — web stays thin even for infrastructure.
- The "pure core, thin process shell" split (R1.5) is the most valuable testing pattern in OTP land: GenServers that only schedule/coordinate, logic in plain functions. If a `handle_info` has business logic, extract it.
- Behaviour + config-selected adapter (Mailer) is the standard Elixir seam for swapping implementations per environment — same pattern test mocks use (research `Mox` for later; it builds on exactly this).
- Decide config keys once, document in `NOTES.md`: `config :task_hive, TaskHive.Digest, interval: ..., enabled: ...` shape — grouping config under the module name is the convention.

## Done when

- [ ] `ci.sh` green; ≥ 25 new tests, no time-sleeps, no leaked processes (`mix test` twice in a row stays green)
- [ ] Digest visible in Swoosh dev mailbox (`/dev/mailbox` route — find it) and via the Mix task
- [ ] 5k-row CSV imports in one request; bad rows reported with line numbers; board updates live
- [ ] 429s demonstrable with a curl loop; limiter survives its own crash (kill it, limits keep working after restart — fresh, and you can say why fresh is acceptable or not)
- [ ] Supervision tree drawn with restart-impact notes; two kill experiments logged

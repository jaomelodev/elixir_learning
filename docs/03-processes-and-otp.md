# 03 — Processes & OTP (no Phoenix)

## Goal

Still in `katas`: build an in-memory task store as a supervised process tree. This is the "multi-threading" doc — except Elixir doesn't do shared-memory threads; it does isolated processes and message passing. Everything Phoenix does (every request, every LiveView, every channel) is one of these processes. Build the primitives by hand once, and Phoenix stops being magic.

## Requirements

### R1 — Raw processes (no OTP yet)

1. `Katas.Counter.start()` spawns a process holding an integer; `Counter.increment(pid)`, `Counter.get(pid)` communicate with it via `send`/`receive` only. Implement the receive loop by hand with recursion.
2. Write a test proving two counters are independent (state isolation).
3. Demonstrate (in a test) what happens when you `send` a message the loop doesn't match: the process should not crash — find out where the message went (mailbox) and write `Counter.flush_unknown/1` or document the leak. This is a classic real-world bug.
4. Link experiment: spawn a process that raises, once with `spawn/1` and once with `spawn_link/1`, and observe (test with `Process.flag(:trap_exit, true)` or `assert_receive` of `:DOWN` via monitor) the difference between links and monitors.

### R2 — `Katas.TaskStore` (GenServer)

Rewrite the store as a proper `GenServer`:

1. API: `start_link/1`, `add_task(server, attrs)` → `{:ok, task}` with server-assigned incremental id, `get_task/2`, `list_tasks/1`, `complete_task/2`, `delete_task/2`. Tasks are plain maps or your own struct.
2. Sync vs async: `add_task` must be a `call` (caller needs the id back); implement `touch(server, id)` (updates an `updated_at`) as a `cast`, then write a comment in the module explaining why casts are dangerous defaults (no backpressure, no failure signal).
3. The server must accept a `name:` option so it can be registered and addressed by name instead of pid.
4. `handle_info/2`: make the store schedule itself a `:cleanup` message every N ms (`Process.send_after/3`) that deletes completed tasks older than X. Test with a short interval.
5. Concurrency proof: a test spawning 100 `Task.async` callers each adding a task, asserting 100 unique ids afterwards — the GenServer serializes them; understand that this is both the safety *and* the bottleneck.

### R3 — Supervision

1. Add a `Supervisor` (module-based or in `application.ex` — make `katas` an application with `mix.exs` `mod:` entry) that starts the `TaskStore` named `Katas.TaskStore`.
2. Kill it (`Process.exit(pid, :kill)`) in a test or iex session and verify it restarts with fresh state. Then answer for yourself: where did the data go, and what does that imply for real systems? (Foreshadowing: the database is the state that survives; processes hold *transient* state.)
3. Try the restart strategies (`:one_for_one`, `:rest_for_one`) with a second dummy child and observe the difference in iex.
4. Read about "let it crash" and write a 5-line summary in the supervisor's `@moduledoc` — in your own words, that's the test.

### R4 — Concurrent work & ETS

1. `Katas.Importer.import_concurrently(paths)` parses many CSV files (reuse doc 02's pipeline) concurrently with `Task.async_stream/3`, with `max_concurrency` and `timeout` options exposed. Compare wall-clock time vs sequential `Enum.map` on 4+ files in a test or benchmark script.
2. One file failing must not bring down the rest — research `Task.async_stream`'s `on_timeout` / error handling, decide a policy, test it.
3. Rebuild the TaskStore's storage on **ETS**: `Katas.TaskStore.Ets` with the same API but state in an ETS table, so reads (`get_task`, `list_tasks`) go straight to ETS without passing through the GenServer (lock-free concurrent reads), while writes still serialize through the server. This read/write split is a foundational BEAM pattern (it's how Phoenix PubSub, Registry, and rate limiters work).
4. `Registry` taster: start tasks stores per "team name" via a `Registry` + `DynamicSupervisor` (`start_store(team_name)`), addressing them with via-tuples. Two teams, isolated stores, one supervisor.

### R5 — Observation

Not code: with the app running under `iex -S mix`, use `:observer.start()` (or `:recon`/`Process.list` if observer GUI is unavailable) to find your supervision tree, inspect the TaskStore's state and mailbox. Know how to find a process's memory and message queue length — this is your future production debugging kit.

## Constraints

- R1 must not use `GenServer`/`Agent` — raw `spawn`/`send`/`receive` only.
- R2+ must not use raw `spawn` — OTP abstractions only.
- No global mutable anything: if you feel the need for a module attribute as storage, stop and reconsider (research why module attributes are compile-time).

## Concepts to research

- BEAM processes vs OS threads, scheduler, reductions
- `spawn/1`, `spawn_link/1`, `send/2`, `receive`, selective receive, mailboxes
- Process isolation, links, monitors (`Process.monitor`, `:DOWN` messages), `trap_exit`
- `GenServer`: `init/1`, `handle_call/3`, `handle_cast/2`, `handle_info/2`, `call` vs `cast`, timeouts
- `Process.send_after/3`, GenServer-driven periodic work
- Process naming/registration, via-tuples, `Registry`
- `Supervisor`, child specs, `start_link`, restart strategies (`one_for_one`, `rest_for_one`, `one_for_all`), `DynamicSupervisor`
- OTP application, `application.ex`, `mod:` in `mix.exs`, supervision tree
- "Let it crash", error kernel pattern
- `Task`, `Task.async/await`, `Task.async_stream/3`, `Task.Supervisor`
- `Agent` (and why GenServer usually wins)
- ETS: table types, `:ets.new` options, read/write concurrency, ownership
- Message passing vs shared memory; why no locks/mutexes here
- `:observer`, `Process.info/2` (`:message_queue_len`, `:memory`)

## Architecture notes

- `application.ex` (the `Application` module with `start/2`) is the composition root of every Elixir app — the Phoenix project in doc 04 has one too; after this doc you'll recognize every line of it.
- Naming: the GenServer module is both the client API (public functions calling `GenServer.call`) and the server callbacks (`handle_*`) in one file. That's idiomatic — don't split client/server into separate modules.
- GenServers are not objects and not a place for domain logic — they exist for *state over time* and *concurrency control*. Domain rules stay in plain modules (your doc-02 code); the process layer orchestrates. Misusing GenServers as "services" is the most common Elixir architecture mistake; read "to GenServer or not to GenServer" discussions.
- In the real app, almost all of this is provided: the DB pool, PubSub, Presence, rate limiters are GenServers/ETS underneath. Doc 10 brings these patterns back inside Phoenix.

## Done when

- [ ] `mix test` green; ≥ 15 new tests; concurrent tests use `async: true` where safe (research what makes a test unsafe for async)
- [ ] Kill-and-restart demonstrated; you can explain where state went
- [ ] ETS-backed reads measurably/architecturally bypass the GenServer
- [ ] You can sketch (paper is fine) your supervision tree from memory
- [ ] You can answer: "why does Elixir not need mutexes?"

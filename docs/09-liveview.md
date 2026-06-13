# 09 — LiveView: The Real-Time Task Board

## Goal

Rebuild the project's task view as a LiveView 1.1 board with live filtering, inline editing, and **multi-user real-time updates** via PubSub: two browsers on the same project see each other's changes without refresh. The doc-08 controller version stays — comparing them is the lesson.

## Requirements

### R1 — Mount & auth

1. New route `live "/projects/:id/board"` inside a `live_session` that enforces authentication — research `live_session` + `on_mount` hooks; your session-based `current_scope` from doc 08 must become available in the LiveView's `socket.assigns`. (You're rebuilding the plug's job for the websocket world — note in NOTES.md why plugs alone don't cover LiveView after the initial render.)
2. Foreign project → the LiveView must not mount (404 or redirect with flash; consistent with doc 08).
3. In NOTES.md: trace the LiveView lifecycle for this page — HTTP mount, websocket connect, second `mount/3` call. Verify with an `IO.inspect(connected?(socket))` experiment, then remove it.

### R2 — The board

1. Three columns (todo / doing / done), each listing the project's tasks as cards (title, assignee, due date, comment count).
2. Task collections rendered with **streams** (`stream/3`, `stream_insert`, `stream_delete`) — not plain list assigns; research why (memory on the server, DOM patching). Use LiveView 1.1 keyed comprehension/stream idioms.
3. Status change: each card has a "move to →" control firing a `phx-click` with `phx-value-*`; `handle_event` calls the existing context function and moves the card between columns via stream operations — **no full re-query** of all tasks on every event.
4. Live filter: assignee dropdown + text search box (`phx-change` on a form, debounced — research `phx-debounce`) filtering server-side.
5. New-task form at the top of the todo column: a `<.form>` with `phx-change` validation (errors appear as you type, using the changeset) and `phx-submit` to create. After create: form resets, card appears via stream insert.

### R3 — Real-time (PubSub)

1. Context layer broadcasts: after successful `create_task` / `update_task` / `delete_task`, `Projects` broadcasts `{:task_created | :task_updated | :task_deleted, task}` on a per-project topic via `Phoenix.PubSub`. Broadcasting lives in the **context** (single source of truth), not in the LiveView — every future consumer (doc 10's digest, other LiveViews) gets it free.
2. The board subscribes on mount (only when `connected?`), handles the messages in `handle_info/2`, updates streams. Open two browsers, two users, same project: moves/creates/deletes appear on both sides. This requirement is the heart of the doc.
3. The broadcast must not echo back redundantly to the originator in a way that double-applies (idempotent stream ops make this easy — verify, don't assume).
4. Write the multi-user test: LiveViewTest supports this — two `live/2` connections in one test asserting that an action through one appears in the other's rendered HTML (`render/1` after the broadcast; research `render_async`/timing if flaky).

### R4 — Presence

1. Show "who's viewing this board" avatars/initials via `Phoenix.Presence`: track on mount, untrack automatically on disconnect, list updates live in all browsers.
2. Research what Presence gives you beyond a homemade PubSub solution (CRDT, conflict resolution across nodes) — two sentences in NOTES.md.

### R5 — Comments modal (navigation patterns)

1. Clicking a card opens task detail with comments + add-comment form. Implement with `live_navigation`: either a modal via `live_patch`/`patch` (URL changes, board stays mounted — research `handle_params`) or a separate LiveView with `navigate`. **Requirement: use `patch` + `handle_params`** so you learn the mount-vs-patch distinction; back button must work.
2. New comments broadcast + appear live for another viewer of the same task.

### R6 — Polish & comparison

1. One **colocated hook** (LiveView 1.1 feature): e.g. auto-focus the new-task input when the form opens, or local-time formatting of due dates. Deliberately tiny — the point is knowing where JS hooks live now and how `phx-hook` wires up.
2. Loading/latency: enable LiveView's latency simulator in dev, watch what users on slow links see; add `phx-disable-with` or loading classes where it hurts.
3. NOTES.md comparison table, controller page (doc 08) vs LiveView board: lines of code, what travels over the wire per interaction, state location, failure modes (server restart, lost connection — what does the user experience? research LiveView reconnect/recovery and `phx-auto-recover`).

## Constraints

- Existing contexts only, plus the broadcast additions; any other new context function needs the one-line justification.
- No JS beyond the one colocated hook.
- The doc-08 HTML pages must still work afterwards (PubSub additions must not break callers — broadcasts are fire-and-forget).
- Streams mandatory for all task/comment collections; if you catch yourself with `assign(socket, :tasks, ...)` for the lists, redo it.

## Concepts to research

- LiveView lifecycle: disconnected vs connected mount, `mount/3`, `connected?/1`, `handle_params/3`, `handle_event/3`, `handle_info/2`
- `live_session`, `on_mount`, auth in LiveView vs plugs
- Sockets and assigns; `temporary assigns` (legacy) vs **streams**; `stream/3` family, stream reset, keyed comprehensions (LiveView 1.1)
- `phx-click`, `phx-value-*`, `phx-change`, `phx-submit`, `phx-debounce`, `phx-disable-with`
- `<.form>` in LiveView, live validation with changesets
- `Phoenix.PubSub`: `subscribe/2`, `broadcast/3`, topic naming conventions
- `Phoenix.Presence`: `track/4`, `list/1`, `handle_diff`, why CRDTs
- `push_patch` vs `push_navigate` vs `redirect`; `live_patch` semantics; modals with `handle_params`
- JS commands (`Phoenix.LiveView.JS`) — show/hide without round trips
- Colocated hooks (1.1), `phx-hook`
- `Phoenix.LiveViewTest`: `live/2`, `render_click`, `render_change`, `render_submit`, `has_element?/2`, testing two live connections
- Latency simulator, reconnects, `phx-auto-recover`
- Every LiveView is a process (doc 03 payoff): one crash = one user's view, supervisor restarts it — find the supervision path

## Architecture notes

- File layout:
  ```
  lib/task_hive_web/live/board_live.ex            # or board_live/index.ex if you prefer dirs
  lib/task_hive_web/live/board_live.html.heex     # optional colocated template
  ```
  Naming convention: `SomethingLive` modules under `live/`.
- Broadcast-from-context is the architecture decision of this doc: the context is the write path's single choke point, so it's the only honest place to announce changes. LiveViews are mere subscribers — they must tolerate receiving events they caused.
- Topic naming: `"project:#{id}:tasks"` style — stable, scoped, documented in the context module.
- A LiveView is a GenServer (doc 03: you already wrote one). `handle_info` here is exactly `handle_info` there. The mental model transfer is the real payoff of Phase 0 — make it explicit for yourself.
- Keep LiveViews thin like controllers: event parsing + context calls + assign/stream updates. Domain rules still live in core. A `handle_event` longer than ~15 lines is a smell.

## Done when

- [ ] `ci.sh` green; ≥ 20 new tests including the two-browser LiveViewTest and a Presence test
- [ ] The two-real-browsers demo works: status moves, creates, deletes, comments, presence — all live on both sides
- [ ] Back/forward buttons behave through modal open/close
- [ ] Kill the LiveView process (`:observer` or `Process.exit`) while the page is open — describe what the user saw and why
- [ ] Comparison table in NOTES.md done; you can argue when you'd *still* pick a plain controller page

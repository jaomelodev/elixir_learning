# 06 — Domain Modeling: Teams, Projects, Tasks, Comments

## Goal

The full TaskHive domain with associations, multi-tenant scoping (a user only ever sees data from their teams), querying with pagination/filter/sort, and a transaction. Plus the first sanctioned use of a resource generator — followed by a mandatory autopsy of its output.

## Domain

```
User ⇄ Team        (many-to-many through memberships, membership has role: member|admin)
Team 1—* Project
Project 1—* Task   (task: title, description, status: todo|doing|done, due_on, position,
                    assignee → User, must be a member of the team)
Task 1—* Comment   (comment: body, author → User)
```

## Requirements

### R1 — Migrations & schemas (by hand)

1. Hand-written migrations for `teams`, `memberships`, `projects`, `tasks`, `comments`. Requirements on the SQL level:
   - All foreign keys with `references(..., on_delete: ...)` — decide per relation what deleting a team/project/user does (cascade? nilify? restrict?) and write the decision table in NOTES.md. Deleting a user must not delete tasks they're assigned to (nilify), but deleting a project deletes its tasks (cascade). Justify the rest.
   - `memberships`: unique composite index on `(user_id, team_id)`; `role` as string with a CHECK constraint (research `Ecto.Enum` for the schema side).
   - `tasks.status`: same treatment; default `todo`.
   - Indexes on every FK you'll query by (you will: research why FKs aren't auto-indexed in Postgres).
2. Schemas with proper associations: `has_many`, `belongs_to`, `many_to_many` (through `Membership` — use `has_many :through` or `many_to_many`; research the difference, pick, justify).
3. `Ecto.Enum` for `role` and `status` fields.

### R2 — Contexts & scoping

1. New contexts: `TaskHive.Teams` (teams + memberships) and `TaskHive.Projects` (projects + tasks + comments). Defend or adjust this split in NOTES.md — context boundaries are design; there is no single right answer, but "one context per table" is the wrong one.
2. **Every** read/write function takes the `%Scope{}` first (from doc 05): `Teams.list_teams(scope)` returns only the user's teams; `Projects.get_task!(scope, id)` raises/404s if the task's team doesn't include the user, *even if the id exists*. This is the broken-access-control killer; it must be in the **query** (joins/where on membership), not an after-fetch check.
3. Membership rules: team creator becomes admin; admins can add/remove members and change roles; members can't. Last admin can't leave/demote (transaction + check).
4. `Projects.create_task(scope, project, attrs)`: assignee, if present, must be a member of the project's team — `foreign_key_constraint` alone can't express this; research custom changeset validation with a query, or a composite FK design. Choose, implement, test the bypass attempt.

### R3 — A transaction that earns it

1. `Teams.create_team_with_defaults(scope, attrs)`: creates team + creator's admin membership + a default "General" project, atomically. Implement with `Ecto.Multi` (not nested `Repo.transaction` callbacks). Test the rollback: make the third step fail and assert nothing persisted.
2. Read about `Repo.transact/2` (new-ish in Ecto 3.13) vs `Ecto.Multi` vs `Repo.transaction/1` with functions — note in NOTES.md when each fits.

### R4 — REST endpoints

All under the authenticated pipeline, all scope-threaded:

1. `GET/POST /api/teams`, `GET /api/teams/:id`, membership endpoints `POST/DELETE /api/teams/:id/memberships` (admin-only → 403 for members).
2. Nested: `GET/POST /api/teams/:team_id/projects`, `GET/PATCH/DELETE /api/projects/:id`, `GET/POST /api/projects/:project_id/tasks`, `GET/PATCH/DELETE /api/tasks/:id`, `POST /api/tasks/:task_id/comments`. Research shallow vs deep nesting conventions; keep nesting one level deep max as above.
3. Accessing any resource outside your teams → `404` (not 403 — you decided this trade-off in doc 05; revisit: for *records*, 404 avoids existence leaks. If you chose differently, make it consistent and re-document).
4. Task JSONs embed assignee (id+name) and comment count. No N+1: research `preload` (and joined preloads); prove with a test that captures Ecto query logs or telemetry counting queries for a 20-task index (one of the listed concepts shows how).

### R5 — Listing: pagination, filtering, sorting

For `GET /api/projects/:project_id/tasks`:

1. Query params: `status` (filter), `assignee_id` (filter), `sort` (`due_on|inserted_at|position`, with `-` prefix for desc), `page`+`page_size` (offset pagination; cap page_size at 100).
2. Invalid params (unknown status, negative page, junk sort) → `422` with a field-keyed errors map. Implement parameter validation with a **schemaless changeset** (`{%{}, types}` + `cast`) — this is the idiomatic answer to "how do I validate untyped query params without a DB table", and the payoff of doc 02.
3. Response envelope: `{"data":[...],"meta":{"page":1,"page_size":25,"total_count":n,"total_pages":n}}`.
4. Build the query compositionally: a base scoped query, then small private functions each applying one filter/sort, piped. No interpolated SQL strings.
5. Read about cursor/keyset pagination; note in NOTES.md why offset pagination degrades on big tables (no need to implement keyset — stretch goal 99).

### R6 — Generator autopsy

1. On a branch (or just `git stash`-able state): run `mix phx.gen.json` for a throwaway resource, e.g. `Labels Label labels name:string color:string` — let it generate context, schema, migration, controller, JSON, tests.
2. Read **every** generated file. Write `NOTES.md` section "generator vs mine": at least 8 concrete differences (e.g., how it structures tests, fixtures, fallback usage, scope handling — 1.8 generators thread scopes!, changeset style, what it does better than your hand version, what you'd delete).
3. Decide: keep labels (wire them up properly to tasks with a join table — more practice) or delete the branch. Either is fine; the autopsy was the point.

## Constraints

- Migrations and the *first* of each new file kind still by hand; the generator touches only R6's throwaway resource.
- No query logic in controllers; no `Repo` outside contexts (re-run the doc-04 grep).
- No pagination/filter libraries (no Flop/Scrivener) — schemaless changesets + hand-built query composition.

## Concepts to research

- `has_many/3`, `belongs_to/3`, `many_to_many/3`, `has_many :through`, join schemas
- `references/2` and `on_delete` options; FK indexes in Postgres
- `Ecto.Enum`, CHECK constraints, `create constraint/3`
- `Ecto.Query`: `from`, `join`, `where`, `order_by`, `limit/offset`, `select`, `count`, dynamic ordering, query composition/piping, `Ecto.Query.dynamic/2`
- `Repo.preload/2` vs joined preload in the query, N+1 detection
- Ecto telemetry events / counting queries in tests
- `Ecto.Multi`, `Repo.transaction`, `Repo.transact/2` (Ecto 3.13)
- Schemaless changesets (`Ecto.Changeset.cast/4` with `{data, types}`)
- Composite unique indexes, partial indexes
- Offset vs keyset pagination
- REST nested-route conventions, shallow routing
- `mix phx.gen.json` / `phx.gen.context` anatomy; Phoenix 1.8 scopes in generators
- OWASP broken access control (why scope-in-the-query matters)

## Architecture notes

- Context boundaries: `Teams` owns the *who-can-see-what* primitives (membership queries); `Projects` consumes them. When `Projects` needs "is user in team?", it calls `Teams.member?(scope, team)` — cross-context calls go through public context APIs, never reach into another context's schemas/Repo queries. If that feels ceremonious here, fine — feel the ceremony, it pays at scale.
- Scoping pattern to standardize on: every context module gets a private `base_query(scope)` that already joins/filters by membership; every public function builds on it. One choke point, auditable in one screen.
- Query composition idiom: small `defp apply_status_filter(query, nil), do: query` / `defp apply_status_filter(query, status), do: where(...)` clauses piped in sequence — pattern matching as control flow again.
- File placement follows doc 04's pattern; schemas under their context dir (`lib/task_hive/projects/task.ex`), one JSON module per controller.

## Done when

- [ ] `mix test` green; ≥ 40 new tests including: cross-tenant 404s for every resource type, admin-only membership rules, Multi rollback, N+1 guard, all pagination/filter/sort edge cases
- [ ] Decision table for `on_delete` in NOTES.md
- [ ] Generator autopsy with ≥ 8 differences written down
- [ ] curl session: two users, two teams, prove user A literally cannot retrieve user B's task by id
- [ ] You can write a scoped, filtered, paginated Ecto query from scratch without looking at the last one

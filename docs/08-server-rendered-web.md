# 08 — Server-Rendered Web UI (Controllers + HEEx)

## Goal

A classic, no-JavaScript-required web UI on top of the same contexts: session login, team/project/task pages, forms bound to changesets, flash messages, daisyUI styling. You'll feel the request/response cycle in full — which is exactly what LiveView (doc 09) will then abstract away.

## Requirements

### R1 — Session auth (browser)

1. Pages: `GET /login` (form), `POST /login`, `DELETE /logout` (research why logout should not be a GET), `GET /register` + `POST /register`.
2. On login: store the user id (or a signed token) in the **session**; write the plug `TaskHiveWeb.Plugs.AuthenticateBrowser` that loads `current_scope` from the session for browser requests, redirecting to `/login` with a flash when missing. Reuse `Accounts` functions from doc 05 — zero new business logic.
3. Session security checklist (verify each, note in NOTES.md): cookie is signed (vs encrypted — difference?), `http_only`, `same_site` setting, `renew_session` on login (session fixation — research and implement).
4. The `:browser` pipeline already includes CSRF protection — find the plug, then prove it: a curl POST to `/login` without the token must 403/error. Note where the token lives in forms.
5. Root layout shows: current user name + logout button when logged in, login link otherwise.

### R2 — Pages (read paths)

1. `/teams` — list my teams. `/teams/:id` — team page: projects list + members sidebar (names, roles). `/projects/:id` — project page: tasks **table** with status badge, assignee, due date; filter controls (status dropdown, assignee dropdown) and sort links that round-trip via query params to your existing doc-06 listing logic (shared context functions — the web controller and API controller call the *same* context function; if you can't reuse it, refactor the context, not the controller).
2. All scope rules hold: foreign team URL → 404 page. Verify the error pages render HTML (not JSON) for browser routes — research how `ErrorHTML` works.
3. Extract at least three **function components** into `lib/task_hive_web/components/`: e.g. `status_badge`, `task_row`, `member_list`. Use attr/slot declarations (`attr`, `slot`, `:doc`) — they're compile-checked; misuse one on purpose to see the warning.

### R3 — Forms (write paths)

1. New/edit forms for: team, project, task (title, description, status, assignee select limited to team members, due date). Standard RESTful controller actions (`new`, `create`, `edit`, `update`, `delete` with method override — research how a `<a>`/form does DELETE without JS).
2. Forms are built from **changesets** via `to_form/2`; validation errors render inline next to fields after failed submit, with the user's input preserved. Use the generated `CoreComponents.input` component — read its source first; it's the best HEEx tutorial in your repo.
3. Flash messages on every successful create/update/delete; redirect-after-POST pattern (research why redirect, not render, after success).
4. Task delete needs a confirm (the `data-confirm` attribute — find which JS in `app.js` makes it work; this is your one peek into the asset pipeline).

### R4 — Layout & styling

1. Customize the daisyUI theme (Phoenix 1.8 ships it): change primary color + add a dark/light toggle that persists (the generated layout already has machinery — find it, understand it, adjust it).
2. Navigation bar with active-page indication; flash rendering; a consistent page header component.
3. Keep it modest. This is not a CSS course — timebox styling; the requirement is *touching* the asset pipeline knowingly (where Tailwind config lives in 1.8 — hint: it moved into CSS — how `mix assets.build` works, what esbuild does).

### R5 — Tests

1. ConnCase tests for: login/logout flow, session persistence across requests, redirect-when-anonymous, CSRF presence in forms (assert the hidden input exists), each page renders for authorized user and 404s for foreign data, form error re-render (submit invalid, assert error text + preserved input), redirect-after-success + flash.
2. Use `Floki` (or LazyHTML, whichever your Phoenix version's html helpers use) to assert on HTML structure, not string-contains, at least for the forms. Research `html_response/2`.

## Constraints

- **Zero custom JavaScript.** Everything works with forms and links (the `data-confirm` and theme toggle JS already shipped don't count).
- No new context functions unless a true gap appears — the web layer is a second consumer of the same core. Every new context function gets a one-line justification in NOTES.md.
- Verified routes (`~p"/projects/#{project}"`) everywhere; zero hardcoded path strings (grep `"/teams` in templates to self-check).

## Concepts to research

- `Plug.Session`, session stores (cookie store), signed vs encrypted cookies, `http_only`, `same_site`, session fixation & `configure_session(conn, renew: true)`
- CSRF: `protect_from_forgery`, how the token gets into forms
- Phoenix controllers for HTML: `render/3`, assigns, `put_flash/3`, `redirect/2`
- HEEx: `~H`, `{}` vs `<%= %>` interpolation (1.8 style), `:if`/`:for` attributes, components vs templates
- Function components, `attr/3`, `slot/2`, `Phoenix.Component`
- `Phoenix.HTML.Form`, `to_form/2`, `.form` / `.input` core components, `inputs_for`
- Layouts in Phoenix 1.8 (single root + app layout as function component)
- Verified routes `~p`, `Phoenix.VerifiedRoutes`
- Method override (`_method` param) for PUT/PATCH/DELETE from forms
- Post/Redirect/Get pattern
- `ErrorHTML`, custom 404/500 pages
- Asset pipeline 1.8: esbuild, tailwind via CSS `@plugin`/config-in-CSS, daisyUI themes, `mix assets.*` tasks
- `Floki` / `html_response/2` for HTML assertions

## Architecture notes

- Controllers for HTML and JSON can coexist; keep them separate (`UserController` for API under `/api` scope, `UserHTMLController` naming is *not* the convention — instead, separate router scopes route to separate controller modules; the common convention is namespacing inside `controllers/` or just distinct names. Decide one scheme, apply consistently, note it).
- Templates in 1.8 live as `*_html.ex` modules with embedded `~H` or colocated `*.html.heex` files under `controllers/<name>_html/`. Use colocated files for big pages, `~H` for small ones — mixed is normal.
- Shared UI vocabulary belongs in `components/` as function components; page-specific markup stays in the page template. The moment you copy-paste a badge twice, componentize it.
- The web layer consuming contexts identically to the API layer is the architectural proof that your contexts are right. Friction here = context API smell — fix it in core, and your API controllers get better for free.

## Done when

- [ ] `ci.sh` green; ≥ 25 new tests
- [ ] Manual click-through: register → login → create team → project → tasks → filter/sort → edit with a validation error → delete with confirm → logout. No JS console needed, no dead end without a flash/redirect
- [ ] CSRF curl experiment documented
- [ ] Session security checklist answered in NOTES.md
- [ ] You can explain what a round trip costs here (full HTML re-render) — the setup for doc 09

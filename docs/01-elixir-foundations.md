# 01 — Elixir Foundations (no Phoenix)

## Goal

A pure-Elixir Mix project named `katas` containing small, tested modules that force you through strings, numbers, dates, pattern matching, and immutability. Nothing here is throwaway: the habits (doctests, `iex`, `mix test`) carry through the whole curriculum.

## Requirements

Create the project with `mix new katas` (outside the future Phoenix app; e.g. `./katas`). Then implement the following modules, each with tests.

### R1 — `Katas.Slug`

1. `Slug.from_title(title)` turns `"Hello, World! Ça va?"` into `"hello-world-ca-va"`: lowercase, accents stripped to ASCII where possible, non-alphanumerics collapsed into single dashes, no leading/trailing dash.
2. Must handle UTF-8 correctly — `"héllo"` has 5 *characters* but 6 *bytes*; your code should make you confront the difference between `String.length/1` and `byte_size/1`.
3. `Slug.truncate(slug, max)` cuts at `max` characters without splitting a grapheme and without leaving a trailing dash.
4. Empty string and `nil` input: `from_title/1` must raise `FunctionClauseError` for `nil` (use a guard or pattern match — do **not** write an `if`), and return `""` for `""`.

### R2 — `Katas.Money`

1. Represent money as integer cents internally. `Money.parse("R$ 1.234,56")` → `{:ok, 123456}`; `Money.parse("abc")` → `{:error, :invalid}`.
2. `Money.format(123456)` → `"R$ 1.234,56"`. No floats anywhere in this module — write a test proving `Money.parse("0,10")` plus `Money.parse("0,20")` sums to exactly 30 cents (then read why `0.1 + 0.2` is a famous problem).
3. `Money.split(total_cents, n)` splits a bill among `n` people where remainders distribute fairly: `split(100, 3)` → `[34, 33, 33]`. Sum must always equal the input — property worth testing with a handful of cases.
4. At least two functions in this module must have **doctests**, and `mix test` must run them.

### R3 — `Katas.Workdays`

1. `Workdays.between(date1, date2)` counts business days (Mon–Fri) between two `Date`s, exclusive of start, inclusive of end.
2. `Workdays.next(date, n)` returns the date `n` business days after `date`.
3. Implement the iteration **recursively at least once** (no `Enum`) and once with ranges + `Enum` — keep both, name them `between/2` and `between_enum/2`, test they agree.

### R4 — Pipelines

1. `Katas.Report.summary(list_of_raw_strings)` takes lines like `"2026-01-15;lunch;R$ 35,50"` and produces a map `%{count: n, total_cents: t, first_date: %Date{}, last_date: %Date{}}`.
2. The body of `summary/1` must be a single pipeline (`|>`) of named private functions. If you find yourself nesting calls or assigning more than twice, refactor.
3. Malformed lines are skipped, but the function also has a strict variant `summary!/1` that raises on the first bad line. Note the `!` convention — you'll see it everywhere in Elixir.

### R5 — iex literacy

Not code — a habit. In `iex -S mix`, demonstrate to yourself (no deliverable, but do it):

- `h String.split` and `h Enum` — reading docs in the shell
- Recompile with `recompile/0` after editing
- `i some_value` to inspect any term's type
- Bind a variable, "change" it via `String.upcase`, and confirm the original binding's data didn't mutate — then read what rebinding actually does

## Constraints

- No dependencies except dev/test tooling. For accent stripping you may discover you want a library — don't; handle a reasonable hardcoded accent map or use `:unicode` / `String.normalize`. The struggle is the lesson.
- No `if`/`else` where pattern matching, multiple function clauses, or guards do the job. Challenge: zero `if` in the whole project.
- All public functions get `@doc` and `@spec`.

## Concepts to research

- `mix new`, Mix project layout (`lib/`, `test/`, `mix.exs`)
- Modules, named functions, arity notation (`foo/2`), private functions (`defp`)
- Pattern matching, the match operator `=`, pin operator `^`
- Multiple function clauses, guards (`when`), `FunctionClauseError`
- Immutability, variable rebinding vs mutation
- Pipe operator `|>`
- Strings as UTF-8 binaries, graphemes vs codepoints vs bytes, charlists (and why `'foo'` ≠ `"foo"`)
- `String` module, `String.normalize/2`
- Integers, floats, why floats break money math, integer division `div/2` and `rem/2`
- `Date`, `Date.range/2`, `Day of week` functions, sigils `~D[]`
- Atoms, tagged tuples `{:ok, value}` / `{:error, reason}`
- The `!` (bang) function naming convention
- `@doc`, `@moduledoc`, `@spec`, doctests
- ExUnit: `use ExUnit.Case`, `assert`, `assert_raise`, `doctest MyModule`
- `iex`: `h/1`, `i/1`, `recompile/0`

## Architecture notes

- One module per file: `lib/katas/slug.ex` holds `Katas.Slug`. Tests mirror: `test/katas/slug_test.exs`.
- Test files end in `_test.exs` (script files, not compiled) and must call the module they test by full name.
- `mix format` before every commit. Look at `.formatter.exs` — it ships with the project.
- Private helpers go *below* the public functions they support; public API reads top-down.

## Done when

- [x] `mix test` green, including doctests
- [x] At least 15 tests total across the modules
- [x] Zero `if` expressions (`grep -rn "if " lib/` — comprehension keywords don't count)
- [x] `mix format --check-formatted` passes
- [x] You can explain (to yourself) why `"héllo"` is 6 bytes, and what `{:error, :invalid}` buys you over raising

# 02 — Data, Flow & Errors (no Phoenix)

## Goal

Extend the `katas` project with a mini ETL: parse untyped input (CSV-ish text), validate it without a type system, transform it lazily, and handle failures idiomatically. This doc is your answer to "Elixir isn't statically typed — how do I trust my data?" before Ecto gives you the production-grade version in doc 04.

## Requirements

### R1 — `Katas.Csv` (parsing)

1. `Csv.parse(string)` parses lines of `name;email;age;joined_on` into a list of maps with **string keys** (`%{"name" => ..., ...}`) — raw external data should never get atom keys (research why: atom table exhaustion).
2. Handles: empty lines (skip), trailing whitespace, missing trailing fields (`{:error, {:bad_row, line_number}}` aborts the whole parse).
3. `Csv.parse_stream(path)` does the same from a file **lazily** — it must be able to process a 1M-line file without loading it into memory. Write a test that generates a large temp file and asserts memory-sane behavior by only `Enum.take/2`-ing the first 5 rows.

### R2 — `Katas.Member` (validation of untyped data)

1. Define a `Member` **struct** with fields `name`, `email`, `age`, `joined_on` and enforce at compile time that `name` and `email` are required keys (`@enforce_keys`).
2. `Member.new(map_with_string_keys)` returns `{:ok, %Member{}}` or `{:error, errors}` where `errors` is a map like `%{age: "must be a positive integer", email: "is invalid"}`. Rules:
   - `name`: non-empty string, max 100 chars
   - `email`: contains `@` with something on both sides (don't gold-plate the regex)
   - `age`: optional; if present, string-parses to integer 0..150
   - `joined_on`: ISO-8601 date string → `%Date{}`; defaults to today
3. Accumulate **all** errors, not just the first. No exceptions for control flow.
4. Add `@spec`s. Then run the Elixir 1.20 type checker (`mix compile` warnings) and deliberately write one call with a wrong type to see what the compiler now catches vs what it can't. Keep a short note of the result in the module doc.

### R3 — `Katas.Pipeline` (composition & error flow)

1. `Pipeline.import(path)` = read file → parse → validate each row → return `{:ok, [%Member{}]}` or the first error, implemented with a **`with` expression** — one clean happy path, each failure short-circuiting.
2. A lenient variant `Pipeline.import_lenient(path)` returns `%{ok: [members], errors: [{line, errors_map}]}` — partition, don't abort. Implement the partitioning with `Enum.reduce/3` into an accumulator (no pre-built `Enum.split_with` on the first pass; afterwards, refactor to whichever stdlib function you found and keep the better one).
3. `Pipeline.stats(members)` returns `%{by_join_year: %{2024 => 10, ...}, avg_age: float_or_nil}` — exercises `Enum.group_by`, `Enum.frequencies_by` or a comprehension with `into:`/`reduce:`. Try a comprehension at least once.

### R4 — Protocols & behaviours

1. Implement the `String.Chars` protocol for `Member` so `"#{member}"` produces `"Ana <ana@x.com>"`.
2. Implement `Inspect` for `Member` so the email is redacted in `inspect/1` output (`a***@x.com`) — this is a real production pattern for PII.
3. Define a behaviour `Katas.Source` with callback `read(opts) :: {:ok, String.t()} | {:error, term()}`; provide two implementations (file source, in-memory string source) and make `Pipeline.import/2` accept the source module as an argument. This is Elixir's polymorphism-for-modules; protocols are polymorphism-for-data. Know which is which when done.

### R5 — Exceptions (when they're right)

1. Define a custom exception `Katas.ImportError` with fields `line` and `reason`.
2. `Pipeline.import!/1` wraps `import/1`, raising `ImportError` on failure. Test with `assert_raise`.
3. Somewhere in the file-reading path, use `File.open` + `after` (or research `File.read` vs `File.read!` and pick deliberately) so you've handled resource cleanup once by hand.

## Constraints

- Stdlib only. No CSV/validation libraries — Ecto changesets will replace `Member.new/1` in doc 04 and the comparison is the lesson.
- `Stream` is mandatory in R1.3; everything else may use `Enum`. Know the difference before choosing.
- Recursion already proved in doc 01; here prefer `Enum`/`Stream`/comprehensions — idiomatic Elixir rarely hand-rolls recursion.

## Concepts to research

- Lists vs tuples (and their performance characteristics), keyword lists vs maps
- Map syntax: `%{}`, update syntax `%{map | key: v}`, `Map.get/put/update`, `Access` (`map["k"]`)
- String keys vs atom keys; `String.to_atom/1` danger, atom table
- `Enum` vs `Stream`, laziness, `File.stream!/1`
- `Enum.reduce/3`, `Enum.group_by/3`, `Enum.split_with/2`, `Enum.frequencies_by/2`
- Comprehensions: `for`, `into:`, `reduce:`, filters
- Structs, `@enforce_keys`, default values, structs vs maps
- `with` expressions, `else` clauses in `with`
- Tagged tuples as the error-handling backbone; "railway-oriented" style
- `raise` / `rescue` / `after`, `try` as expression, custom exceptions (`defexception`)
- When to raise vs return `{:error, _}` (library boundary rule)
- Protocols: `defprotocol`, `defimpl`, `String.Chars`, `Inspect`, deriving
- Behaviours: `@callback`, `@behaviour`, behaviours vs protocols
- Typespecs: `@spec`, `@type`, `String.t()`
- Elixir 1.20 gradual set-theoretic types, `dynamic()`, type inference — read the "Gradual set-theoretic types" page on hexdocs
- Dialyzer (just know what it is and how the new type checker differs)

## Architecture notes

- A behaviour's implementations conventionally live under the behaviour's namespace: `Katas.Source.File`, `Katas.Source.Memory` in `lib/katas/source/`.
- Validation that returns accumulated errors as data (R2) is exactly the shape of `Ecto.Changeset`. You are hand-rolling a tiny changeset on purpose; when you meet the real one, map your fields → `cast`, your rules → `validate_*`, your errors map → `traverse_errors`.
- The "parse, don't validate" idea: `Member.new/1` converts untrusted `map` → trusted `%Member{}` at the boundary, and everything past the boundary trusts the struct. This boundary pattern is how dynamic-language codebases stay sane, and it's where Elixir 1.20's inference helps most.

## Done when

- [ ] `mix test` green; ≥ 20 new tests
- [ ] 1M-line stream test passes without OOM (and you know why)
- [ ] `inspect(member)` redacts email; `to_string(member)` works
- [ ] You can articulate: when `with` vs `case`, when `{:error, _}` vs `raise`, when protocol vs behaviour
- [ ] You've seen at least one real warning from the 1.20 type checker triggered by your own wrong code

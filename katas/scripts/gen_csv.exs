# Generates a CSV of random `name;email;age;joined_on` rows.
#
# Usage (stdlib only — no project compile needed, run with plain `elixir`):
#   elixir scripts/gen_csv.exs                 # 1M rows -> tmp/members.csv
#   elixir scripts/gen_csv.exs 500000          # custom row count
#   elixir scripts/gen_csv.exs 1000000 out.csv # custom count + path
#
# Streams rows to disk lazily — constant memory regardless of count.

{count, path} =
  case System.argv() do
    [] -> {1_000_000, "tmp/members.csv"}
    [count] -> {String.to_integer(count), "tmp/members.csv"}
    [count, path] -> {String.to_integer(count), path}
  end

first_names = ~w(Alice Bob Carol Dave Eve Frank Grace Heidi Ivan Judy Mallory Niaj Olivia Peggy Trent Victor Walter)
last_names = ~w(Smith Jones Brown Taylor Wilson Davies Evans Thomas Roberts Walker Wright Hughes Green Hall Lewis)
domains = ~w(example.com test.org mail.net inbox.io demo.dev)

random_row = fn ->
  first = Enum.random(first_names)
  last = Enum.random(last_names)
  name = "#{first} #{last}"
  email = "#{String.downcase(first)}.#{String.downcase(last)}#{:rand.uniform(9999)}@#{Enum.random(domains)}"
  age = Integer.to_string(:rand.uniform(150))

  # random date in the last ~5 years
  days_ago = :rand.uniform(1825)
  joined_on = Date.add(Date.utc_today(), -days_ago) |> Date.to_iso8601()

  "#{name};#{email};#{age};#{joined_on}\n"
end

path |> Path.dirname() |> File.mkdir_p!()

file = File.stream!(path)

Stream.concat(
  ["name;email;age;joined_on\n"],
  Stream.repeatedly(random_row) |> Stream.take(count)
)
|> Stream.into(file)
|> Stream.run()

IO.puts("Wrote #{count} rows + header to #{path}")

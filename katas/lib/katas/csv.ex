defmodule Katas.Csv do
  @type csv_row_parsed :: %{String.t() => String.t()}

  @type indexed_row :: {String.t(), integer()}

  @spec parse(binary()) :: {:ok, list(csv_row_parsed())} | {:error, {:bad_row, integer()}}
  @doc """
  Parses lines of `name;email;age;joined_on` into a list of maps with **string keys** (`%{"name" => ..., ...}`).

  Skips empty lines, trims trailing whitespace, and aborts the whole parse with
  `{:error, {:bad_row, line_number}}` (1-based) on the first malformed row.
  """
  def parse(string) when is_binary(string) do
    string
    |> String.split(["\r\n", "\n"])
    |> Enum.with_index(1)
    |> Enum.drop(1)
    |> Enum.reduce_while([], fn indexed_row, acc ->
      case parse_csv_row(indexed_row) do
        :skip -> {:cont, acc}
        {:ok, row} -> {:cont, [row | acc]}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:error, _} = error -> error
      rows -> {:ok, Enum.reverse(rows)}
    end
  end

  @spec parse_csv_row(indexed_row()) ::
          :skip | {:ok, csv_row_parsed()} | {:error, {:bad_row, integer()}}
  defp parse_csv_row({row, line}) when is_binary(row) and is_integer(line) do
    if String.trim(row) == "" do
      :skip
    else
      case String.split(row, ";") do
        [name, email, age, joined_on] ->
          {:ok,
           %{
             "name" => String.trim(name),
             "email" => String.trim(email),
             "age" => String.trim(age),
             "joined_on" => String.trim(joined_on)
           }}

        _ ->
          {:error, {:bad_row, line}}
      end
    end
  end

  @spec parse_stream(binary()) :: Enumerable.t()
  @doc """
  Lazily parses `name;email;age;joined_on` from a file into a **stream** of maps
  with **string keys** (`%{"name" => ..., ...}`), skipping the header and blank lines.

  Reads incrementally via `File.stream!/1`. `Enum.take(parse_stream(path), 5)`
  touches only the first handful of lines — a 1M-line file never loads into memory.
  Nothing happens until the returned stream is enumerated.

  Unlike `parse/1`, a lazy stream cannot return `{:error, {:bad_row, n}}` as its
  value: a row isn't seen until enumeration reaches it. A malformed row therefore
  **raises** (with its 1-based line number) mid-stream. Reach for `parse/1` when you
  want the whole list up front with a tagged-tuple error instead.

  Whitespace is trimmed per field. A missing file raises `File.Error` on enumeration.
  """
  def parse_stream(path) when is_binary(path) do
    path
    |> File.stream!()
    |> Stream.with_index(1)
    |> Stream.flat_map(fn
      {_line, 1} ->
        []

      {line, index} ->
        case parse_csv_row({line, index}) do
          :skip -> []
          {:ok, row} -> [row]
          {:error, {:bad_row, n}} -> raise "malformed CSV row at line #{n}"
        end
    end)
  end
end

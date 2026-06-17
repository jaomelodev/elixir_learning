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

  @spec parse_stream(binary()) :: {:ok, list(csv_row_parsed())} | {:error, {atom(), integer()}}
  @doc """
  Parses lines `name;email;age;joined_on` from a csv file into a list of maps with **string keys** (`%{"name" => ..., ...}`).

  Skips empty lines, trims trailing whitespace, and aborts the whole parse with
  `{:error, {:bad_row, line_number}}` (1-based) on the first malformed row.
  """
  def parse_stream(path) when is_binary(path) do
    path
    |> File.stat()
    |> case do
      {:ok, _} ->
        File.stream!(path)
        |> Stream.drop(1)
        |> Stream.chunk_every(5)
        |> Enum.with_index()
        |> Enum.map(&Task.async(fn -> process_chunk(&1) end))
        |> Enum.map(&Task.await(&1))

      {:error, _} ->
        {:error, :file_not_found}
    end
  end

  defp process_chunk({chunk, index}) do
    IO.puts("#{index}")

    chunk
    |> Enum.with_index(1)
    |> Enum.reduce_while([], fn {row, row_index}, acc ->
      case parse_csv_row({row, row_index + index * 5}) do
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
end

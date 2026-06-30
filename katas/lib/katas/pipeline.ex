defmodule Katas.Pipeline do
  alias Katas.Csv
  alias Katas.Member

  @spec import(String.t()) ::
          {:ok, list(%Katas.Member{})}
          | {:error, {:bad_row, integer()}}
          | {:error, %{atom() => String.t()}}
  @doc """
  Reads file → parse → validate each row → return `{:ok, [%Member{}]}` or the first error.
  """
  def import(path) when is_binary(path) do
    with {:ok, content} <- File.read(path),
         {:ok, rows} <- Csv.parse(content) do
      Enum.reduce_while(rows, [], fn item, acc ->
        Member.new(item)
        |> case do
          {:ok, member} -> {:cont, [member | acc]}
          {:error, _} = error -> {:halt, error}
        end
      end)
      |> case do
        {:error, _} = error -> error
        members -> {:ok, Enum.reverse(members)}
      end
    else
      {:error, _} = error -> error
    end
  end

  @spec import(String.t()) ::
          %{ok: list(%Katas.Member{}), errors: list({integer(), %{atom() => String.t()}})}
  @doc """
  Reads file → parse → validate each row → return `%{ok: [%Member{}], errors: [{line, errors_map}]}`. It process all the rows and returned all the ones with errors
  """
  def import_lenient(path) when is_binary(path) do
    Katas.Csv.parse_stream(path)
    |> Enum.reduce(%{ok: [], errors: []}, fn row, acc ->
      case row do
        {:error, {_, line}} ->
          %{acc | errors: [{line, %{parse: "invalid_row"}} | acc.errors]}

        {line, item} ->
          Member.new(item)
          |> case do
            {:ok, member} -> %{acc | ok: [member | acc.ok]}
            {:error, errors} -> %{acc | errors: [{line, errors} | acc.errors]}
          end
      end
    end)
    |> case do
      %{ok: members, errors: errors} -> %{ok: Enum.reverse(members), errors: Enum.reverse(errors)}
    end
  end
end

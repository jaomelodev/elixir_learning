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
         {:ok, rows} <- Csv.parse(content),
         {:ok, members} <- validate_all(rows) do
      {:ok, members}
    end
  end

  defp validate_all(rows) do
    rows
    |> Enum.reduce_while([], fn item, acc ->
      case Member.new(item) do
        {:ok, member} -> {:cont, [member | acc]}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:error, _} = error -> error
      members -> {:ok, Enum.reverse(members)}
    end
  end

  @spec import_lenient(String.t()) ::
          %{ok: list(%Katas.Member{}), errors: list({integer(), %{atom() => String.t()}})}
  @doc """
  Reads file → parse → validate each row → return `%{ok: [%Member{}], errors: [{line, errors_map}]}`. It process all the rows and returned all the ones with errors
  """
  def import_lenient(path) when is_binary(path) do
    result =
      Katas.Csv.parse_stream(path)
      |> Enum.reduce(%{ok: [], errors: []}, fn row, acc ->
        case row do
          {:error, {_, line}} ->
            %{acc | errors: [{line, %{parse: "invalid_row"}} | acc.errors]}

          {line, item} ->
            case Member.new(item) do
              {:ok, member} -> %{acc | ok: [member | acc.ok]}
              {:error, errors} -> %{acc | errors: [{line, errors} | acc.errors]}
            end
        end
      end)

    %{ok: Enum.reverse(result.ok), errors: Enum.reverse(result.errors)}
  end
end

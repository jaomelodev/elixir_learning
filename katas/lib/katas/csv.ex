defmodule Katas.Csv do
  @type csv_row_parsed :: %{
          name: String.t(),
          email: String.t(),
          age: String.t(),
          joined_on: String.t()
        }

  @type indexed_row :: {String.t(), integer()}

  @spec parse(binary()) :: {:ok, list(csv_row_parsed())} | {:error, {:bad_row, integer()}}
  @doc """
  Parses lines of `name;email;age;joined_on` into a list of maps with **string keys** (`%{"name" => ..., ...}`)
  """
  def parse(string) when is_binary(string) do
    indexed_row_list =
      string
      |> String.split(["\r\n", "\n"])
      |> Enum.with_index()
      |> List.delete_at(0)
      |> Enum.reduce([], &filter_empty_rows/2)
      |> Enum.reverse()

    try do
      {:ok, Enum.map(indexed_row_list, &parse_csv_row_throw/1)}
    catch
      :throw, value -> value
    end
  end

  @spec filter_empty_rows(indexed_row(), list(indexed_row())) :: list(indexed_row())
  defp filter_empty_rows({row, index}, acc)
       when is_binary(row) and is_integer(index) and is_list(acc) do
    row
    |> String.trim()
    |> String.length()
    |> case do
      0 -> acc
      _ -> [{row, index} | acc]
    end
  end

  @spec parse_csv_row_throw(indexed_row()) :: csv_row_parsed()
  defp parse_csv_row_throw({row, index}) when is_binary(row) and is_integer(index) do
    with row_splited = String.split(row, ";"), 4 <- length(row_splited) do
      [name, email, age, joined_on] = Enum.map(row_splited, &String.trim/1)

      %{
        "name" => name,
        "email" => email,
        "age" => age,
        "joined_on" => joined_on
      }
    else
      _ -> throw({:error, {:bad_row, index + 1}})
    end
  end
end

defmodule Katas.Report do
  @type summary_stats :: %{
          count: integer(),
          total_cents: integer(),
          first_date: Calendar.date() | nil,
          last_date: Calendar.date() | nil
        }

  @doc ~S"""
  Takes a list of lines like `"2026-01-15;lunch;R$ 35,50"` and produces a map
  `%{count: n, total_cents: t, first_date: %Date{}, last_date: %Date{}}`.
  Malformed lines are skipped.

  ## Example

      iex> Katas.Report.summary(["2026-01-15;lunch;R$ 35,50", "garbage", "2026-02-20;coffee;R$ 0,00", "2026-11-16;dinner;R$ 100,00"])
      %{count: 3, total_cents: 13550, first_date: ~D[2026-01-15], last_date: ~D[2026-11-16]}
  """
  @spec summary([binary()]) :: summary_stats()
  def summary(lines) when is_list(lines) do
    lines
    |> Enum.map(&parse_line/1)
    |> Enum.reject(&(&1 == :error))
    |> Enum.reduce(empty_summary(), &add_record/2)
  end

  @doc ~S"""
  Like `summary/1`, but raises on the first malformed line.

  ## Example

      iex> Katas.Report.summary!(["2026-01-15;lunch;R$ 35,50", "2026-11-16;dinner;R$ 100,00"])
      %{count: 2, total_cents: 13550, first_date: ~D[2026-01-15], last_date: ~D[2026-11-16]}
      iex> Katas.Report.summary!(["2026-01-15;lunch;R$ 35,50", "garbage"])
      ** (RuntimeError) Invalid line: "garbage"
  """
  @spec summary!([binary()]) :: summary_stats()
  def summary!(lines) when is_list(lines) do
    lines
    |> Enum.map(&parse_line!/1)
    |> Enum.reduce(empty_summary(), &add_record/2)
  end

  @spec empty_summary() :: summary_stats()
  defp empty_summary do
    %{count: 0, total_cents: 0, first_date: nil, last_date: nil}
  end

  @spec add_record(%{date: Calendar.date(), cents: integer()}, summary_stats()) :: summary_stats()
  defp add_record(%{date: date, cents: cents}, acc) do
    %{
      count: acc.count + 1,
      total_cents: acc.total_cents + cents,
      first_date: acc.first_date || date,
      last_date: date
    }
  end

  @spec parse_line(binary()) :: %{date: Calendar.date(), cents: integer()} | :error
  defp parse_line(line) when is_binary(line) do
    with [date_str, _desc, amount_str] <- String.split(line, ";"),
         {:ok, date} <- Date.from_iso8601(date_str),
         {:ok, cents} <- parse_amount(amount_str) do
      %{date: date, cents: cents}
    else
      _ -> :error
    end
  end

  @spec parse_line!(binary()) :: %{date: Calendar.date(), cents: integer()}
  defp parse_line!(line) when is_binary(line) do
    case parse_line(line) do
      :error -> raise "Invalid line: #{inspect(line)}"
      record -> record
    end
  end

  @spec parse_amount(binary()) :: {:ok, integer()} | {:error, :invalid}
  defp parse_amount("R$" <> _ = string) do
    string
    |> String.replace(~r/\D+/u, "")
    |> Integer.parse()
    |> case do
      {value, _} -> {:ok, value}
      :error -> {:error, :invalid}
    end
  end

  defp parse_amount(_other), do: {:error, :invalid}
end

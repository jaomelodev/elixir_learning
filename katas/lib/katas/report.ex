defmodule Katas.Report do
  @type summary_stats :: %{
          count: integer(),
          total_cents: integer(),
          first_date: Calendar.date(),
          last_date: Calendar.date()
        }

  @doc ~S"""
  Takes lines like `"2026-01-15;lunch;R$ 35,50"` and produces a map `%{count: n, total_cents: t, first_date: %Date{}, last_date: %Date{}}`.

  ## Example

      iex> Katas.Report.summary("2026-01-15;lunch;R$ 35,50;2027-20-20;R$ 0.00;R$ 100,00;2026-11-16")
      %{count: 5, total_cents: 13550, first_date: ~D[2026-01-15], last_date: ~D[2026-11-16]}
  """
  @spec summary(binary()) :: summary_stats()
  def summary(list_of_raw_strings) when is_binary(list_of_raw_strings) do
    list_of_raw_strings
    |> String.split(";")
    |> Enum.reduce(%{count: 0, total_cents: 0, first_date: nil, last_date: nil}, fn string, acc ->
      handle_item(string, acc)
    end)
  end

  @spec handle_item(binary(), summary_stats()) :: summary_stats()
  defp handle_item(string, acc) do
    %{
      count: count,
      total_cents: total_cents,
      first_date: first_date,
      last_date: last_date
    } = acc

    parse_item(string)
    |> case do
      {:ok, :date, date} ->
        %{
          count: count + 1,
          total_cents: total_cents,
          first_date: first_date || date,
          last_date: date
        }

      {:ok, :cents, cents} ->
        %{
          count: count + 1,
          total_cents: total_cents + cents,
          first_date: first_date,
          last_date: last_date
        }

      _other ->
        acc
    end
  end

  @spec parse_item(binary()) ::
          {:ok, :date, Calendar.date()} | {:ok, :cents, integer()} | {:error, :invalid}
  defp(parse_item(string) when is_binary(string)) do
    parse_date(string)
    |> case do
      {:ok, value} ->
        {:ok, :date, value}

      _other ->
        parse_reals(string)
        |> case do
          {:ok, value} -> {:ok, :cents, value}
          _other -> {:error, :invalid}
        end
    end
  end

  @spec parse_reals(binary()) :: {:ok, integer()} | {:error, :invalid}
  defp parse_reals(string) when is_binary(string) do
    case String.starts_with?(string, "R$") do
      false ->
        {:error, :invalid}

      true ->
        string
        |> String.replace(~r/\D+/u, "")
        |> Integer.parse()
        |> case do
          :error -> {:error, :invalid}
          {value, _} -> {:ok, value}
        end
    end
  end

  @spec parse_date(binary()) :: {:ok, Calendar.date()} | {:error, atom()}
  defp parse_date(string) when is_binary(string) do
    Date.from_iso8601(string)
  end

  @doc ~S"""
  Takes lines like `"2026-01-15;R$ 35,50"` and produces a map `%{count: n, total_cents: t, first_date: %Date{}, last_date: %Date{}}`. It raise if the input is malformed

  ## Example

      iex> Katas.Report.summary!("2026-01-15;R$ 35,50;R$ 0.00;R$ 100,00;2026-11-16")
      %{count: 5, total_cents: 13550, first_date: ~D[2026-01-15], last_date: ~D[2026-11-16]}
      iex> Katas.Report.summary!("2026-01-15;lunch;R$ 35,50;2027-20-20;R$ 0.00;R$ 100,00;2026-11-16")
      ** (RuntimeError) Invalid string
  """
  @spec summary!(binary()) :: summary_stats()
  def summary!(list_of_raw_strings) when is_binary(list_of_raw_strings) do
    list_of_raw_strings
    |> String.split(";")
    |> Enum.reduce(%{count: 0, total_cents: 0, first_date: nil, last_date: nil}, fn string, acc ->
      handle_item!(string, acc)
    end)
  end

  @spec handle_item!(binary(), summary_stats()) :: summary_stats()
  defp handle_item!(string, acc) do
    %{
      count: count,
      total_cents: total_cents,
      first_date: first_date,
      last_date: last_date
    } = acc

    parse_item(string)
    |> case do
      {:ok, :date, date} ->
        %{
          count: count + 1,
          total_cents: total_cents,
          first_date: first_date || date,
          last_date: date
        }

      {:ok, :cents, cents} ->
        %{
          count: count + 1,
          total_cents: total_cents + cents,
          first_date: first_date,
          last_date: last_date
        }

      _other ->
        raise "Invalid string"
    end
  end
end

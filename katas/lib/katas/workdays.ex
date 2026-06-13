defmodule Katas.Workdays do
  @doc """
  Counts business days (Mon–Fri) between two `Date`s, exclusive of start, inclusive of end

  ## Example
      iex> Katas.Workdays.between(~D[2026-06-12], ~D[2026-06-19])
      5
  """
  @spec between(Calendar.date(), Calendar.date()) :: integer()
  def between(%Date{} = date1, %Date{} = date2) do
    case Date.compare(date1, date2) do
      :lt ->
        next_day = Date.add(date1, 1)

        days_to_add =
          case Date.day_of_week(next_day) in 1..5 do
            true -> 1
            false -> 0
          end

        days_to_add + between(next_day, date2)

      _ ->
        0
    end
  end

  @doc """
  Counts business days (Mon–Fri) between two `Date`s, exclusive of start, inclusive of end usin Enum

  ## Example
      iex> Katas.Workdays.between_enum(~D[2026-06-12], ~D[2026-06-19])
      5
  """
  @spec between_enum(Calendar.date(), Calendar.date()) :: integer()
  def between_enum(%Date{} = date1, %Date{} = date2) do
    case Date.compare(date1, date2) do
      :lt ->
        Date.range(Date.add(date1, 1), date2)
        |> Enum.count(fn date -> Date.day_of_week(date) in 1..5 end)

      _ ->
        0
    end
  end

  @doc """
  Returns the next worday date `n` business days after `date`

  ## Example
      iex> Katas.Workdays.next(~D[2026-06-12], 5)
      ~D[2026-06-19]
  """
  @spec next(Calendar.date(), integer()) :: Calendar.date()
  def next(%Date{} = date, n) when n >= 1 do
    next_day = Date.add(date, 1)

    days_to_reduce =
      case Date.day_of_week(next_day) in 1..5 do
        true -> 1
        false -> 0
      end

    next(next_day, n - days_to_reduce)
  end

  # No @spec or @doc here! Just the second clause.
  def next(%Date{} = date, n) when n == 0 do
    date
  end
end

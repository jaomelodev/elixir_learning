defmodule Katas.Workdays do
  @doc """
  Counts business days (Mon–Fri) between two `Date`s, exclusive of start, inclusive of end

  ## Example
      iex> Katas.Workdays.between(~D[2026-06-12], ~D[2026-06-19])
      5
  """
  @spec between(Calendar.date(), Calendar.date()) :: integer()
  def between(%Date{} = date1, %Date{} = date2) do
    next_day = Date.add(date1, 1)

    is_weekday = Date.day_of_week(next_day) in 1..5

    days_to_add =
      case is_weekday do
        true -> 1
        false -> 0
      end

    case next_day == date2 do
      true -> days_to_add
      false -> days_to_add + between(next_day, date2)
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
    exclusive_start = Date.add(date1, 1)

    Date.range(exclusive_start, date2)
    |> Enum.filter(fn date -> Date.day_of_week(date) != 6 and Date.day_of_week(date) != 7 end)
    |> length()
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

    day_of_week = Date.day_of_week(next_day)

    is_weekday = day_of_week in 1..5

    days_to_reduce = if is_weekday, do: 1, else: 0

    next(next_day, n - days_to_reduce)
  end

  # No @spec or @doc here! Just the second clause.
  def next(%Date{} = date, n) when n == 0 do
    date
  end
end

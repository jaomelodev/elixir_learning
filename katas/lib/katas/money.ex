defmodule Katas.Money do
  @doc ~S"""
  Parses the money string to an integer or return invalid if the string can't be converted to integer

  ## Example

      iex> Katas.Money.parse("R$ 1.234,56")
      {:ok, 123456}
      iex> Katas.Money.parse("abc")
      {:error, :invalid}
  """
  @spec parse(binary()) :: {:ok, integer()} | {:error, :invalid}
  def parse(money_string) when is_binary(money_string) do
    money_string
    |> String.replace(~r/\D+/u, "")
    |> Integer.parse()
    |> case do
      {value, _} -> {:ok, value}
      :error -> {:error, :invalid}
    end
  end

  @doc ~S"""
  Format a given integer to a brazilian reals string.

  ## Example

      iex> Katas.Money.format(123456)
      "R$ 1.234,56"
  """
  @spec format(integer()) :: binary()
  def format(money) when is_integer(money) do
    reals =
      div(money, 100)
      |> Integer.to_charlist()
      |> fmt()

    cents =
      rem(money, 100)
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    "R$ " <> reals <> "," <> cents
  end

  # Format a given charlist to a string that separate the hundreds of a number.
  @spec fmt(charlist()) :: binary()
  defp fmt(num) when is_list(num) do
    {h, t} = Enum.split(num, rem(length(num), 3))
    t = t |> Enum.chunk_every(3) |> Enum.join(".")

    case {h, t} do
      {[], _} -> t
      {_, ""} -> "#{h}"
      _ -> "#{h}." <> t
    end
  end

  @doc ~S"""
  Splits a bill among `n` people where remainders distribute fairly starting from the start of the list.

  ## Example

      iex> Katas.Money.split(100, 3)
      [34, 33, 33]
  """
  @spec split(integer(), integer()) :: list(integer())
  def split(total_cents, n) when is_integer(total_cents) when is_integer(n) do
    equal_amount = div(total_cents, n)

    remaining = rem(total_cents, n)

    List.duplicate(equal_amount + 1, remaining) ++ List.duplicate(equal_amount, n - remaining)
  end
end

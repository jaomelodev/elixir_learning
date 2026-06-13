defmodule Katas.MoneyTest do
  use ExUnit.Case
  doctest Katas.Money

  test "no float math: 0,10 + 0,20 sums to exactly 30 cents" do
    {:ok, a} = Katas.Money.parse("0,10")
    {:ok, b} = Katas.Money.parse("0,20")
    assert a + b == 30
  end

  test "format pads cents below 10" do
    assert Katas.Money.format(105) == "R$ 1,05"
  end

  test "format does not emit a leading dot for 3-digit reals" do
    assert Katas.Money.format(50000) == "R$ 500,00"
  end

  test "split sums to total and has n parts" do
    cases = [{100, 3}, {10, 4}, {7, 7}, {1, 3}, {1000, 1}]

    for {total, n} <- cases do
      parts = Katas.Money.split(total, n)
      assert Enum.sum(parts) == total
      assert length(parts) == n
    end
  end
end

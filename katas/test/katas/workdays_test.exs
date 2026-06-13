defmodule Katas.WorkdaysTest do
  use ExUnit.Case
  doctest Katas.Workdays

  test "between and between_enum agree" do
    cases = [
      {~D[2026-06-12], ~D[2026-06-19]},
      {~D[2026-06-15], ~D[2026-06-17]},
      {~D[2026-01-01], ~D[2026-03-01]},
      {~D[2026-06-13], ~D[2026-06-14]}
    ]

    for {d1, d2} <- cases do
      assert Katas.Workdays.between(d1, d2) == Katas.Workdays.between_enum(d1, d2)
    end
  end

  test "empty interval is zero, not an infinite loop" do
    assert Katas.Workdays.between(~D[2026-06-12], ~D[2026-06-12]) == 0
    assert Katas.Workdays.between_enum(~D[2026-06-12], ~D[2026-06-12]) == 0
  end

  test "next skips weekends" do
    # Friday + 1 business day -> Monday
    assert Katas.Workdays.next(~D[2026-06-12], 1) == ~D[2026-06-15]
  end
end

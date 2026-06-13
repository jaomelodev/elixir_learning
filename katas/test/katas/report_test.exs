defmodule Katas.ReportTest do
  use ExUnit.Case
  doctest Katas.Report

  test "summary skips malformed lines" do
    result =
      Katas.Report.summary([
        "2026-01-15;lunch;R$ 35,50",
        "not a line",
        "2026-13-99;bad;R$ 1,00",
        "2026-11-16;dinner;R$ 100,00"
      ])

    assert result == %{
             count: 2,
             total_cents: 13550,
             first_date: ~D[2026-01-15],
             last_date: ~D[2026-11-16]
           }
  end

  test "summary! raises on the first malformed line" do
    assert_raise RuntimeError, fn ->
      Katas.Report.summary!(["2026-01-15;lunch;R$ 35,50", "garbage"])
    end
  end
end

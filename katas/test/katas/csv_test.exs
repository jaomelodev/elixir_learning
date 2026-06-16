defmodule Katas.CsvTest do
  use ExUnit.Case
  doctest Katas.Csv

  test "should parse the csv synchronically" do
    csv_string = """
    name;email;age;joined_on
    Alice;alice@example.com;30;2026-01-15

    Bob;bob@example.com;25;2026-05-20
    """

    expected_result =
      {:ok,
       [
         %{
           "name" => "Alice",
           "email" => "alice@example.com",
           "age" => "30",
           "joined_on" => "2026-01-15"
         },
         %{
           "name" => "Bob",
           "email" => "bob@example.com",
           "age" => "25",
           "joined_on" => "2026-05-20"
         }
       ]}

    result = Katas.Csv.parse(csv_string)

    assert result == expected_result
  end

  test "should fail when there's a missing field" do
    csv_string = """
    name;email;age;joined_on
    Alice;;30;2026-01-15

    Bob;25;2026-05-20
    """

    expected_result = {:error, {:bad_row, 4}}

    result = Katas.Csv.parse(csv_string)

    assert result == expected_result
  end

  test "uses string keys, never atom keys" do
    csv_string = "name;email;age;joined_on\nAlice;a@x.com;30;2026-01-15\n"

    {:ok, [row]} = Katas.Csv.parse(csv_string)

    assert Map.keys(row) |> Enum.all?(&is_binary/1)
  end

  test "trims trailing/leading whitespace on each field" do
    csv_string = "name;email;age;joined_on\n  Alice  ; a@x.com ;30; 2026-01-15 \n"

    expected = {:ok, [%{"name" => "Alice", "email" => "a@x.com", "age" => "30", "joined_on" => "2026-01-15"}]}

    assert Katas.Csv.parse(csv_string) == expected
  end

  test "handles \\r\\n (CRLF) line endings" do
    csv_string = "name;email;age;joined_on\r\nAlice;a@x.com;30;2026-01-15\r\nBob;b@x.com;25;2026-05-20\r\n"

    {:ok, rows} = Katas.Csv.parse(csv_string)

    assert length(rows) == 2
    assert Enum.at(rows, 0)["name"] == "Alice"
    assert Enum.at(rows, 1)["name"] == "Bob"
  end

  test "empty string yields no rows" do
    assert Katas.Csv.parse("") == {:ok, []}
  end

  test "header-only input yields no rows" do
    assert Katas.Csv.parse("name;email;age;joined_on\n") == {:ok, []}
  end

  test "skips multiple blank lines between rows" do
    csv_string = "name;email;age;joined_on\nAlice;a@x.com;30;2026-01-15\n\n\n\nBob;b@x.com;25;2026-05-20\n"

    {:ok, rows} = Katas.Csv.parse(csv_string)

    assert length(rows) == 2
  end

  test "extra fields are a bad row" do
    csv_string = "name;email;age;joined_on\nAlice;a@x.com;30;2026-01-15;extra\n"

    assert Katas.Csv.parse(csv_string) == {:error, {:bad_row, 2}}
  end

  test "reports the correct 1-based line number with blanks before the bad row" do
    csv_string = "name;email;age;joined_on\nAlice;a@x.com;30;2026-01-15\n\nBob;only;two\n"

    assert Katas.Csv.parse(csv_string) == {:error, {:bad_row, 4}}
  end

  test "aborts whole parse, returns no partial results on bad row" do
    csv_string = "name;email;age;joined_on\nAlice;a@x.com;30;2026-01-15\nBad;row\nCarol;c@x.com;40;2026-03-03\n"

    assert Katas.Csv.parse(csv_string) == {:error, {:bad_row, 3}}
  end

  test "empty fields are allowed at parse level (count is what matters)" do
    csv_string = "name;email;age;joined_on\nAlice;;;\n"

    expected = {:ok, [%{"name" => "Alice", "email" => "", "age" => "", "joined_on" => ""}]}

    assert Katas.Csv.parse(csv_string) == expected
  end

  test "input without trailing newline parses the last row" do
    csv_string = "name;email;age;joined_on\nAlice;a@x.com;30;2026-01-15"

    {:ok, rows} = Katas.Csv.parse(csv_string)

    assert length(rows) == 1
  end
end

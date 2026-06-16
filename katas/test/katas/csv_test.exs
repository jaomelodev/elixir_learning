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
end

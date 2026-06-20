defmodule Katas.CsvTest do
  use ExUnit.Case
  doctest Katas.Csv

  describe "parse/1" do
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

      expected =
        {:ok,
         [%{"name" => "Alice", "email" => "a@x.com", "age" => "30", "joined_on" => "2026-01-15"}]}

      assert Katas.Csv.parse(csv_string) == expected
    end

    test "handles \\r\\n (CRLF) line endings" do
      csv_string =
        "name;email;age;joined_on\r\nAlice;a@x.com;30;2026-01-15\r\nBob;b@x.com;25;2026-05-20\r\n"

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
      csv_string =
        "name;email;age;joined_on\nAlice;a@x.com;30;2026-01-15\n\n\n\nBob;b@x.com;25;2026-05-20\n"

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
      csv_string =
        "name;email;age;joined_on\nAlice;a@x.com;30;2026-01-15\nBad;row\nCarol;c@x.com;40;2026-03-03\n"

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

  describe "parse_stream/1" do
    # Writes `content` to a unique temp file, returns path, cleans up after test.
    defp write_tmp(content) do
      path =
        Path.join(
          System.tmp_dir!(),
          "csv_stream_test_#{System.unique_integer([:positive])}.csv"
        )

      File.write!(path, content)
      on_exit(fn -> File.rm(path) end)
      path
    end

    # Builds a CSV (header + `count` valid data rows). `bad_at` (1-based data row,
    # i.e. file line number) injects a malformed row at that position.
    defp build_csv(count, bad_at \\ nil) do
      rows =
        for i <- 1..count do
          line = i + 1

          if line == bad_at do
            "Bad;row\n"
          else
            "Name#{i};name#{i}@x.com;30;2026-01-15\n"
          end
        end

      IO.iodata_to_binary(["name;email;age;joined_on\n" | rows])
    end

    test "returns a lazy stream, not a materialized list" do
      path = write_tmp(build_csv(3))

      stream = Katas.Csv.parse_stream(path)

      # A composed lazy stream is a function (Stream.transform), not an eager
      # list. Nothing is read until enumerated.
      refute is_list(stream)
      assert is_function(stream, 2)
    end

    test "enumerates to the same rows parse/1 returns" do
      content = build_csv(50)
      path = write_tmp(content)

      {:ok, parsed} = Katas.Csv.parse(content)

      assert Enum.to_list(Katas.Csv.parse_stream(path)) == parsed
    end

    test "yields maps with string keys, never atom keys" do
      path = write_tmp("name;email;age;joined_on\nAlice;a@x.com;30;2026-01-15\n")

      assert [row] = Enum.to_list(Katas.Csv.parse_stream(path))
      assert Map.keys(row) |> Enum.all?(&is_binary/1)
    end

    test "trims whitespace on each field" do
      path = write_tmp("name;email;age;joined_on\n  Alice  ; a@x.com ;30; 2026-01-15 \n")

      assert [row] = Enum.to_list(Katas.Csv.parse_stream(path))

      assert row == %{
               "name" => "Alice",
               "email" => "a@x.com",
               "age" => "30",
               "joined_on" => "2026-01-15"
             }
    end

    test "skips blank lines" do
      path =
        write_tmp(
          "name;email;age;joined_on\nAlice;a@x.com;30;2026-01-15\n\n\nBob;b@x.com;25;2026-05-20\n"
        )

      assert length(Enum.to_list(Katas.Csv.parse_stream(path))) == 2
    end

    test "header-only file yields no rows" do
      path = write_tmp("name;email;age;joined_on\n")

      assert Enum.to_list(Katas.Csv.parse_stream(path)) == []
    end

    test "preserves row order" do
      path = write_tmp(build_csv(30))

      rows = Enum.to_list(Katas.Csv.parse_stream(path))
      assert Enum.map(rows, & &1["name"]) == Enum.map(1..30, &"Name#{&1}")
    end

    test "raises with the 1-based line number on a malformed row" do
      # bad row at file line 4 (header=1, data rows start at 2)
      path = write_tmp(build_csv(5, 4))

      assert_raise RuntimeError, ~r/line 4/, fn ->
        Enum.to_list(Katas.Csv.parse_stream(path))
      end
    end

    test "does not raise on a bad row past the rows actually taken (laziness)" do
      # malformed row at line 100, but we only consume the first 5 — never reached.
      path = write_tmp(build_csv(200, 100))

      rows = Katas.Csv.parse_stream(path) |> Enum.take(5)
      assert length(rows) == 5
    end

    test "missing file raises File.Error only on enumeration" do
      path =
        Path.join(System.tmp_dir!(), "does_not_exist_#{System.unique_integer([:positive])}.csv")

      # building the stream is fine — it's lazy
      stream = Katas.Csv.parse_stream(path)

      assert_raise File.Error, fn -> Enum.to_list(stream) end
    end

    test "is lazy: Enum.take/2 on a huge file reads only the first rows (no OOM)" do
      # ~200k rows; fully materialized as maps this is 50+ MB. Taking 5 must not.
      path = write_tmp(build_csv(200_000))

      :erlang.garbage_collect()
      before = :erlang.memory(:total)

      rows = Katas.Csv.parse_stream(path) |> Enum.take(5)

      used = :erlang.memory(:total) - before

      assert length(rows) == 5
      assert Enum.at(rows, 0)["name"] == "Name1"
      assert Enum.at(rows, 4)["name"] == "Name5"

      # Pulling 5 rows must not allocate anything near the whole-file size.
      assert used < 20_000_000,
             "took #{div(used, 1_000_000)} MB to read 5 rows — stream isn't lazy"
    end
  end
end

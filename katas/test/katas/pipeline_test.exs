defmodule Katas.PipelineTest do
  use ExUnit.Case

  alias Katas.Member

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

  defp build_csv(count, bad_at \\ nil, malformed_at \\ nil) do
    rows =
      for i <- 1..count do
        line = i + 1

        case line do
          _ when line == bad_at -> "Bad;row\n"
          _ when line == malformed_at -> "Name#{i};name#{i}@x.com;abc;2026-01-15\n"
          _ -> "Name#{i};name#{i}@x.com;30;2026-01-15\n"
        end
      end

    IO.iodata_to_binary(["name;email;age;joined_on\n" | rows])
  end

  describe "import/1" do
    test "should be able to parse the csv" do
      path = write_tmp(build_csv(2))

      expected_result =
        {:ok,
         [
           %Member{name: "Name1", email: "name1@x.com", age: 30, joined_on: ~D[2026-01-15]},
           %Member{name: "Name2", email: "name2@x.com", age: 30, joined_on: ~D[2026-01-15]}
         ]}

      result = Katas.Pipeline.import(path)

      assert result == expected_result
    end

    test "should not parse a bad row" do
      path = write_tmp(build_csv(3, 2))

      expected_result = {:error, {:bad_row, 2}}

      result = Katas.Pipeline.import(path)

      assert result == expected_result
    end

    test "should not create a member from a malformed line values" do
      path = write_tmp(build_csv(3, nil, 2))

      expected_result = {:error, %{age: "must be a positive integer between 0 and 150"}}

      result = Katas.Pipeline.import(path)

      assert result == expected_result
    end
  end

  describe "import_lenient/1" do
    test "should be able to parse the csv" do
      path = write_tmp(build_csv(2))

      expected_result =
        %{
          ok: [
            %Member{name: "Name1", email: "name1@x.com", age: 30, joined_on: ~D[2026-01-15]},
            %Member{name: "Name2", email: "name2@x.com", age: 30, joined_on: ~D[2026-01-15]}
          ],
          errors: []
        }

      result = Katas.Pipeline.import_lenient(path)

      assert result == expected_result
    end

    test "should parse a bad row and return the parse error with the line" do
      path = write_tmp(build_csv(3, 2))

      expected_result = %{
        ok: [
          %Member{name: "Name2", email: "name2@x.com", age: 30, joined_on: ~D[2026-01-15]},
          %Member{name: "Name3", email: "name3@x.com", age: 30, joined_on: ~D[2026-01-15]}
        ],
        errors: [{2, %{parse: "invalid_row"}}]
      }

      result = Katas.Pipeline.import_lenient(path)

      assert result == expected_result
    end

    test "should not create a member from a malformed line values" do
      path = write_tmp(build_csv(3, nil, 2))

      expected_result = %{
        ok: [
          %Member{name: "Name2", email: "name2@x.com", age: 30, joined_on: ~D[2026-01-15]},
          %Member{name: "Name3", email: "name3@x.com", age: 30, joined_on: ~D[2026-01-15]}
        ],
        errors: [{2, %{age: "must be a positive integer between 0 and 150"}}]
      }

      result = Katas.Pipeline.import_lenient(path)

      assert result == expected_result
    end
  end
end

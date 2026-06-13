defmodule Katas.SlugTest do
  use ExUnit.Case
  doctest Katas.Slug

  test "nil raises FunctionClauseError" do
    assert_raise FunctionClauseError, fn -> Katas.Slug.from_title(nil) end
  end

  test "empty string returns empty string" do
    assert Katas.Slug.from_title("") == ""
  end

  test "graphemes vs bytes: accents stripped to ASCII" do
    assert String.length("héllo") == 5
    assert byte_size("héllo") == 6
    assert Katas.Slug.from_title("héllo") == "hello"
  end

  test "keeps digits, collapses runs, trims dashes" do
    assert Katas.Slug.from_title("  Top 10!!  Things  ") == "top-10-things"
  end

  test "truncate leaves no trailing dash" do
    refute String.ends_with?(Katas.Slug.truncate("hello-world-ca-va", 6), "-")
  end
end

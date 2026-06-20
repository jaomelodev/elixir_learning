defmodule Katas.MemberTest do
  use ExUnit.Case
  doctest Katas.Member

  alias Katas.Member

  @valid_attrs %{
    "name" => "John",
    "email" => "john@email.com",
    "age" => "24",
    "joined_on" => "2026-06-18"
  }

  defp attrs(overrides), do: Map.merge(@valid_attrs, overrides)

  describe "new/1 success" do
    test "creates member from full string-key map" do
      assert {:ok,
              %Member{
                name: "John",
                email: "john@email.com",
                age: 24,
                joined_on: ~D[2026-06-18]
              }} == Member.new(@valid_attrs)
    end

    test "age is optional: nil value parses to nil" do
      assert {:ok, %Member{age: nil}} = Member.new(attrs(%{"age" => nil}))
    end

    test "age is optional: empty string parses to nil" do
      assert {:ok, %Member{age: nil}} = Member.new(attrs(%{"age" => ""}))
    end

    test "age is optional: key missing entirely" do
      assert {:ok, %Member{age: nil}} = Member.new(Map.delete(@valid_attrs, "age"))
    end

    test "joined_on defaults to today when nil" do
      assert {:ok, %Member{joined_on: today}} = Member.new(attrs(%{"joined_on" => nil}))
      assert today == Date.utc_today()
    end

    test "joined_on defaults to today when key missing" do
      assert {:ok, %Member{joined_on: today}} = Member.new(Map.delete(@valid_attrs, "joined_on"))
      assert today == Date.utc_today()
    end

    test "accepts minimal email a@b" do
      assert {:ok, %Member{email: "a@b"}} = Member.new(attrs(%{"email" => "a@b"}))
    end

    test "age boundaries 0 and 150 are valid" do
      assert {:ok, %Member{age: 0}} = Member.new(attrs(%{"age" => "0"}))
      assert {:ok, %Member{age: 150}} = Member.new(attrs(%{"age" => "150"}))
    end

    test "name of exactly 100 chars is valid" do
      name = String.duplicate("a", 100)
      assert {:ok, %Member{name: ^name}} = Member.new(attrs(%{"name" => name}))
    end
  end

  describe "new/1 name validation" do
    test "missing name is an error map" do
      assert {:error, %{name: "is required"}} = Member.new(Map.delete(@valid_attrs, "name"))
    end

    test "blank name is rejected" do
      assert {:error, %{name: "can't be blank"}} = Member.new(attrs(%{"name" => "   "}))
    end

    test "name over 100 chars is rejected" do
      assert {:error, %{name: "must be at most 100 characters"}} =
               Member.new(attrs(%{"name" => String.duplicate("a", 101)}))
    end
  end

  describe "new/1 email validation" do
    test "missing email is an error map" do
      assert {:error, %{email: "is required"}} = Member.new(Map.delete(@valid_attrs, "email"))
    end

    test "rejects string with no @" do
      assert {:error, %{email: "is invalid"}} = Member.new(attrs(%{"email" => "invalid_email"}))
    end

    test "rejects @ with empty side" do
      assert {:error, %{email: "is invalid"}} = Member.new(attrs(%{"email" => "@b"}))
      assert {:error, %{email: "is invalid"}} = Member.new(attrs(%{"email" => "a@"}))
    end
  end

  describe "new/1 age validation" do
    test "rejects age too high" do
      assert {:error, %{age: "must be a positive integer between 0 and 150"}} =
               Member.new(attrs(%{"age" => "255"}))
    end

    test "rejects negative age" do
      assert {:error, %{age: "must be a positive integer between 0 and 150"}} =
               Member.new(attrs(%{"age" => "-18"}))
    end

    test "rejects non-numeric age" do
      assert {:error, %{age: "must be a positive integer between 0 and 150"}} =
               Member.new(attrs(%{"age" => "abc"}))
    end

    test "rejects trailing garbage after number" do
      assert {:error, %{age: "must be a positive integer between 0 and 150"}} =
               Member.new(attrs(%{"age" => "24x"}))
    end
  end

  describe "new/1 joined_on validation" do
    test "rejects malformed date" do
      assert {:error, %{joined_on: "must be yyyy-mm-dd string"}} =
               Member.new(attrs(%{"joined_on" => "2026a06d-18"}))
    end
  end

  describe "new/1 error accumulation" do
    test "accumulates all errors at once" do
      assert {:error, errors} =
               Member.new(%{
                 "name" => "",
                 "email" => "nope",
                 "age" => "999",
                 "joined_on" => "bad"
               })

      assert errors == %{
               name: "can't be blank",
               email: "is invalid",
               age: "must be a positive integer between 0 and 150",
               joined_on: "must be yyyy-mm-dd string"
             }
    end
  end

  describe "new/1 bad input" do
    test "non-map input returns invalid params" do
      assert {:error, "invalid params"} = Member.new(:not_a_map)
    end
  end
end

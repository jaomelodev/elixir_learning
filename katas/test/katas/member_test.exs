defmodule Katas.MemberTest do
  use ExUnit.Case
  doctest Katas.Member

  describe "Member struct tests" do
    test "should create new member with string map" do
      expected_member =
        {:ok,
         %Katas.Member{
           name: "John",
           email: "john@email.com",
           age: 24,
           joined_on: ~D[2026-06-18]
         }}

      result =
        Katas.Member.new(%{
          name: "John",
          email: "john@email.com",
          age: "24",
          joined_on: "2026-06-18"
        })

      assert result == expected_member
    end

    test "should default to today's day if member haven't provided a joined_on date" do
      expected_member =
        {:ok,
         %Katas.Member{
           name: "John",
           email: "john@email.com",
           age: 24,
           joined_on: Date.utc_today()
         }}

      result =
        Katas.Member.new(%{
          name: "John",
          email: "john@email.com",
          age: "24",
          joined_on: nil
        })

      assert result == expected_member
    end

    test "should not create member with missing name or email" do
      expected_result = {:error, "invalid params"}

      result =
        Katas.Member.new(%{
          name: nil,
          email: nil,
          age: "24",
          joined_on: "2026-06-18"
        })

      assert result == expected_result
    end

    test "should not create member with invalid email" do
      expected_result =
        {:error,
         %{
           email: "is invalid"
         }}

      result =
        Katas.Member.new(%{
          name: "John",
          email: "invalid_email",
          age: "24",
          joined_on: "2026-06-18"
        })

      assert result == expected_result
    end

    test "should not create member with invalid age" do
      expected_result =
        {:error,
         %{
           age: "must be a positive integer between 0 and 150"
         }}

      result_age_too_high =
        Katas.Member.new(%{
          name: "John",
          email: "john@email.com",
          age: "255",
          joined_on: "2026-06-18"
        })

      result_negative_age =
        Katas.Member.new(%{
          name: "John",
          email: "john@email.com",
          age: "-18",
          joined_on: "2026-06-18"
        })

      result_invalid_number =
        Katas.Member.new(%{
          name: "John",
          email: "john@email.com",
          age: "abc",
          joined_on: "2026-06-18"
        })

      assert result_age_too_high == expected_result
      assert result_negative_age == expected_result
      assert result_invalid_number == expected_result
    end

    test "should not create member with invalid date" do
      expected_result =
        {:error,
         %{
           joined_on: "must be yyyy-mm-dd string"
         }}

      result =
        Katas.Member.new(%{
          name: "John",
          email: "john@email.com",
          age: "24",
          joined_on: "2026a06d-18"
        })

      assert result == expected_result
    end
  end
end

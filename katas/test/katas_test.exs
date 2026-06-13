defmodule KatasTest do
  use ExUnit.Case
  doctest Katas

  test "greets the world" do
    assert Katas.hello() == :world
  end
end

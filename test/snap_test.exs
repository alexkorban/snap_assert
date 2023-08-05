defmodule SnapTest do
  use ExUnit.Case

  require Snap

  test "snap_assert" do
    Snap.snap_assert(String.upcase("hello"), "HELLO")

    hello = String.upcase("hello")
    Snap.snap_assert(hello, "HELLO")
  end

  test "snap_assert_raise" do
    Snap.snap_assert_raise(ArgumentError, fn -> raise ArgumentError end)
    Snap.snap_assert_raise(ArithmeticError, fn -> raise 1 / 0 end)
  end
end

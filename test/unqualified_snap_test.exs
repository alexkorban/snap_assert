defmodule UnqualifiedSnapTest do
  use ExUnit.Case

  import Snap

  test "snap_assert" do
    snap_assert String.upcase("hello"), "HELLO"

    hello = String.upcase("hello")
    snap_assert hello, "HELLO"
  end

  test "snap_assert_raise" do
    snap_assert_raise ArgumentError, fn -> raise ArgumentError end
    snap_assert_raise ArithmeticError, fn -> 1 / 0 end
  end
end

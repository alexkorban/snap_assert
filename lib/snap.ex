defmodule Snap do
  @moduledoc """
  Provides macros for instant snapshot testing, that is, macros that automatically amend
  the source code of the test file at their call site with the evaluated value of the expression
  under test.

  ## Usage

  1. Import `Snap` in your test file
  2. Use `snap_assert <some expression>` in one of the tests
  3. Run the tests with `mix test`
  4. Tests will pass and `snap_assert <some expression>` will turn into `snap_assert <some expression>, <expression value>`
  5. Run the tests again; `snap_assert` with two arguments will now be equivalent to a regular assert so tests will pass.

  More concrete example:

  - Add `snap_assert(String.upcase("hello"))` to a test
  - Run `mix test` (tests will pass)
  - The test file is now updated so that you have `snap_assert(String.upcase("hello"), "HELLO")`
  - Run `mix test` again - tests will pass
  - Change the expression to `snap_assert(String.upcase("hello"), "GOODBYE")`
  - Run `mix test` again - tests will fail, ie. now you have a regular assert.

  When working with `snap_assert`, it's useful to have the tests run on every change, for example with:

  ```
  fswatch lib test | mix test --listen-on-stdin --stale
  ```

  ## Why?

  I was inspired by this post by Ian Henry: https://ianthehenry.com/posts/my-kind-of-repl/

  At first, the idea of inserting the value of an expression into an assert seems tautological.
  However, consider how we often write functions: start with a draft implementation, try it out in the REPL,
  realise it's incomplete, make tweaks, try again, repeat until done. Then write unit tests, possibly
  by copy-pasting from the REPL.

  `snap_assert` moves some of that REPL into your test file. When you run tests which include a `snap_assert`,
  you'll see the results directly in your test file. If they are as expected - great, you now have a unit test
  for free. If not, delete the incorrect value, fix your function, run the tests again. Rinse and repeat.

  I was skeptical at first, but I've been trying this macro while working on a package, and it feels good.

  Of course, `snap_assert` isn't suitable for all tests: sometimes you want to check for a substring match, or a pattern match,
  or check that a message is received, and in those cases you still need to use regular ex_unit functionality.
  """

  defmodule UnexpectedLackOfException do
    @moduledoc false
    defexception message: "Expected exception but nothing was raised"
  end

  @doc """
  With two arguments, `snap_assert` is equivalent to a regular `assert`
  """
  defmacro snap_assert(arg1, arg2) do
    quote bind_quoted: [arg1: arg1, arg2: arg2] do
      assert arg1 == arg2
    end
  end

  @doc """
  Modifies the source code of the test file at the call site, adding the evaluated value of `arg` as the second argument.
  """
  defmacro snap_assert(arg) do
    # TODO: There is a problem with duplication in the generated code; seems to be no way to use
    # a private macro to deduplicate (as it has to generate code using variables from surrounding context).
    # Another possibility is to try generating macros like `snap_assert` with another macro.
    # Macro call line can be obtained via `__CALLER__.line`

    quote do
      result = unquote(arg)
      line = __ENV__.line
      path = __ENV__.file

      :global.set_lock({path, self()})
      source = File.read!(path)

      {_quoted, patches} =
        source
        |> Sourceror.parse_string!()
        |> Macro.postwalk([], fn
          {:snap_assert = macro_match, meta, [matched_arg]} = quoted_match, patches ->
            Snap.__patched__(quoted_match, patches, __ENV__.line, result, flip_args?: false)

          {{:., _, [{:__aliases__, _, [:Snap]}, :snap_assert]} = macro_match, meta, [matched_arg]} = quoted_match,
          patches ->
            Snap.__patched__(quoted_match, patches, __ENV__.line, result, flip_args?: false)

          quoted, patches ->
            {quoted, patches}
        end)

      output = Sourceror.patch_string(source, patches)

      File.write!(path, output, [:sync])
      :global.del_lock({path, self()})
    end
  end

  @doc """
  With two arguments, `snap_assert_raise` is equivalent to a regular `assert_raise`
  """
  defmacro snap_assert_raise(arg1, arg2) do
    quote bind_quoted: [arg1: arg1, arg2: arg2] do
      assert_raise arg1, arg2
    end
  end

  @doc """
  Modifies the source code of the test file at the call site, adding the exception produced by `fun`
  as the first argument (or `Snap.UnexpectedLackOfException` if no exception is produced).
  """
  defmacro snap_assert_raise(fun) do
    quote do
      result =
        try do
          apply(unquote(fun), [])
          raise UnexpectedLackOfException
        rescue
          error ->
            error.__struct__
        end

      line = __ENV__.line
      path = __ENV__.file

      :global.set_lock({path, self()})
      source = File.read!(path)

      {_quoted, patches} =
        source
        |> Sourceror.parse_string!()
        |> Macro.postwalk([], fn
          {:snap_assert_raise = macro_match, meta, [matched_arg]} = quoted_match, patches ->
            Snap.__patched__(quoted_match, patches, __ENV__.line, result, flip_args?: true)

          {{:., _, [{:__aliases__, _, [:Snap]}, :snap_assert_raise]} = macro_match, meta, [matched_arg]} = quoted_match,
          patches ->
            Snap.__patched__(quoted_match, patches, __ENV__.line, result, flip_args?: true)

          quoted, patches ->
            {quoted, patches}
        end)

      output = Sourceror.patch_string(source, patches)

      File.write!(path, output, [:sync])
      :global.del_lock({path, self()})
    end
  end

  # There appears to be no way to call from a macro another private macro which uses arguments
  # from the surrounding code, hence I have to rely on calling a public function (a private function
  # of course isn't an option either)
  def __patched__({macro_match, meta, [matched_arg]} = quoted, patches, line, result, flip_args?: flip_args?) do
    if Enum.member?(meta, {:line, line}) do
      range = Sourceror.get_range(quoted)

      replacement =
        {macro_match, meta, if(flip_args?, do: [result, matched_arg], else: [matched_arg, result])}
        |> Sourceror.to_string()

      patch = %{range: range, change: replacement}
      {quoted, [patch | patches]}
    else
      IO.puts("Line didn't match, no replacement generated")
      {quoted, patches}
    end
  end
end

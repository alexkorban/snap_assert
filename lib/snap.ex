defmodule Snap do
  @moduledoc """
  Provides macros for instant snapshot testing, that is, macros that automatically amend
  the source code of the test file at their call site with the evaluated value of the expression
  under test.
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

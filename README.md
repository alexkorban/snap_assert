# snap_assert

An experiment in self-modifying code, or, instant snapshot testing inside your unit tests.

The `snap_assert` macro inserts the result of evaluating its argument directly into your source code as its second argument.
`snap_assert` with two arguments is like a regular assert.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `snap_assert` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:snap_assert, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/snap_assert>.

## Usage 

1. Import `Snap` in your test file
2. Use `snap_assert <some expression>` in one of the tests
3. Run the tests with `mix test`
4. Tests will pass and `snap_assert <some expression>` will turn into `snap_assert <some expression>, <expression value>`
5. Run the tests again; `snap_assert` with two arguments will now be equivalent to a regular assert so tests will pass. 

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


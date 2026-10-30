// A model the DSL cannot print back.
//
// The printer writes `format=<value>` unquoted, so a value with a space
// cannot survive the round-trip. The verifier reports it instead of passing
// a model that cannot be reproduced.
//
// Run `node cli/index.js verify examples/Unprintable.dsl --json` to see the
// failure reported as a kind and a stage rather than as a sentence.

model T {
  x: Text [format="a b"]
}

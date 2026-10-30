// A conflict that no per-field check can see.
//
// `low`'s own constraint is fine: minimum 10, and any value of 10 or more
// satisfies it. `high`'s two constraints only contradict each other *because*
// `high` borrows `low`'s lower bound — after the cross-field reference is
// resolved, high must be at least 10 and at most 5 at the same time.
//
// A validator judges one value against one schema. It can only report "this
// value is out of range" once a value arrives. It has no way to ask whether
// the constraint system as a whole has a solution, because in JSON Schema,
// Zod and moon_zod a constraint is a constant attached to a single field:
// there is nowhere to put "a constraint that depends on another constraint".
//
// The projection writes the impossible range out without saying anything:
//
//   $ projdesk contrast examples/CrossFieldConflict.dsl
//
//   high (Int)
//     projection (moonmodel)  format: int32  maximum: 5  exclusiveMinimum: 10
//     solver (this project)   [CONFLICT] high: over(10) >= most(5): impossible
//
// The solver resolves the reference first and reports the contradiction.

model Pair {
  // the lower bound, on its own perfectly satisfiable
  low: Int [least=10]
  // borrows low's lower bound, which makes the two bounds contradict
  high: Int [over=low.least, most=5]
}

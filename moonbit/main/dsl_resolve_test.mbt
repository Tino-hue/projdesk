// Constraint resolution tests: cross-field references, cycles, and the state
// of the constraint system.

///|
test "resolve: a forward reference settles once the field is known" {
  let (models, _, errors) = @main.dsl_parse(
    "model T {\n  b: Int [over=a.least]\n  a: Int [least=5]\n}",
  )
  assert_eq(errors.length(), 0)
  match models[0].fields[0].checks[0] {
    @main.Over(b) => assert_eq(b.value, Some(5.0))
    _ => abort("expected Over")
  }
}

///|
test "resolve: a chain of references settles" {
  let (models, _, _) = @main.dsl_parse(
    "model T {\n  c: Int [least=b.least]\n  b: Int [least=a.least]\n  a: Int [least=7]\n}",
  )
  match models[0].fields[0].checks[0] {
    @main.Least(b) => assert_eq(b.value, Some(7.0))
    _ => abort("expected Least")
  }
}

///|
test "resolve: a reference cycle is reported once" {
  let (models, _, _) = @main.dsl_parse(
    "model T {\n  a: Int [least=b.least]\n  b: Int [least=a.least]\n}",
  )
  let issues = @main.check_semantics(models)
  assert_eq(issues.length(), 1)
  assert_true(issues[0].to_text().contains("cyclic dependency"))
}

///|
test "resolve: a self reference is a cycle" {
  let (models, _, _) = @main.dsl_parse("model T {\n  a: Int [least=a.least]\n}")
  let issues = @main.check_semantics(models)
  assert_eq(issues.length(), 1)
  assert_true(issues[0].to_text().contains("cyclic dependency"))
}

///|
test "resolve: a reference to a missing field is reported" {
  let (models, _, _) = @main.dsl_parse(
    "model T {\n  b: Int [over=nope.least]\n}",
  )
  let issues = @main.check_semantics(models)
  assert_eq(issues.length(), 1)
  assert_true(issues[0].to_text().contains("unknown field"))
}

///|
test "resolve: a reference to a missing constraint is reported" {
  let (models, _, _) = @main.dsl_parse(
    "model T {\n  a: Int [least=5]\n  b: Int [over=a.nosuch]\n}",
  )
  let issues = @main.check_semantics(models)
  assert_eq(issues.length(), 1)
  assert_true(issues[0].to_text().contains("unknown constraint"))
}

///|
test "resolve: an empty constraint range is reported" {
  let (models, _, _) = @main.dsl_parse(
    "model T {\n  x: Int [least=10, most=5]\n}",
  )
  let issues = @main.check_semantics(models)
  assert_eq(issues.length(), 1)
  assert_true(issues[0].to_text().contains("empty constraint range"))
}

///|
test "resolve: a satisfiable model reports nothing" {
  let (models, _, _) = @main.dsl_parse(
    "model T {\n  a: Int [least=5, most=100]\n  b: Int [over=a.least]\n}",
  )
  let issues = @main.check_semantics(models)
  assert_eq(issues.length(), 0)
}

///|
test "resolve: the field bounds carry the reference they came from" {
  let (models, _, _) = @main.dsl_parse(
    "model T {\n  a: Int [least=5]\n  b: Int [over=a.least]\n}",
  )
  let bounds = @main.model_field_bounds(models[0])
  assert_eq(bounds.length(), 2)
  assert_eq(bounds[0].least, Some({ value: Some(5.0), from_field: "", }))
  assert_eq(bounds[1].over, Some({ value: Some(5.0), from_field: "a", }))
}

///|
test "resolve: a source with an unsettled bound is not projected" {
  let (output, errors) = @main.dsl_project(
    "model T {\n  a: Int [least=b.least]\n  b: Int [least=a.least]\n}",
  )
  assert_true(errors.length() > 0)
  assert_true(output.contains("error"))
}

///|
test "resolve: a resolved reference reaches the projection" {
  let (output, errors) = @main.dsl_project(
    "model T {\n  b: Int [over=a.least]\n  a: Int [least=5]\n}",
  )
  assert_eq(errors.length(), 0)
  assert_true(output.contains("exclusiveMinimum"))
}

///|
test "resolve: a reference survives the printer" {
  let (models, _, _) = @main.dsl_parse(
    "model T {\n  a: Int [least=5]\n  b: Int [over=a.least]\n}",
  )
  let printed = @main.print_models(models)
  assert_true(printed.contains("over=a.least"))
}

///|
test "resolve: the printed reference parses back to the same value" {
  let (models, _, _) = @main.dsl_parse(
    "model T {\n  a: Int [least=5]\n  b: Int [over=a.least]\n}",
  )
  let printed = @main.print_models(models)
  let (reparsed, _, errors) = @main.dsl_parse(printed)
  assert_eq(errors.length(), 0)
  match reparsed[0].fields[1].checks[0] {
    @main.Over(b) => assert_eq(b.value, Some(5.0))
    _ => abort("expected Over")
  }
}

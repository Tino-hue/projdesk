// AST pretty-printer tests: AST -> DSL round-trip

test "printer: simple model prints back to DSL" {
  let (models, _, errors) = @main.dsl_parse(
    "model User {\n  id: Big\n  name: Text\n}",
  )
  assert_eq(errors.length(), 0)
  let printed = @main.print_model(models[0])
  assert_true(printed.contains("model User"))
  assert_true(printed.contains("id: Big"))
  assert_true(printed.contains("name: Text"))
}

test "printer: constraints are preserved" {
  let (models, _, errors) = @main.dsl_parse(
    "model T {\n  x: Text [longest=64, shortest=1]\n}",
  )
  assert_eq(errors.length(), 0)
  let printed = @main.print_model(models[0])
  assert_true(printed.contains("longest=64"))
  assert_true(printed.contains("shortest=1"))
}

test "printer: attributes are preserved" {
  let (models, _, errors) = @main.dsl_parse(
    "model T {\n  x: Big @unique\n  y: Text @optional\n  z: Text @nullable\n}",
  )
  assert_eq(errors.length(), 0)
  let printed = @main.print_model(models[0])
  assert_true(printed.contains("@unique"))
  assert_true(printed.contains("@optional"))
  assert_true(printed.contains("@nullable"))
}

test "printer: compound types are preserved" {
  let (models, _, errors) = @main.dsl_parse(
    "model T {\n  a: List(Text)\n  b: Dict(Int)\n  c: Ref(Address)\n}",
  )
  assert_eq(errors.length(), 0)
  let printed = @main.print_model(models[0])
  assert_true(printed.contains("List(Text)"))
  assert_true(printed.contains("Dict(Int)"))
  assert_true(printed.contains("Ref(Address)"))
}

test "printer: nested models are preserved" {
  let (models, _, errors) = @main.dsl_parse(
    "model T {\n  addr: Nest {\n    city: Text\n  }\n}",
  )
  assert_eq(errors.length(), 0)
  let printed = @main.print_model(models[0])
  assert_true(printed.contains("Nest"))
  assert_true(printed.contains("city: Text"))
}

test "printer: printed output re-parses to an equivalent model" {
  let src = "model User {\n  id: Big @unique\n  name: Text [longest=64]\n}"
  let (models, _, _) = @main.dsl_parse(src)
  let printed = @main.print_model(models[0])
  let (reparsed, _, errors) = @main.dsl_parse(printed)
  assert_eq(errors.length(), 0)
  assert_eq(reparsed.length(), 1)
  assert_eq(reparsed[0].name, "User")
  assert_eq(reparsed[0].fields.length(), 2)
  assert_eq(reparsed[0].fields[0].name, "id")
  assert_eq(reparsed[0].fields[1].name, "name")
  // the constraint must survive the round-trip
  assert_eq(reparsed[0].fields[1].checks.length(), 1)
}

test "printer: multiple models print together" {
  let (models, _, errors) = @main.dsl_parse(
    "model A {\n  x: Text\n}\n\nmodel B {\n  y: Int\n}",
  )
  assert_eq(errors.length(), 0)
  let printed = @main.print_models(models)
  assert_true(printed.contains("model A"))
  assert_true(printed.contains("model B"))
}

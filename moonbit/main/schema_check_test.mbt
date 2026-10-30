// Static satisfiability analysis of a JSON Schema.
//
// The point of these tests is the other half of the feature: a checker that
// cries wolf is worse than no checker, so the healthy schemas matter as much
// as the broken ones.

///|
test "schema: a range that no number satisfies is reported" {
  let out = @main.check_json_schema_str(
    "{\"type\":\"number\",\"minimum\":10,\"maximum\":5}",
  )
  assert_true(out.contains("empty_range"))
  assert_true(out.contains("\"ok\":false"))
}

///|
test "schema: an open bound that meets an inclusive one is reported" {
  // exclusiveMinimum 5 excludes 5, and maximum 5 allows it
  let out = @main.check_json_schema_str(
    "{\"type\":\"number\",\"exclusiveMinimum\":5,\"maximum\":5}",
  )
  assert_true(out.contains("empty_range"))
}

///|
test "schema: allOf branches that together leave nothing are reported" {
  // each branch on its own is fine; together they are impossible
  let out = @main.check_json_schema_str(
    "{\"allOf\":[{\"minimum\":0},{\"maximum\":-1}]}",
  )
  assert_true(out.contains("empty_range"))
  assert_true(out.contains("allOf"))
}

///|
test "schema: length bounds that no string satisfies are reported" {
  let out = @main.check_json_schema_str(
    "{\"type\":\"string\",\"minLength\":5,\"maxLength\":2}",
  )
  assert_true(out.contains("empty_length"))
}

///|
test "schema: an enum that no value of it satisfies is reported" {
  let out = @main.check_json_schema_str(
    "{\"type\":\"string\",\"enum\":[\"open\",\"closed\"],\"minLength\":10}",
  )
  assert_true(out.contains("empty_enum"))
}

///|
test "schema: an enum whose values do not match the declared type is reported" {
  let out = @main.check_json_schema_str(
    "{\"type\":\"integer\",\"enum\":[\"a\",\"b\"]}",
  )
  assert_true(out.contains("empty_enum"))
}

///|
test "schema: a reference into $defs is followed and its contradiction found" {
  let out = @main.check_json_schema_str(
    "{\"properties\":{\"a\":{\"$ref\":\"#/$defs/Bad\"}},\"$defs\":{\"Bad\":{\"minimum\":10,\"maximum\":5}}}",
  )
  assert_true(out.contains("empty_range"))
}

///|
test "schema: a reference that points at nothing is reported" {
  let out = @main.check_json_schema_str("{\"$ref\":\"#/$defs/Missing\"}")
  assert_true(out.contains("dangling_ref"))
}

///|
test "schema: a not over an impossible schema excludes everything" {
  let out = @main.check_json_schema_str(
    "{\"not\":{\"minimum\":10,\"maximum\":5}}",
  )
  assert_true(out.contains("empty_not"))
}

///|
test "schema: an anyOf where no branch works is reported" {
  let out = @main.check_json_schema_str(
    "{\"anyOf\":[{\"minimum\":10,\"maximum\":5},{\"minimum\":20,\"maximum\":1}]}",
  )
  assert_true(out.contains("no_live_branch"))
}

///|
test "schema: a multipleOf of zero is reported" {
  let out = @main.check_json_schema_str(
    "{\"type\":\"number\",\"multipleOf\":0}",
  )
  assert_true(out.contains("invalid_multiple_of"))
}

///|
test "schema: a contradiction inside a property is reported with its path" {
  let out = @main.check_json_schema_str(
    "{\"properties\":{\"reading\":{\"minimum\":10,\"maximum\":5}}}",
  )
  assert_true(out.contains("/properties/reading"))
}

///|
test "schema: a healthy schema reports nothing" {
  let out = @main.check_json_schema_str(
    "{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"integer\",\"minimum\":1},\"name\":{\"type\":\"string\",\"minLength\":1,\"maxLength\":64},\"status\":{\"type\":\"string\",\"enum\":[\"open\",\"closed\"]}},\"required\":[\"id\"]}",
  )
  assert_true(out.contains("\"ok\":true"))
  assert_true(out.contains("\"finding_count\":0"))
}

///|
test "schema: the JSON Schema a model projects to is itself healthy" {
  // the projections this kernel writes must not be caught by its own checker
  let dsl = "model User {\n  id: Big @unique\n  name: Text [shortest=1, longest=64]\n  age: Int @optional [least=0, under=150]\n}"
  let (projections, _errors) = @main.dsl_project(dsl)
  let json_schema = @jsonparse.parse_json(projections)
  let schema_text = match json_schema {
    Object(map) =>
      match map.get("jsonSchema") {
        Some(String(s)) => s
        _ => "{}"
      }
    _ => "{}"
  }
  let out = @main.check_json_schema_str(schema_text)
  assert_true(out.contains("\"ok\":true"))
}

///|
test "schema: a schema that is not JSON at all does not crash the checker" {
  let out = @main.check_json_schema_str("this is not json")
  assert_true(out.contains("\"ok\":true"))
}

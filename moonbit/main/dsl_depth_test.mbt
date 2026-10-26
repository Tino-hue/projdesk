// DSL depth tests: comments, nested models, error positions

// ---- Comment support ----

test "comment: line comment is lexed as Comment token" {
  let (tokens, errors) = lex("// hello\nmodel")
  assert_eq(errors.length(), 0)
  match tokens[0].token {
    Comment(s) => assert_eq(s, " hello")
    _ => abort("expected Comment token")
  }
}

test "comment: comments are skipped by parser" {
  let src = "// leading comment\nmodel T {\n  // field comment\n  x: Text\n}"
  let (models, _, errors) = dsl_parse(src)
  assert_eq(errors.length(), 0)
  assert_eq(models.length(), 1)
  assert_eq(models[0].fields.length(), 1)
}

test "comment: trailing comment on same line" {
  let src = "model T {\n  x: Text // the x field\n}"
  let (models, _, errors) = dsl_parse(src)
  assert_eq(errors.length(), 0)
  assert_eq(models[0].fields.length(), 1)
}

test "comment: comment-only line between fields" {
  let src = "model T {\n  a: Text\n  // divider\n  b: Int\n}"
  let (models, _, errors) = dsl_parse(src)
  assert_eq(errors.length(), 0)
  assert_eq(models[0].fields.length(), 2)
}

test "comment: empty comment" {
  let (tokens, errors) = lex("//\n")
  assert_eq(errors.length(), 0)
  match tokens[0].token {
    Comment(_) => ()
    _ => abort("expected Comment")
  }
}

test "comment: single slash is an error (not a comment)" {
  let (_, errors) = lex("a / b")
  assert_eq(errors.length() > 0, true)
}

// ---- Nested model support ----

test "nested: Nest { ... } parses into Nested type" {
  let src = "model T {\n  addr: Nest {\n    city: Text\n    zip: Int\n  }\n}"
  let (models, _, errors) = dsl_parse(src)
  assert_eq(errors.length(), 0)
  match models[0].fields[0].kind {
    Nested(m) => {
      assert_eq(m.fields.length(), 2)
      assert_eq(m.fields[0].name, "city")
    }
    _ => abort("expected Nested type")
  }
}

test "nested: nested model with constraints" {
  let src = "model T {\n  addr: Nest {\n    code: Text [longest=8]\n  }\n}"
  let (models, _, errors) = dsl_parse(src)
  assert_eq(errors.length(), 0)
  match models[0].fields[0].kind {
    Nested(m) => assert_eq(m.fields[0].checks.length(), 1)
    _ => abort("expected Nested")
  }
}

test "nested: List(Nest { ... }) works" {
  let src = "model T {\n  items: List(Nest {\n    v: Int\n  })\n}"
  let (models, _, errors) = dsl_parse(src)
  assert_eq(errors.length(), 0)
  match models[0].fields[0].kind {
    ListOf(_) => ()
    _ => abort("expected ListOf")
  }
}

test "nested: codegen maps Nested to moonmodel Nest" {
  let src = "model T {\n  addr: Nest {\n    city: Text\n  }\n}"
  let (models, _, _) = dsl_parse(src)
  let (primary, _) = dsl_to_models(models)
  match primary.fields[0].kind {
    @moonmodel.Nest(_) => ()
    _ => abort("expected moonmodel Nest")
  }
}

// ---- Error position precision ----

test "error: missing colon reports line and column" {
  let src = "model T {\n  name Text\n}"
  let (_, _, errors) = dsl_parse(src)
  assert_true(errors.length() > 0)
  assert_eq(errors[0].line, 2)
}

test "error: missing closing brace reports line" {
  let src = "model T {\n  x: Text\n"
  let (_, _, errors) = dsl_parse(src)
  assert_true(errors.length() > 0)
  assert_true(errors[0].line >= 2)
}

test "error: unknown constraint reports position" {
  let src = "model T {\n  x: Text [bogus=1]\n}"
  let (_, _, errors) = dsl_parse(src)
  assert_true(errors.length() > 0)
  assert_eq(errors[0].line, 2)
  assert_true(errors[0].msg.contains("bogus"))
}

test "error: error message includes expected token" {
  let src = "model T {\n  x Text\n}"
  let (_, _, errors) = dsl_parse(src)
  assert_true(errors.length() > 0)
  assert_true(errors[0].msg.contains("expected"))
}

test "error: to_text formats position" {
  let e : @main.ParseError = { msg: "boom", line: 3, col: 7 }
  let t = e.to_text()
  assert_true(t.contains("line 3:7"))
  assert_true(t.contains("boom"))
}

test "error: parser recovers and continues to next model" {
  let src = "model Bad {\n  : Text\n}\n\nmodel Good {\n  x: Text\n}"
  let (models, _, errors) = dsl_parse(src)
  assert_true(errors.length() > 0)
  // Should still find the second model
  assert_true(models.length() >= 1)
}

// ---- Combined features ----

test "combined: comments + nested + multiple models parse together" {
  let src =
    "// top comment\n" +
    "model User {\n" +
    "  // the identifier\n" +
    "  id: Big @unique\n" +
    "  addr: Nest {\n" +
    "    // city line\n" +
    "    city: Text\n" +
    "  }\n" +
    "}\n" +
    "\n" +
    "// another model\n" +
    "model Address {\n" +
    "  line: Text\n" +
    "}"
  let (models, _, errors) = dsl_parse(src)
  assert_eq(errors.length(), 0)
  assert_eq(models.length(), 2)
  assert_eq(models[0].name, "User")
  assert_eq(models[1].name, "Address")
}

test "combined: DSL with comments round-trips through projection" {
  let src =
    "// user model\n" +
    "model User {\n" +
    "  // unique id\n" +
    "  id: Big @unique\n" +
    "  // display name\n" +
    "  name: Text [longest=64]\n" +
    "}"
  let (output, errors) = dsl_project(src)
  assert_eq(errors.length(), 0)
  assert_true(output.contains("jsonSchema"))
  assert_true(output.contains("User"))
}

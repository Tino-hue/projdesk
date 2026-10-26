// DSL parser tests: lexer, parser, codegen, round-trip

// ---- Lexer tests ----

///|
test "lex: simple identifiers and keywords" {
  let (tokens, errors) = @main.lex("model User {")
  assert_eq(errors.length(), 0)
  assert_eq(tokens[0].token, KwModel)
  assert_eq(tokens[1].token, Ident("User"))
  assert_eq(tokens[2].token, LBrace)
  assert_eq(tokens[3].token, Eof)
}

///|
test "lex: numbers (integer and decimal)" {
  let (tokens, errors) = @main.lex("42 3.14")
  assert_eq(errors.length(), 0)
  assert_eq(tokens[0].token, Number(42.0))
  assert_eq(tokens[1].token, Number(3.14))
}

///|
test "lex: strings" {
  let (tokens, errors) = @main.lex("\"hello\" \"world\"")
  assert_eq(errors.length(), 0)
  assert_eq(tokens[0].token, Str("hello"))
  assert_eq(tokens[1].token, Str("world"))
}

///|
test "lex: symbols" {
  let (tokens, _) = @main.lex(": , [ ] { } ( ) @ =")
  assert_eq(tokens[0].token, Colon)
  assert_eq(tokens[1].token, Comma)
  assert_eq(tokens[2].token, LBracket)
  assert_eq(tokens[3].token, RBracket)
  assert_eq(tokens[4].token, LBrace)
  assert_eq(tokens[5].token, RBrace)
  assert_eq(tokens[6].token, LParen)
  assert_eq(tokens[7].token, RParen)
  assert_eq(tokens[8].token, At)
  assert_eq(tokens[9].token, Eq)
}

///|
test "lex: line tracking" {
  let (tokens, _) = @main.lex("a\nb\nc")
  assert_eq(tokens[0].line, 1)
  assert_eq(tokens[2].line, 2)
  assert_eq(tokens[4].line, 3)
}

///|
test "lex: unexpected character produces error" {
  let (_, errors) = @main.lex("a # b")
  assert_eq(errors.length(), 1)
}

///|
test "lex: unterminated string produces error" {
  let (_, errors) = @main.lex("\"unclosed")
  assert_eq(errors.length(), 1)
}

// ---- Parser tests ----

///|
test "parse: simple model with one field" {
  let (models, _, errors) = @main.dsl_parse("model User {\n  name: Text\n}")
  assert_eq(errors.length(), 0)
  assert_eq(models.length(), 1)
  assert_eq(models[0].name, "User")
  assert_eq(models[0].fields.length(), 1)
  assert_eq(models[0].fields[0].name, "name")
}

///|
test "parse: multiple fields" {
  let src = "model User {\n  id: Big\n  name: Text\n  age: Int\n}"
  let (models, _, errors) = @main.dsl_parse(src)
  assert_eq(errors.length(), 0)
  assert_eq(models[0].fields.length(), 3)
}

///|
test "parse: field with type List(Text)" {
  let (models, _, errors) = @main.dsl_parse("model T {\n  tags: List(Text)\n}")
  assert_eq(errors.length(), 0)
  match models[0].fields[0].kind {
    ListOf(_) => ()
    _ => abort("expected ListOf")
  }
}

///|
test "parse: field with type Ref(Address)" {
  let (models, _, errors) = @main.dsl_parse("model T {\n  home: Ref(Address)\n}")
  assert_eq(errors.length(), 0)
  match models[0].fields[0].kind {
    RefTo(s) => assert_eq(s, "Address")
    _ => abort("expected RefTo")
  }
}

///|
test "parse: field with @optional attribute" {
  let (models, _, errors) = @main.dsl_parse("model T {\n  name: Text @optional\n}")
  assert_eq(errors.length(), 0)
  assert_false(models[0].fields[0].required)
}

///|
test "parse: field with @nullable attribute" {
  let (models, _, errors) = @main.dsl_parse("model T {\n  name: Text @nullable\n}")
  assert_eq(errors.length(), 0)
  assert_true(models[0].fields[0].nullable)
}

///|
test "parse: field with checks" {
  let src = "model T {\n  name: Text [shortest=1, longest=64]\n}"
  let (models, _, errors) = @main.dsl_parse(src)
  assert_eq(errors.length(), 0)
  assert_eq(models[0].fields[0].checks.length(), 2)
}

///|
test "parse: field with @unique and checks" {
  let src = "model T {\n  id: Big @unique\n  name: Text [longest=64]\n}"
  let (models, _, errors) = @main.dsl_parse(src)
  assert_eq(errors.length(), 0)
  assert_eq(models[0].fields.length(), 2)
}

///|
test "parse: constraint values" {
  let src = "model T {\n  x: Real [least=0.0, most=100.0, over=-1.0, under=101.0, step=0.5]\n}"
  let (models, _, errors) = @main.dsl_parse(src)
  assert_eq(errors.length(), 0)
  assert_eq(models[0].fields[0].checks.length(), 5)
}

///|
test "parse: pattern and format" {
  let src = "model T {\n  e: Text [pattern=\"^a+$\", format=email]\n}"
  let (models, _, errors) = @main.dsl_parse(src)
  assert_eq(errors.length(), 0)
  assert_eq(models[0].fields[0].checks.length(), 2)
}

///|
test "parse: options constraint" {
  let src = "model T {\n  s: Text [options=[free, paid, staff]]\n}"
  let (models, _, errors) = @main.dsl_parse(src)
  assert_eq(errors.length(), 0)
  match models[0].fields[0].checks[0] {
    Options(vals) => assert_eq(vals.length(), 3)
    _ => abort("expected Options")
  }
}

///|
test "parse: multiple models" {
  let src = "model User {\n  id: Big\n}\n\nmodel Address {\n  line: Text\n}"
  let (models, _, errors) = @main.dsl_parse(src)
  assert_eq(errors.length(), 0)
  assert_eq(models.length(), 2)
  assert_eq(models[0].name, "User")
  assert_eq(models[1].name, "Address")
}

///|
test "parse: missing closing brace produces error" {
  let (_, _, errors) = @main.dsl_parse("model T {\n  x: Text\n")
  assert_true(errors.length() > 0)
}

///|
test "parse: invalid field syntax produces error" {
  let (_, _, errors) = @main.dsl_parse("model T {\n  : Text\n}")
  assert_true(errors.length() > 0)
}

// ---- Codegen tests ----

///|
test "codegen: simple model maps to moonmodel" {
  let (models, _, _) = @main.dsl_parse(
    "model User {\n  id: Big @unique\n  name: Text [longest=64]\n}",
  )
  let (primary, known) = @main.dsl_to_models(models)
  assert_eq(primary.name, "User")
  assert_eq(primary.fields.length(), 2)
  assert_eq(known.length(), 0)
}

///|
test "codegen: type mapping is correct" {
  let (models, _, _) = @main.dsl_parse(
    "model T {\n  a: Bool\n  b: Int\n  c: Big\n  d: Real\n  e: Text\n  f: Bytes\n  g: Stamp\n  h: Any\n}",
  )
  let (primary, _) = @main.dsl_to_models(models)
  assert_eq(primary.fields[0].kind, Bool)
  assert_eq(primary.fields[1].kind, Int)
  assert_eq(primary.fields[2].kind, Big)
  assert_eq(primary.fields[3].kind, Real)
  assert_eq(primary.fields[4].kind, Text)
  assert_eq(primary.fields[5].kind, Bytes)
  assert_eq(primary.fields[6].kind, Stamp)
  assert_eq(primary.fields[7].kind, Any)
}

///|
test "codegen: checks map correctly" {
  let (models, _, _) = @main.dsl_parse(
    "model T {\n  x: Text [shortest=1, longest=64, pattern=\"^a\", format=email]\n}",
  )
  let (primary, _) = @main.dsl_to_models(models)
  let c = primary.fields[0].check
  assert_eq(c.shortest, Some(1))
  assert_eq(c.longest, Some(64))
  assert_eq(c.pattern, Some("^a"))
  assert_eq(c.format, Some("email"))
}

///|
test "codegen: unique and distinct map correctly" {
  let (models, _, _) = @main.dsl_parse(
    "model T {\n  id: Big @unique\n  tags: List(Text) @optional\n}",
  )
  let (primary, _) = @main.dsl_to_models(models)
  assert_true(primary.fields[0].check.unique)
}

///|
test "codegen: multiple models split into primary and known" {
  let (models, _, _) = @main.dsl_parse(
    "model User {\n  home: Ref(Address)\n}\n\nmodel Address {\n  line: Text\n}",
  )
  let (primary, known) = @main.dsl_to_models(models)
  assert_eq(primary.name, "User")
  assert_eq(known.length(), 1)
  assert_eq(known[0].name, "Address")
}

// ---- Full pipeline test ----

///|
test "dsl_project: returns valid output for simple model" {
  let src = "model User {\n  id: Big @unique\n  name: Text [longest=64]\n}"
  let (output, errors) = @main.dsl_project(src)
  assert_eq(errors.length(), 0)
  assert_true(output.length() > 0)
  assert_true(output.contains("jsonSchema"))
  assert_true(output.contains("sql"))
}

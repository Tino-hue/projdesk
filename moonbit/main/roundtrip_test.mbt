// Round-trip verification tests
//
// The point of these is that a lost constraint must fail the round-trip.
// The previous verifier compared only field names and four flags, so a model
// that lost every constraint was reported as sound.

///|
test "roundtrip: simple model survives round-trip" {
  let m = @moonmodel.Model::new("User", [
    @moonmodel.Field::new("id", Big, check=@moonmodel.Check::new(unique=true)),
    @moonmodel.Field::new("name", Text, check=@moonmodel.Check::new(longest=64)),
  ])
  match @main.roundtrip_model(m, []) {
    Pass => ()
    Fail(msg) => abort("roundtrip failed: " + msg)
  }
}

///|
test "roundtrip: all simple types survive" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Bool),
    @moonmodel.Field::new("b", Int),
    @moonmodel.Field::new("c", Big),
    @moonmodel.Field::new("d", Real),
    @moonmodel.Field::new("e", Text),
    @moonmodel.Field::new("f", Bytes),
    @moonmodel.Field::new("g", Stamp),
    @moonmodel.Field::new("h", Any),
  ])
  match @main.roundtrip_model(m, []) {
    Pass => ()
    Fail(msg) => abort("roundtrip failed: " + msg)
  }
}

///|
test "roundtrip: List and Dict survive" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("tags", List(Text)),
    @moonmodel.Field::new("meta", Dict(Int)),
  ])
  match @main.roundtrip_model(m, []) {
    Pass => ()
    Fail(msg) => abort("roundtrip failed: " + msg)
  }
}

///|
test "roundtrip: Ref survives" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("home", Ref("Address")),
  ])
  match @main.roundtrip_model(m, []) {
    Pass => ()
    Fail(msg) => abort("roundtrip failed: " + msg)
  }
}

///|
test "roundtrip: optional and nullable flags survive" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text, required=false),
    @moonmodel.Field::new("b", Text, nullable=true),
    @moonmodel.Field::new("c", Text, required=false, nullable=true),
    @moonmodel.Field::new("d", Text, required=true, nullable=false),
  ])
  match @main.roundtrip_model(m, []) {
    Pass => ()
    Fail(msg) => abort("roundtrip failed: " + msg)
  }
}

///|
test "roundtrip: constraints survive" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new(
      "x",
      Text,
      check=@moonmodel.Check::new(shortest=1, longest=64),
    ),
    @moonmodel.Field::new(
      "y",
      Real,
      check=@moonmodel.Check::new(least=0.0, most=100.0),
    ),
    @moonmodel.Field::new(
      "z",
      List(Text),
      check=@moonmodel.Check::new(distinct=true),
    ),
    @moonmodel.Field::new("w", Big, check=@moonmodel.Check::new(unique=true)),
  ])
  match @main.roundtrip_model(m, []) {
    Pass => ()
    Fail(msg) => abort("roundtrip failed: " + msg)
  }
}

///|
test "roundtrip: exclusive bounds and step survive" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new(
      "x",
      Int,
      check=@moonmodel.Check::new(over=0.0, under=101.0, step=0.5),
    ),
  ])
  match @main.roundtrip_model(m, []) {
    Pass => ()
    Fail(msg) => abort("roundtrip failed: " + msg)
  }
}

///|
test "roundtrip: pattern, format and options survive" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new(
      "code",
      Text,
      check=@moonmodel.Check::new(pattern="^[a-z]+$"),
    ),
    @moonmodel.Field::new(
      "mail",
      Text,
      check=@moonmodel.Check::new(format="email"),
    ),
    @moonmodel.Field::new(
      "status",
      Text,
      check=@moonmodel.Check::new(options=[
        Json::string("open"),
        Json::string("closed"),
      ]),
    ),
  ])
  match @main.roundtrip_model(m, []) {
    Pass => ()
    Fail(msg) => abort("roundtrip failed: " + msg)
  }
}

///|
test "roundtrip: a nested model keeps its inner fields" {
  let inner = @moonmodel.Model::new("", [
    @moonmodel.Field::new(
      "city",
      Text,
      check=@moonmodel.Check::new(shortest=1, longest=64),
    ),
  ])
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("addr", Nest(inner)),
  ])
  match @main.roundtrip_model(m, []) {
    Pass => ()
    Fail(msg) => abort("roundtrip failed: " + msg)
  }
}

///|
test "roundtrip: a known model travels with the primary one" {
  let address = @moonmodel.Model::new("Address", [
    @moonmodel.Field::new("line", Text),
  ])
  let m = @moonmodel.Model::new("User", [
    @moonmodel.Field::new("home", Ref("Address")),
  ])
  match @main.roundtrip_model(m, [address]) {
    Pass => ()
    Fail(msg) => abort("roundtrip failed: " + msg)
  }
}

///|
test "roundtrip: a raw type is reported instead of silently degraded" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("blob", Raw("{\"any\": 1}")),
  ])
  match @main.roundtrip_model(m, []) {
    Pass => abort("expected a raw type to fail the round-trip")
    Fail(msg) => assert_true(msg.contains("raw type"))
  }
}

///|
test "roundtrip: DSL string round-trips" {
  let dsl = "model User {\n  id: Big @unique\n  name: Text [longest=64]\n}"
  match @main.roundtrip_dsl(dsl) {
    Pass => ()
    Fail(msg) => abort("DSL roundtrip failed: " + msg)
  }
}

///|
test "roundtrip: a DSL source with every construct round-trips" {
  let dsl = "model User {\n  id: Big @unique\n  name: Text [shortest=1, longest=64]\n  email: Text [format=email]\n  age: Int @optional [least=0, under=150]\n  tags: List(Text) @optional @distinct\n  home: Ref(Address)\n  addr: Nest {\n    city: Text\n  }\n}\n\nmodel Address {\n  line: Text\n}"
  match @main.roundtrip_dsl(dsl) {
    Pass => ()
    Fail(msg) => abort("DSL roundtrip failed: " + msg)
  }
}

///|
test "roundtrip: a format value the DSL cannot print is reported" {
  // The printer writes `format=<value>` unquoted, so a value with a space
  // cannot survive. The round-trip has to say so rather than pass.
  let dsl = "model T {\n  x: Text [format=\"a b\"]\n}"
  match @main.roundtrip_dsl(dsl) {
    Pass => abort("expected an unprintable format to fail the round-trip")
    Fail(_) => ()
  }
}

///|
test "roundtrip: the comparison detects a lost constraint" {
  let (a, _, _) = @main.dsl_parse("model T {\n  x: Int [least=5]\n}")
  let (b, _, _) = @main.dsl_parse("model T {\n  x: Int [least=9]\n}")
  let d = @main.ast_difference(a[0], b[0])
  assert_true(d.contains("least"))
}

///|
test "roundtrip: the comparison detects a changed type" {
  let (a, _, _) = @main.dsl_parse("model T {\n  x: Int\n}")
  let (b, _, _) = @main.dsl_parse("model T {\n  x: Text\n}")
  let d = @main.ast_difference(a[0], b[0])
  assert_true(d.contains("type changed"))
}

///|
test "roundtrip: the comparison detects a lost field" {
  let (a, _, _) = @main.dsl_parse("model T {\n  x: Int\n  y: Int\n}")
  let (b, _, _) = @main.dsl_parse("model T {\n  x: Int\n}")
  let d = @main.ast_difference(a[0], b[0])
  assert_true(d.contains("field count"))
}

///|
test "roundtrip: the comparison sees no difference for identical models" {
  let src = "model T {\n  x: Int [least=5]\n  y: Text @optional\n}"
  let (a, _, _) = @main.dsl_parse(src)
  let (b, _, _) = @main.dsl_parse(src)
  assert_eq(@main.ast_difference(a[0], b[0]), "")
}

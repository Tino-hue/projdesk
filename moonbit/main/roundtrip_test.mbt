// Round-trip tests

///|
test "roundtrip: simple model survives round-trip" {
  let m = @moonmodel.Model::new("User", [
    @moonmodel.Field::new("id", Big, check=@moonmodel.Check::new(unique=true)),
    @moonmodel.Field::new("name", Text, check=@moonmodel.Check::new(longest=64)),
  ])
  match @main.roundtrip_model(m) {
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
  match @main.roundtrip_model(m) {
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
  match @main.roundtrip_model(m) {
    Pass => ()
    Fail(msg) => abort("roundtrip failed: " + msg)
  }
}

///|
test "roundtrip: Ref survives" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("home", Ref("Address")),
  ])
  match @main.roundtrip_model(m) {
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
  match @main.roundtrip_model(m) {
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
  match @main.roundtrip_model(m) {
    Pass => ()
    Fail(msg) => abort("roundtrip failed: " + msg)
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
test "roundtrip: run_roundtrips returns JSON" {
  let m1 = @moonmodel.Model::new("A", [@moonmodel.Field::new("x", Text)])
  let m2 = @moonmodel.Model::new("B", [@moonmodel.Field::new("y", Int)])
  let json = @main.run_roundtrips([m1, m2])
  assert_true(json.contains("results"))
  assert_true(json.contains("passed"))
  assert_true(json.contains("total"))
}

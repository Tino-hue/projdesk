// Semantic equivalence tests

test "equiv: identical models are equivalent" {
  let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("a", Text)])
  assert_eq(model_equiv(m, m), Equivalent)
}

test "equiv: name mismatch is incompatible" {
  let a = @moonmodel.Model::new("A", [@moonmodel.Field::new("x", Text)])
  let b = @moonmodel.Model::new("B", [@moonmodel.Field::new("x", Text)])
  match model_equiv(a, b) {
    Incompatible(_) => ()
    _ => abort("expected Incompatible")
  }
}

test "equiv: missing field is incompatible" {
  let a = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text),
    @moonmodel.Field::new("y", Text),
  ])
  let b = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", Text)])
  match model_equiv(a, b) {
    Incompatible(_) => ()
    _ => abort("expected Incompatible")
  }
}

test "equiv: Int widens to Big" {
  let a = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", Int)])
  let b = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", Big)])
  match model_equiv(a, b) {
    SubtypeOf(_) => ()
    _ => abort("expected SubtypeOf")
  }
}

test "equiv: Big narrows to Int is not safe" {
  let a = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", Big)])
  let b = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", Int)])
  match model_equiv(a, b) {
    SupertypeOf(_) => ()
    _ => abort("expected SupertypeOf")
  }
}

test "equiv: stricter constraints are subtype" {
  let a = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, check=@moonmodel.Check::new(longest=10)),
  ])
  let b = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, check=@moonmodel.Check::new(longest=100)),
  ])
  match model_equiv(a, b) {
    SubtypeOf(_) => ()
    _ => abort("expected SubtypeOf")
  }
}

test "equiv: required is stricter than optional" {
  let a = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", Text, required=true)])
  let b = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", Text, required=false)])
  match model_equiv(a, b) {
    SubtypeOf(_) => ()
    _ => abort("expected SubtypeOf")
  }
}

test "equiv: nullable is looser than non-null" {
  let a = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", Text, nullable=true)])
  let b = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", Text, nullable=false)])
  match model_equiv(a, b) {
    SupertypeOf(_) => ()
    _ => abort("expected SupertypeOf")
  }
}

test "equiv: options subset is subtype" {
  let a = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, check=@moonmodel.Check::new(options=[Json::string("a")])),
  ])
  let b = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, check=@moonmodel.Check::new(options=[Json::string("a"), Json::string("b")])),
  ])
  match model_equiv(a, b) {
    SubtypeOf(_) => ()
    _ => abort("expected SubtypeOf")
  }
}

test "equiv: mixed subtyping is incompatible" {
  let a = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, required=true),
    @moonmodel.Field::new("y", Text, required=false),
  ])
  let b = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, required=false),
    @moonmodel.Field::new("y", Text, required=true),
  ])
  match model_equiv(a, b) {
    Incompatible(_) => ()
    _ => abort("expected Incompatible")
  }
}

test "equiv: check_equivalence returns JSON" {
  let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", Text)])
  let json = check_equivalence(m, m)
  assert_true(json.contains("equivalent"))
  assert_true(json.contains("true"))
}

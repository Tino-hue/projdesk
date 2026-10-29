// Independence tests: what the engines find that projection does not.
//
// The proposal has to answer one objection: "the model semantics and the
// projections already exist in moonmodel". These tests show the difference on
// the same model, from both directions:
//
//   - the projection carries a contradiction through and says nothing about it
//   - the solver reports it
//
// The projection side is moonmodel's own JSON Schema writer, so the contrast
// is measured against the library the engines are compared to, not against a
// description of it.

///|
/// The JSON Schema projection of a model, as moonmodel writes it
fn projection_text(m : @moonmodel.Model) -> String {
  @json.document(m).stringify(indent=2)
}

///|
/// A model whose numeric bounds contradict each other about half the time
fn random_bounded_model(rng : @main.Rng) -> @moonmodel.Model {
  let least = rng.next_int(100).to_double()
  let most = if rng.next_bool() {
    // below the lower bound: the range is empty
    least - rng.next_int(50).to_double() - 1.0
  } else {
    least + rng.next_int(50).to_double() + 1.0
  }
  let name = "M" + rng.next_int(1000).to_string()
  @moonmodel.Model::new(name, [
    @moonmodel.Field::new("x", Int, check=@moonmodel.Check::new(least~, most~)),
  ])
}

///|
test "independence: the projection carries an empty range through silently" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new(
      "x",
      Int,
      check=@moonmodel.Check::new(least=10.0, most=5.0),
    ),
  ])
  // moonmodel writes both bounds and has nothing to say about them
  let schema = projection_text(m)
  assert_true(schema.contains("minimum"))
  assert_true(schema.contains("maximum"))
  assert_false(schema.contains("error"))
}

///|
test "independence: the solver reports the empty range" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new(
      "x",
      Int,
      check=@moonmodel.Check::new(least=10.0, most=5.0),
    ),
  ])
  let diags = @main.analyze_model(m)
  assert_true(diags.length() > 0)
  assert_true(diags.any(fn(d) { d.severity() == "error" }))
  assert_true(diags.any(fn(d) { d.to_text().contains("empty range") }))
}

///|
test "independence: every conflict the solver finds is silent in the projection" {
  let rng = @main.new_rng(20261028L)
  let mut reported = 0
  for i = 0; i < 100; i = i + 1 {
    let m = random_bounded_model(rng)
    let diags = @main.analyze_model(m)
    let has_error = diags.any(fn(d) { d.severity() == "error" })
    if has_error {
      reported += 1
      // the projection still emits a schema, with the contradictory bounds
      // carried straight through
      let schema = projection_text(m)
      assert_true(schema.contains("minimum"))
      assert_true(schema.contains("maximum"))
    }
  }
  // the generator is built to conflict about half the time
  assert_true(reported > 20)
}

///|
test "independence: a closed set that breaks the length bound is reported" {
  let opts : Array[Json] = [Json::string("toolong")]
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new(
      "code",
      Text,
      check=@moonmodel.Check::new(longest=3, options=opts),
    ),
  ])
  // the projection cannot express the contradiction, so it keeps both
  let schema = projection_text(m)
  assert_true(schema.contains("maxLength"))
  assert_true(schema.contains("toolong"))
  // the solver sees it
  let diags = @main.analyze_model(m)
  assert_true(diags.any(fn(d) { d.to_text().contains("exceeds longest") }))
}

///|
test "independence: a redundant bound is reported" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new(
      "x",
      Int,
      check=@moonmodel.Check::new(least=0.0, over=0.0),
    ),
  ])
  // the projection writes both, which is harmless but says nothing
  let schema = projection_text(m)
  assert_true(schema.contains("minimum"))
  assert_true(schema.contains("exclusiveMinimum"))
  // the solver calls it redundant
  let diags = @main.analyze_model(m)
  assert_true(diags.any(fn(d) { d.to_text().contains("subsumed") }))
}

///|
test "independence: the DSL resolves a bound the model format cannot express" {
  // `b` takes its lower bound from `a`. The model format has no way to say
  // that, so the reference exists only in the DSL and has to be resolved
  // before anything else can be done with the model.
  let (models, _, errors) = @main.dsl_parse(
    "model T {\n  a: Int [least=5]\n  b: Int [over=a.least]\n}",
  )
  assert_eq(errors.length(), 0)
  let (model, _) = @main.dsl_to_models(models)
  let b = model.fields[1]
  match b.check.over {
    Some(v) => assert_eq(v, 5.0)
    None => abort("expected the reference to resolve")
  }
}

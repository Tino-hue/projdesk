// Performance benchmarks for the engine pipeline
// Establishes measurable upper bounds on model size

///|
/// Time a projection of a model with N fields
fn bench_projection(field_count : Int) -> (Double, Int) {
  let fields : Array[@moonmodel.Field] = []
  for i = 0; i < field_count; i = i + 1 {
    fields.push(
      @moonmodel.Field::new(
        "field_" + i.to_string(),
        Text,
        check=@moonmodel.Check::new(shortest=1, longest=64),
      ),
    )
  }
  let m = @moonmodel.Model::new("Bench", fields)
  let start = @bench.monotonic_clock_start()
  let result = @main.project_all(m, [])
  let elapsed = @bench.monotonic_clock_end(start)
  let _ = result.json_schema.length()
  (elapsed, field_count)
}

///|
/// Build a model with N simple fields
fn make_fields(n : Int) -> Array[@moonmodel.Field] {
  let fields : Array[@moonmodel.Field] = []
  for i = 0; i < n; i = i + 1 {
    fields.push(
      @moonmodel.Field::new(
        "field_" + i.to_string(),
        Text,
        check=@moonmodel.Check::new(shortest=1, longest=64),
      ),
    )
  }
  fields
}

test "bench: projection of 100 fields completes within budget" {
  let (elapsed, count) = bench_projection(100)
  assert_eq(count, 100)
  assert_true(elapsed < 2000.0, msg="100-field projection took " + elapsed.to_string() + "ms")
}

test "bench: projection of 200 fields completes within budget" {
  let (elapsed, count) = bench_projection(200)
  assert_eq(count, 200)
  assert_true(elapsed < 5000.0, msg="200-field projection took " + elapsed.to_string() + "ms")
}

test "bench: constraint solving on 100 fields within budget" {
  let fields : Array[@moonmodel.Field] = []
  for i = 0; i < 100; i = i + 1 {
    fields.push(
      @moonmodel.Field::new(
        "f" + i.to_string(),
        Real,
        check=@moonmodel.Check::new(least=0.0, most=100.0),
      ),
    )
  }
  let m = @moonmodel.Model::new("Big", fields)
  let start = @bench.monotonic_clock_start()
  let diags = @main.analyze_model(m)
  let elapsed = @bench.monotonic_clock_end(start)
  // Valid constraints produce no diagnoses (only conflicts/redundancies/warnings)
  assert_eq(diags.length(), 0)
  assert_true(elapsed < 1000.0, msg="solving 100 fields took " + elapsed.to_string() + "ms")
}

test "bench: DSL parsing of 100-field source within budget" {
  let src : Ref[String] = { val: "model Big {\n" }
  for i = 0; i < 100; i = i + 1 {
    src.val = src.val + "  field_" + i.to_string() + ": Text [longest=64]\n"
  }
  src.val = src.val + "}"
  let start = @bench.monotonic_clock_start()
  let (models, _, errors) = @main.dsl_parse(src.val)
  let elapsed = @bench.monotonic_clock_end(start)
  assert_eq(errors.length(), 0)
  assert_eq(models.length(), 1)
  assert_eq(models[0].fields.length(), 100)
  assert_true(elapsed < 1000.0, msg="parsing 100-field DSL took " + elapsed.to_string() + "ms")
}

test "bench: diff on 100-field models within budget" {
  // Build two independent field lists
  let old_fields : Array[@moonmodel.Field] = []
  let new_fields : Array[@moonmodel.Field] = []
  for i = 0; i < 100; i = i + 1 {
    old_fields.push(@moonmodel.Field::new("field_" + i.to_string(), Text))
    if i == 99 {
      new_fields.push(@moonmodel.Field::new("field_99", Big))
    } else {
      new_fields.push(@moonmodel.Field::new("field_" + i.to_string(), Text))
    }
  }
  let old = @moonmodel.Model::new("Big", old_fields)
  let new = @moonmodel.Model::new("Big", new_fields)
  let start = @bench.monotonic_clock_start()
  let report = @main.diff_models(old, new)
  let elapsed = @bench.monotonic_clock_end(start)
  assert_eq(report.changes.length(), 1)
  assert_true(elapsed < 1000.0, msg="diff took " + elapsed.to_string() + "ms")
}

test "bench: round-trip on 50-field model within budget" {
  let m = @moonmodel.Model::new("RT", make_fields(50))
  let start = @bench.monotonic_clock_start()
  let result = @main.roundtrip_model(m)
  let elapsed = @bench.monotonic_clock_end(start)
  match result {
    Pass => ()
    Fail(msg) => abort("round-trip failed: " + msg)
  }
  assert_true(elapsed < 2000.0, msg="round-trip took " + elapsed.to_string() + "ms")
}

test "bench: equivalence check on 100-field models within budget" {
  let fields = make_fields(100)
  let a = @moonmodel.Model::new("Big", fields)
  let b = @moonmodel.Model::new("Big", fields)
  let start = @bench.monotonic_clock_start()
  let result = @main.model_equiv(a, b)
  let elapsed = @bench.monotonic_clock_end(start)
  assert_eq(result, @main.Equivalent)
  assert_true(elapsed < 1000.0, msg="equivalence took " + elapsed.to_string() + "ms")
}

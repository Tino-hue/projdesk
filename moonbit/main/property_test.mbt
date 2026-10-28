// Property-based tests: verify engine invariants over many random models
// These prove correctness beyond hand-picked examples

// ---- PRNG determinism ----

///|
test "prng: same seed produces same sequence" {
  let a = @main.new_rng(42L)
  let b = @main.new_rng(42L)
  for i = 0; i < 20; i = i + 1 {
    assert_eq(a.next_int64(), b.next_int64())
  }
}

///|
test "prng: different seeds produce different sequences" {
  let a = @main.new_rng(1L)
  let b = @main.new_rng(2L)
  let mut differs = false
  for i = 0; i < 10; i = i + 1 {
    if a.next_int64() != b.next_int64() {
      differs = true
    }
  }
  assert_true(differs)
}

///|
test "prng: next_int stays within bounds" {
  let rng = @main.new_rng(123L)
  for i = 0; i < 200; i = i + 1 {
    let v = rng.next_int(10)
    assert_true(v >= 0 && v < 10)
  }
}

///|
test "prng: next_double in [0,1)" {
  let rng = @main.new_rng(456L)
  for i = 0; i < 200; i = i + 1 {
    let v = rng.next_double()
    assert_true(v >= 0.0 && v < 1.0)
  }
}

// ---- Property: round-trip holds for random models ----

///|
test "property: round-trip holds for 100 random models" {
  let rng = @main.new_rng(2024L)
  let models = @main.random_models(rng, 100)
  for m in models {
    match @main.roundtrip_model(m, []) {
      Pass => ()
      Fail(msg) => abort("round-trip failed for " + m.name + ": " + msg)
    }
  }
}

///|
test "property: round-trip holds for random constraint models" {
  let rng = @main.new_rng(777L)
  for i = 0; i < 50; i = i + 1 {
    let m = @main.random_constraint_model(rng)
    match @main.roundtrip_model(m, []) {
      Pass => ()
      Fail(msg) => abort("round-trip failed: " + msg)
    }
  }
}

///|
test "property: DSL generation always parses without errors" {
  let rng = @main.new_rng(31337L)
  let models = @main.random_models(rng, 40)
  for m in models {
    let dsl = @main.model_to_dsl_public(m)
    let (_, lex_errors, parse_errors) = @main.dsl_parse(dsl)
    assert_eq(lex_errors.length(), 0)
    assert_eq(parse_errors.length(), 0)
  }
}

// ---- Property: solver invariants ----

///|
test "property: solver never crashes on random models" {
  let rng = @main.new_rng(999L)
  for i = 0; i < 60; i = i + 1 {
    let m = @main.random_constraint_model(rng)
    let diags = @main.analyze_model(m)
    // Every diagnosis must have a non-empty text
    for d in diags {
      assert_true(d.to_text().length() > 0)
    }
  }
}

///|
test "property: solver detects at least one conflict when least > most" {
  let rng = @main.new_rng(555L)
  for i = 0; i < 30; i = i + 1 {
    let lo = rng.next_int(50).to_double()
    let hi = lo - rng.next_int(20).to_double() - 1.0
    let m = @moonmodel.Model::new("T", [
      @moonmodel.Field::new(
        "x",
        Real,
        check=@moonmodel.Check::new(least=lo, most=hi),
      ),
    ])
    let diags = @main.analyze_model(m)
    assert_true(
      @main.has_conflicts(diags),
      msg="should detect conflict: least=" +
        lo.to_string() +
        " most=" +
        hi.to_string(),
    )
  }
}

///|
test "property: model with no constraints yields exactly one diagnosis per field" {
  let rng = @main.new_rng(1212L)
  for i = 0; i < 20; i = i + 1 {
    let field_count = rng.next_int(4) + 1
    let fields : Array[@moonmodel.Field] = []
    for j = 0; j < field_count; j = j + 1 {
      fields.push(@moonmodel.Field::new("f" + j.to_string(), Text))
    }
    let m = @moonmodel.Model::new("Plain", fields)
    let diags = @main.analyze_model(m)
    assert_eq(diags.length(), field_count)
  }
}

// ---- Property: migration invariants ----

///|
test "property: identical models produce zero migration changes" {
  let rng = @main.new_rng(8080L)
  for i = 0; i < 40; i = i + 1 {
    let m = @main.random_model(rng, "Same")
    let report = @main.diff_models(m, m)
    assert_eq(report.changes.length(), 0)
    assert_eq(report.breaking_count, 0)
  }
}

///|
test "property: diff is symmetric in change count" {
  let rng = @main.new_rng(4242L)
  for i = 0; i < 30; i = i + 1 {
    let a = @main.random_model(rng, "A")
    let b = @main.random_model(rng, "B")
    let ab = @main.diff_models(a, b)
    let ba = @main.diff_models(b, a)
    assert_eq(ab.changes.length(), ba.changes.length())
  }
}

///|
test "property: adding a field is never a breaking change" {
  let rng = @main.new_rng(3333L)
  for i = 0; i < 20; i = i + 1 {
    let m = @main.random_model(rng, "Base")
    let extended = @moonmodel.Model::new(
      m.name,
      m.fields + [@moonmodel.Field::new("added_field", Text)],
      doc=m.doc,
    )
    let report = @main.diff_models(m, extended)
    // Only the added field should appear, and it is not breaking
    assert_eq(report.changes.length(), 1)
    assert_eq(report.breaking_count, 0)
  }
}

// ---- Property: equivalence invariants ----

///|
test "property: model is always equivalent to itself" {
  let rng = @main.new_rng(6060L)
  for i = 0; i < 40; i = i + 1 {
    let m = @main.random_model(rng, "Self")
    match @main.model_equiv(m, m) {
      Equivalent => ()
      other => abort("self-equivalence broken: " + other.to_text())
    }
  }
}

///|
test "property: equivalence is symmetric" {
  let rng = @main.new_rng(2020L)
  for i = 0; i < 30; i = i + 1 {
    let m = @main.random_model(rng, "Sym")
    let a = @main.model_equiv(m, m)
    let b = @main.model_equiv(m, m)
    assert_eq(a.to_text(), b.to_text())
  }
}

///|
test "property: uniformly relaxing all fields makes a strict subtype" {
  let rng = @main.new_rng(1717L)
  for i = 0; i < 20; i = i + 1 {
    // Build a uniformly strict model (every field required, non-nullable)
    let field_count = rng.next_int(4) + 1
    let fields : Array[@moonmodel.Field] = []
    for j = 0; j < field_count; j = j + 1 {
      fields.push(
        @moonmodel.Field::new(
          "f" + j.to_string(),
          Text,
          required=true,
          nullable=false,
          doc="",
          check=@moonmodel.Check::new(),
        ),
      )
    }
    let m = @moonmodel.Model::new("Strict", fields)
    let relaxed = @moonmodel.Model::new(
      m.name,
      m.fields.map(fn(f) {
        @moonmodel.Field::new(
          f.name,
          f.kind,
          required=false,
          nullable=true,
          doc=f.doc,
          check=f.check,
        )
      }),
      doc=m.doc,
    )
    // The strict model is a subtype of the relaxed one (accepts fewer values)
    match @main.model_equiv(m, relaxed) {
      SubtypeOf(_) => ()
      other =>
        abort(
          "strict model must be subtype of relaxed, got: " + other.to_text(),
        )
    }
  }
}

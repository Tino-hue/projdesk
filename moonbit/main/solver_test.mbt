// Constraint solver tests

// ---- Range conflicts ----

test "solver: least > most is conflict" {
  let c = @moonmodel.Check::new(least=10.0, most=5.0)
  let diags = analyze_field("x", c)
  assert_true(has_conflicts(diags))
}

test "solver: least == most is warning" {
  let c = @moonmodel.Check::new(least=5.0, most=5.0)
  let diags = analyze_field("x", c)
  assert_false(has_conflicts(diags))
  assert_true(diags.length() > 0)
}

test "solver: over >= under is conflict" {
  let c = @moonmodel.Check::new(over=5.0, under=5.0)
  let diags = analyze_field("x", c)
  assert_true(has_conflicts(diags))
}

test "solver: least >= under is conflict" {
  let c = @moonmodel.Check::new(least=10.0, under=5.0)
  let diags = analyze_field("x", c)
  assert_true(has_conflicts(diags))
}

test "solver: over >= most is conflict" {
  let c = @moonmodel.Check::new(over=10.0, most=5.0)
  let diags = analyze_field("x", c)
  assert_true(has_conflicts(diags))
}

// ---- Length conflicts ----

test "solver: shortest > longest is conflict" {
  let c = @moonmodel.Check::new(shortest=10, longest=5)
  let diags = analyze_field("x", c)
  assert_true(has_conflicts(diags))
}

test "solver: shortest == longest is warning" {
  let c = @moonmodel.Check::new(shortest=5, longest=5)
  let diags = analyze_field("x", c)
  assert_false(has_conflicts(diags))
}

test "solver: shortest > 0 with longest = 0 is conflict" {
  let c = @moonmodel.Check::new(shortest=1, longest=0)
  let diags = analyze_field("x", c)
  assert_true(has_conflicts(diags))
}

// ---- Redundancy ----

test "solver: least subsumed by over is redundant" {
  let c = @moonmodel.Check::new(least=0.0, over=5.0)
  let diags = analyze_field("x", c)
  let reds = redundancies_only(diags)
  assert_true(reds.length() > 0)
}

test "solver: most subsumed by under is redundant" {
  let c = @moonmodel.Check::new(most=100.0, under=50.0)
  let diags = analyze_field("x", c)
  let reds = redundancies_only(diags)
  assert_true(reds.length() > 0)
}

// ---- Pattern + format ----

test "solver: pattern + format gives warning" {
  let c = @moonmodel.Check::new(pattern="^a", format="email")
  let diags = analyze_field("x", c)
  assert_true(diags.length() > 0)
  assert_false(has_conflicts(diags))
}

// ---- Options + longest ----

test "solver: option exceeding longest is conflict" {
  let c = @moonmodel.Check::new(
    longest=3,
    options=[Json::string("toolong")],
  )
  let diags = analyze_field("x", c)
  assert_true(has_conflicts(diags))
}

// ---- distinct + unique ----

test "solver: distinct + unique gives warning" {
  let c = @moonmodel.Check::new(distinct=true, unique=true)
  let diags = analyze_field("x", c)
  assert_true(diags.length() > 0)
  assert_false(has_conflicts(diags))
}

// ---- Empty check ----

test "solver: empty check gives NoConstraints" {
  let diags = analyze_field("x", @moonmodel.check)
  assert_eq(diags.length(), 1)
  match diags[0] {
    NoConstraints(_) => ()
    _ => abort("expected NoConstraints")
  }
}

// ---- Full model analysis ----

test "solver: analyze_model collects all field diagnoses" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Real, check=@moonmodel.Check::new(least=10.0, most=5.0)),
    @moonmodel.Field::new("b", Text, check=@moonmodel.Check::new(shortest=10, longest=5)),
    @moonmodel.Field::new("c", Text),
  ])
  let diags = analyze_model(m)
  let conflicts = conflicts_only(diags)
  assert_true(conflicts.length() >= 2)
}

test "solver: solve_constraints returns valid JSON" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Real, check=@moonmodel.Check::new(least=10.0, most=5.0)),
  ])
  let json = solve_constraints(m)
  assert_true(json.contains("diagnoses"))
  assert_true(json.contains("conflict_count"))
  assert_true(json.contains("error"))
}

// ---- Diagnosis text ----

test "solver: diagnosis to_text produces readable output" {
  assert_true(Diagnosis::Conflict("x", "test").to_text().contains("[CONFLICT]"))
  assert_true(Diagnosis::Redundant("x", "test").to_text().contains("[REDUNDANT]"))
  assert_true(Diagnosis::Warning("x", "test").to_text().contains("[WARNING]"))
}

test "solver: severity maps correctly" {
  assert_eq(Diagnosis::Conflict("x", "y").severity(), "error")
  assert_eq(Diagnosis::Redundant("x", "y").severity(), "warning")
  assert_eq(Diagnosis::Warning("x", "y").severity(), "info")
  assert_eq(Diagnosis::NoConstraints("x").severity(), "ok")
}

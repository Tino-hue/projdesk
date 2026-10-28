// Interval propagation and semantic analysis tests

// ---- Interval arithmetic ----

///|
test "propagate: intervals intersect tightening bounds" {
  let a : @main.Interval = { lower: Some(0.0), upper: Some(10.0), }
  let b : @main.Interval = { lower: Some(5.0), upper: Some(20.0), }
  let c = a.intersect(b)
  assert_eq(c.lower, Some(5.0))
  assert_eq(c.upper, Some(10.0))
}

///|
test "propagate: empty interval detected" {
  let a : @main.Interval = { lower: Some(10.0), upper: Some(5.0), }
  assert_true(a.is_empty())
}

///|
test "propagate: point interval detected" {
  let a : @main.Interval = { lower: Some(3.0), upper: Some(3.0), }
  assert_true(a.is_point())
  assert_false(a.is_empty())
}

///|
test "propagate: unbounded interval is neither empty nor point" {
  let a = @main.unbounded()
  assert_false(a.is_empty())
  assert_false(a.is_point())
}

// ---- Dependency cycle detection ----

///|
test "propagate: two-field cycle is detected" {
  let bounds : Array[@main.FieldBounds] = [
    {
      name: "a",
      least: Some({ value: Some(0.0), from_field: "b", }),
      most: None,
      over: None,
      under: None,
    },
    {
      name: "b",
      least: Some({ value: Some(0.0), from_field: "a", }),
      most: None,
      over: None,
      under: None,
    },
  ]
  match @main.propagate(bounds) {
    CyclicDependency(_) => ()
    other => abort("expected cycle, got " + other.to_text())
  }
}

///|
test "propagate: self-dependency is a cycle" {
  let bounds : Array[@main.FieldBounds] = [
    {
      name: "a",
      least: Some({ value: Some(0.0), from_field: "a", }),
      most: None,
      over: None,
      under: None,
    },
  ]
  match @main.propagate(bounds) {
    CyclicDependency(_) => ()
    other => abort("expected cycle, got " + other.to_text())
  }
}

///|
test "propagate: three-field cycle is detected" {
  let bounds : Array[@main.FieldBounds] = [
    {
      name: "a",
      least: Some({ value: Some(0.0), from_field: "c", }),
      most: None,
      over: None,
      under: None,
    },
    {
      name: "b",
      least: Some({ value: Some(0.0), from_field: "a", }),
      most: None,
      over: None,
      under: None,
    },
    {
      name: "c",
      least: Some({ value: Some(0.0), from_field: "b", }),
      most: None,
      over: None,
      under: None,
    },
  ]
  match @main.propagate(bounds) {
    CyclicDependency(_) => ()
    other => abort("expected cycle, got " + other.to_text())
  }
}

///|
test "propagate: acyclic references resolve consistently" {
  let bounds : Array[@main.FieldBounds] = [
    {
      name: "a",
      least: Some({ value: Some(0.0), from_field: "", }),
      most: Some({ value: Some(100.0), from_field: "", }),
      over: None,
      under: None,
    },
    {
      name: "b",
      least: Some({ value: Some(0.0), from_field: "a", }),
      most: None,
      over: None,
      under: None,
    },
  ]
  match @main.propagate(bounds) {
    Consistent(_) => ()
    other => abort("expected consistent, got " + other.to_text())
  }
}

///|
test "propagate: empty model is consistent" {
  match @main.propagate([]) {
    Consistent(intervals) => assert_eq(intervals.length(), 0)
    other => abort("expected consistent, got " + other.to_text())
  }
}

///|
test "propagate: a field reached from two places is not a cycle" {
  // value depends on floor, and ceiling depends on floor as well: the graph
  // has a diamond, not a cycle.
  let bounds : Array[@main.FieldBounds] = [
    {
      name: "value",
      least: Some({ value: Some(1.0), from_field: "floor", }),
      most: Some({ value: Some(2.0), from_field: "ceiling", }),
      over: None,
      under: None,
    },
    {
      name: "ceiling",
      least: Some({ value: Some(3.0), from_field: "floor", }),
      most: None,
      over: None,
      under: None,
    },
    {
      name: "floor",
      least: Some({ value: Some(4.0), from_field: "", }),
      most: None,
      over: None,
      under: None,
    },
  ]
  match @main.propagate(bounds) {
    Consistent(_) => ()
    other =>
      abort("expected a diamond to be consistent, got " + other.to_text())
  }
}

///|
test "propagate: a cycle names the fields involved" {
  let bounds : Array[@main.FieldBounds] = [
    {
      name: "a",
      least: Some({ value: Some(1.0), from_field: "b", }),
      most: None,
      over: None,
      under: None,
    },
    {
      name: "b",
      least: Some({ value: Some(1.0), from_field: "a", }),
      most: None,
      over: None,
      under: None,
    },
  ]
  match @main.propagate(bounds) {
    CyclicDependency(fields) => {
      assert_true(fields.contains("a"))
      assert_true(fields.contains("b"))
    }
    other => abort("expected cycle, got " + other.to_text())
  }
}

// ---- Semantic analysis ----

///|
test "semantic: undefined Ref is detected" {
  let (models, _, errors) = @main.dsl_parse(
    "model User {\n  home: Ref(Missing)\n}",
  )
  assert_eq(errors.length(), 0)
  let issues = @main.check_semantics(models)
  assert_eq(issues.length(), 1)
  match issues[0] {
    UndefinedRef(field, target) => {
      assert_eq(field, "home")
      assert_eq(target, "Missing")
    }
    _ => abort("expected UndefinedRef")
  }
}

///|
test "semantic: defined Ref produces no issue" {
  let (models, _, _) = @main.dsl_parse(
    "model User {\n  home: Ref(Address)\n}\n\nmodel Address {\n  line: Text\n}",
  )
  let issues = @main.check_semantics(models)
  assert_eq(issues.length(), 0)
}

///|
test "semantic: two-model cycle is detected" {
  let (models, _, _) = @main.dsl_parse(
    "model A {\n  b: Ref(B)\n}\n\nmodel B {\n  a: Ref(A)\n}",
  )
  let issues = @main.check_semantics(models)
  assert_eq(issues.length(), 1)
  match issues[0] {
    RefCycle(_) => ()
    _ => abort("expected RefCycle")
  }
}

///|
test "semantic: self reference is detected" {
  let (models, _, _) = @main.dsl_parse("model Node {\n  next: Ref(Node)\n}")
  let issues = @main.check_semantics(models)
  assert_true(issues.length() >= 1)
}

///|
test "semantic: three-model cycle is detected" {
  let (models, _, _) = @main.dsl_parse(
    "model A {\n  b: Ref(B)\n}\n\nmodel B {\n  c: Ref(C)\n}\n\nmodel C {\n  a: Ref(A)\n}",
  )
  let issues = @main.check_semantics(models)
  assert_true(issues.length() >= 1)
  match issues[0] {
    RefCycle(_) => ()
    _ => abort("expected RefCycle")
  }
}

///|
test "semantic: nested model Ref is checked" {
  let (models, _, _) = @main.dsl_parse(
    "model User {\n  addr: Nest {\n    owner: Ref(Owner)\n  }\n}",
  )
  let issues = @main.check_semantics(models)
  assert_true(issues.length() >= 1)
}

///|
test "semantic: issue text is readable" {
  let (models, _, _) = @main.dsl_parse("model User {\n  home: Ref(Missing)\n}")
  let issues = @main.check_semantics(models)
  assert_true(issues[0].to_text().contains("Missing"))
  assert_eq(issues[0].severity(), "error")
}

///|
test "semantic: JSON output has issue count" {
  let (models, _, _) = @main.dsl_parse("model User {\n  home: Ref(Missing)\n}")
  let json = @main.check_semantics_json(models)
  assert_true(json.contains("issues"))
  assert_true(json.contains("issue_count"))
}

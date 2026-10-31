// Migration engine tests

///|
test "migration: field added detected" {
  let old = @moonmodel.Model::new("T", [@moonmodel.Field::new("a", Text)])
  let new = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text),
    @moonmodel.Field::new("b", Int),
  ])
  let report = @main.diff_models(old, new)
  assert_eq(report.changes.length(), 1)
  match report.changes[0] {
    FieldAdded(n, _) => assert_eq(n, "b")
    _ => abort("expected FieldAdded")
  }
}

///|
test "migration: field removed detected and is breaking" {
  let old = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text),
    @moonmodel.Field::new("b", Int),
  ])
  let new = @moonmodel.Model::new("T", [@moonmodel.Field::new("a", Text)])
  let report = @main.diff_models(old, new)
  assert_eq(report.changes.length(), 1)
  assert_eq(report.breaking_count, 1)
}

///|
test "migration: type change detected and is breaking" {
  let old = @moonmodel.Model::new("T", [@moonmodel.Field::new("a", Text)])
  let new = @moonmodel.Model::new("T", [@moonmodel.Field::new("a", Big)])
  let report = @main.diff_models(old, new)
  assert_eq(report.changes.length(), 1)
  assert_true(report.changes[0].is_breaking())
}

///|
test "migration: required change detected" {
  let old = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text, required=false),
  ])
  let new = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text, required=true),
  ])
  let report = @main.diff_models(old, new)
  assert_eq(report.changes.length(), 1)
  assert_true(report.changes[0].is_breaking()) // optional -> required is breaking
}

///|
test "migration: nullable change detected" {
  let old = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text, nullable=true),
  ])
  let new = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text, nullable=false),
  ])
  let report = @main.diff_models(old, new)
  assert_eq(report.changes.length(), 1)
  assert_true(report.changes[0].is_breaking()) // nullable -> non-null is breaking
}

///|
test "migration: constraint added detected" {
  let old = @moonmodel.Model::new("T", [@moonmodel.Field::new("a", Text)])
  let new = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text, check=@moonmodel.Check::new(longest=64)),
  ])
  let report = @main.diff_models(old, new)
  assert_eq(report.changes.length(), 1)
  match report.changes[0] {
    ConstraintAdded(_, _) => ()
    _ => abort("expected ConstraintAdded")
  }
}

///|
test "migration: constraint removed detected" {
  let old = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text, check=@moonmodel.Check::new(longest=64)),
  ])
  let new = @moonmodel.Model::new("T", [@moonmodel.Field::new("a", Text)])
  let report = @main.diff_models(old, new)
  assert_eq(report.changes.length(), 1)
  match report.changes[0] {
    ConstraintRemoved(_, _) => ()
    _ => abort("expected ConstraintRemoved")
  }
}

///|
test "migration: identical models produce no changes" {
  let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("a", Text)])
  let report = @main.diff_models(m, m)
  assert_eq(report.changes.length(), 0)
  assert_eq(report.breaking_count, 0)
}

///|
test "migration: SQL ALTER TABLE generated for added field" {
  let old = @moonmodel.Model::new("T", [@moonmodel.Field::new("a", Text)])
  let new = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text),
    @moonmodel.Field::new("b", Big),
  ])
  let sql = @main.generate_sql_migration(old, new)
  assert_true(sql.contains("ALTER TABLE"))
  assert_true(sql.contains("ADD COLUMN"))
  assert_true(sql.contains("b BIGINT"))
}

///|
test "migration: SQL DROP COLUMN for removed field" {
  let old = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text),
    @moonmodel.Field::new("b", Int),
  ])
  let new = @moonmodel.Model::new("T", [@moonmodel.Field::new("a", Text)])
  let sql = @main.generate_sql_migration(old, new)
  assert_true(sql.contains("DROP COLUMN"))
}

///|
test "migration: SQL adds NOT NULL when required changes" {
  let old = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text, required=false),
  ])
  let new = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text, required=true),
  ])
  let sql = @main.generate_sql_migration(old, new)
  assert_true(sql.contains("SET NOT NULL"))
}

///|
test "migration: breaking change count correct" {
  let old = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text),
    @moonmodel.Field::new("b", Text),
    @moonmodel.Field::new("c", Text),
  ])
  let new = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Big), // type change = breaking
    @moonmodel.Field::new("d", Text), // added = not breaking
    // b, c removed = breaking
  ])
  let report = @main.diff_models(old, new)
  assert_eq(report.breaking_count, 3) // 1 type change + 2 removals
}

///|
test "migration: generate_migration returns valid JSON" {
  let old = @moonmodel.Model::new("T", [@moonmodel.Field::new("a", Text)])
  let new = @moonmodel.Model::new("T", [@moonmodel.Field::new("a", Big)])
  let json = @main.generate_migration(old, new)
  assert_true(json.contains("changes"))
  assert_true(json.contains("sql"))
  assert_true(json.contains("breaking_count"))
}

///|
test "migration: @main.Migration::to_text produces readable output" {
  assert_true(
    @main.Migration::FieldAdded("x", "Text").to_text().contains("+ field x"),
  )
  assert_true(
    @main.Migration::FieldRemoved("x").to_text().contains("- field x"),
  )
  assert_true(
    @main.Migration::TypeChanged("x", "Text", "Big")
    .to_text()
    .contains("Text -> Big"),
  )
}

// --- constraint-aware diffing ---
//
// A schema diff compares the text of the constraints. Two of the questions
// that matter cannot be answered that way: whether a constraint change
// changes anything at all, and whether it leaves the field with no
// satisfying value.

///|
test "migration: a constraint another one already implies is not breaking" {
  // over(0) already excludes nothing that least(0) would not, so adding
  // least(0) accepts exactly the same values as before
  let old = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Int, check=@moonmodel.Check::new(over=0.0)),
  ])
  let new = @moonmodel.Model::new("T", [
    @moonmodel.Field::new(
      "a",
      Int,
      check=@moonmodel.Check::new(over=0.0, least=0.0),
    ),
  ])
  let report = @main.diff_models(old, new)
  assert_eq(report.changes.length(), 1)
  match report.changes[0] {
    RedundantConstraint(_, _) => ()
    _ => abort("expected RedundantConstraint")
  }
  assert_eq(report.breaking_count, 0)
}

///|
test "migration: removing an implied constraint is not breaking either" {
  // the least(0) was already implied by over(0), so removing it changes
  // nothing either
  let old = @moonmodel.Model::new("T", [
    @moonmodel.Field::new(
      "a",
      Int,
      check=@moonmodel.Check::new(over=0.0, least=0.0),
    ),
  ])
  let new = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Int, check=@moonmodel.Check::new(over=0.0)),
  ])
  let report = @main.diff_models(old, new)
  assert_eq(report.changes.length(), 1)
  match report.changes[0] {
    RedundantConstraint(_, _) => ()
    _ => abort("expected RedundantConstraint")
  }
  assert_eq(report.breaking_count, 0)
}

///|
test "migration: a bound that moved is one change, not a removal and an addition" {
  let old = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Int, check=@moonmodel.Check::new(over=0.0)),
  ])
  let new = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Int, check=@moonmodel.Check::new(over=10.0)),
  ])
  let report = @main.diff_models(old, new)
  assert_eq(report.changes.length(), 1)
  match report.changes[0] {
    ConstraintChanged(_, kind, _, _, narrowing) => {
      assert_eq(kind, "over")
      assert_true(narrowing) // the field now accepts fewer values
    }
    _ => abort("expected ConstraintChanged")
  }
  assert_eq(report.breaking_count, 1)
}

///|
test "migration: a bound that moved outwards is not breaking" {
  let old = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Int, check=@moonmodel.Check::new(most=5.0)),
  ])
  let new = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Int, check=@moonmodel.Check::new(most=100.0)),
  ])
  let report = @main.diff_models(old, new)
  assert_eq(report.changes.length(), 1)
  assert_eq(report.breaking_count, 0) // more values are accepted, none rejected
}

///|
test "migration: a change that leaves the field with no value is reported" {
  // least(10) with most(5) accepts nothing at all, and that is not the same
  // thing as swapping a constraint
  let old = @moonmodel.Model::new("T", [
    @moonmodel.Field::new(
      "a",
      Int,
      check=@moonmodel.Check::new(least=10.0, most=100.0),
    ),
  ])
  let new = @moonmodel.Model::new("T", [
    @moonmodel.Field::new(
      "a",
      Int,
      check=@moonmodel.Check::new(least=10.0, most=5.0),
    ),
  ])
  let report = @main.diff_models(old, new)
  assert_eq(report.changes.length(), 1)
  match report.changes[0] {
    Unsatisfiable(_, why) => assert_true(why.contains("empty range"))
    _ => abort("expected Unsatisfiable")
  }
  assert_eq(report.breaking_count, 1)
}

///|
test "migration: the solver and the diff agree about what is contradictory" {
  // the same field, judged by the solver and by the diff
  let bad = @moonmodel.Check::new(least=10.0, most=5.0)
  assert_eq(@main.field_conflicts(bad).length(), 1)
  let good = @moonmodel.Check::new(least=1.0, most=5.0)
  assert_eq(@main.field_conflicts(good).length(), 0)
}

///|
test "migration: the solver names the constraints it finds implied" {
  let check = @moonmodel.Check::new(least=0.0, over=0.0)
  let subsumed = @main.subsumed_constraints(check)
  assert_eq(subsumed.length(), 1)
  assert_eq(subsumed[0].part, "least=0")
  assert_true(subsumed[0].reason.contains("subsumed by over"))
}

///|
test "migration: the SQL migration says when a change breaks the model" {
  let old = @moonmodel.Model::new("T", [
    @moonmodel.Field::new(
      "a",
      Int,
      check=@moonmodel.Check::new(least=10.0, most=100.0),
    ),
  ])
  let new = @moonmodel.Model::new("T", [
    @moonmodel.Field::new(
      "a",
      Int,
      check=@moonmodel.Check::new(least=10.0, most=5.0),
    ),
  ])
  let sql = @main.generate_sql_migration(old, new)
  assert_true(sql.contains("ERROR"))
  assert_true(sql.contains("accepts no value"))
}

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

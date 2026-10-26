// Collection type equivalence + complex migration + dialect differences

// ---- Collection type equivalence ----

test "equiv: List(Text) equals List(Text)" {
  let a = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", List(Text)),
  ])
  let b = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", List(Text)),
  ])
  match model_equiv(a, b) {
    Equivalent => ()
    other => abort("expected Equivalent, got " + other.to_text())
  }
}

test "equiv: List(Int) widens to List(Big)" {
  let a = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", List(Int)),
  ])
  let b = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", List(Big)),
  ])
  match model_equiv(a, b) {
    SubtypeOf(_) => ()
    other => abort("expected SubtypeOf, got " + other.to_text())
  }
}

test "equiv: Dict(Text) equals Dict(Text)" {
  let a = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Dict(Text)),
  ])
  let b = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Dict(Text)),
  ])
  match model_equiv(a, b) {
    Equivalent => ()
    other => abort("expected Equivalent, got " + other.to_text())
  }
}

test "equiv: List(Text) incompatible with Dict(Text)" {
  let a = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", List(Text)),
  ])
  let b = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Dict(Text)),
  ])
  match model_equiv(a, b) {
    Incompatible(_) => ()
    other => abort("expected Incompatible, got " + other.to_text())
  }
}

test "equiv: List(Text) incompatible with Text" {
  let a = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", List(Text)),
  ])
  let b = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text),
  ])
  match model_equiv(a, b) {
    Incompatible(_) => ()
    other => abort("expected Incompatible, got " + other.to_text())
  }
}

test "equiv: nested model with same fields is equivalent" {
  let nested1 = @moonmodel.Model::new("", [
    @moonmodel.Field::new("city", Text),
    @moonmodel.Field::new("zip", Int),
  ])
  let nested2 = @moonmodel.Model::new("", [
    @moonmodel.Field::new("city", Text),
    @moonmodel.Field::new("zip", Int),
  ])
  let a = @moonmodel.Model::new("T", [@moonmodel.Field::new("addr", Nest(nested1))])
  let b = @moonmodel.Model::new("T", [@moonmodel.Field::new("addr", Nest(nested2))])
  match model_equiv(a, b) {
    Equivalent => ()
    other => abort("expected Equivalent, got " + other.to_text())
  }
}

test "equiv: nested model with widened field is subtype" {
  let nested1 = @moonmodel.Model::new("", [
    @moonmodel.Field::new("zip", Int),
  ])
  let nested2 = @moonmodel.Model::new("", [
    @moonmodel.Field::new("zip", Big),
  ])
  let a = @moonmodel.Model::new("T", [@moonmodel.Field::new("addr", Nest(nested1))])
  let b = @moonmodel.Model::new("T", [@moonmodel.Field::new("addr", Nest(nested2))])
  match model_equiv(a, b) {
    SubtypeOf(_) => ()
    other => abort("expected SubtypeOf, got " + other.to_text())
  }
}

test "equiv: nested model with different field count is incompatible" {
  let nested1 = @moonmodel.Model::new("", [
    @moonmodel.Field::new("city", Text),
  ])
  let nested2 = @moonmodel.Model::new("", [
    @moonmodel.Field::new("city", Text),
    @moonmodel.Field::new("zip", Int),
  ])
  let a = @moonmodel.Model::new("T", [@moonmodel.Field::new("addr", Nest(nested1))])
  let b = @moonmodel.Model::new("T", [@moonmodel.Field::new("addr", Nest(nested2))])
  match model_equiv(a, b) {
    Incompatible(_) => ()
    other => abort("expected Incompatible, got " + other.to_text())
  }
}

test "equiv: List of List widens recursively" {
  let a = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", List(List(Int))),
  ])
  let b = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", List(List(Big))),
  ])
  match model_equiv(a, b) {
    SubtypeOf(_) => ()
    other => abort("expected SubtypeOf, got " + other.to_text())
  }
}

// ---- Complex multi-field migration ----

test "migration: multiple simultaneous changes detected" {
  let old = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text),
    @moonmodel.Field::new("b", Int),
    @moonmodel.Field::new("c", Bool),
  ])
  let new = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Big),      // type changed
    @moonmodel.Field::new("c", Bool),     // b removed
    @moonmodel.Field::new("d", Text),     // d added
  ])
  let report = diff_models(old, new)
  assert_eq(report.changes.length(), 3)
  // type change + removal = breaking
  assert_eq(report.breaking_count, 2)
}

test "migration: multi-field SQL contains all statements" {
  let old = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text),
    @moonmodel.Field::new("b", Int),
  ])
  let new = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text),
    @moonmodel.Field::new("b", Int),
    @moonmodel.Field::new("c", Bool),
  ])
  let sql = generate_sql_migration(old, new)
  assert_true(sql.contains("ADD COLUMN c BOOLEAN"))
  assert_true(sql.contains("ALTER TABLE T"))
}

test "migration: required + nullable changes both emitted" {
  let old = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, required=false, nullable=true),
  ])
  let new = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, required=true, nullable=false),
  ])
  let sql = generate_sql_migration(old, new)
  assert_true(sql.contains("SET NOT NULL"))
}

test "migration: constraint add generates UNIQUE constraint SQL" {
  let old = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("id", Big),
  ])
  let new = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("id", Big, check=@moonmodel.Check::new(unique=true)),
  ])
  let sql = generate_sql_migration(old, new)
  assert_true(sql.contains("ADD CONSTRAINT"))
  assert_true(sql.contains("UNIQUE"))
}

// ---- Dialect differences ----

test "migration: Postgres vs Sqlite vs Mysql type names differ" {
  let old = @moonmodel.Model::new("T", [])
  let new = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Bool),
    @moonmodel.Field::new("b", Bytes),
    @moonmodel.Field::new("c", Stamp),
  ])
  let pg = generate_sql_migration(old, new, dialect="Postgres")
  let lite = generate_sql_migration(old, new, dialect="Sqlite")
  let my = generate_sql_migration(old, new, dialect="Mysql")
  assert_true(pg.contains("BOOLEAN"))
  assert_true(pg.contains("BYTEA"))
  assert_true(pg.contains("TIMESTAMPTZ"))
  assert_true(lite.contains("INTEGER"))
  assert_true(lite.contains("BLOB"))
  assert_true(lite.contains("TEXT"))
  assert_true(my.contains("TINYINT(1)"))
  assert_true(my.contains("BLOB"))
  assert_true(my.contains("DATETIME"))
}

test "migration: dialect comment appears in output" {
  let old = @moonmodel.Model::new("T", [])
  let new = @moonmodel.Model::new("T", [@moonmodel.Field::new("a", Text)])
  let sql = generate_sql_migration(old, new, dialect="Mysql")
  assert_true(sql.contains("Mysql"))
}

test "migration: breaking change warning appears in SQL" {
  let old = @moonmodel.Model::new("T", [@moonmodel.Field::new("a", Text)])
  let new = @moonmodel.Model::new("T", [])
  let sql = generate_sql_migration(old, new)
  assert_true(sql.contains("WARNING"))
  assert_true(sql.contains("breaking"))
}

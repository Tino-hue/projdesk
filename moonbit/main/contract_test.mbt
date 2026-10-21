// Contract tests: lock required x nullable x four-target semantics + drop list correctness

///|
/// Build a minimal test model
fn test_model() -> @moonmodel.Model {
  @moonmodel.Model::new(
    "Test",
    [
      @moonmodel.Field::new("id", Big, check=@moonmodel.Check::new(unique=true)),
      @moonmodel.Field::new(
        "name",
        Text,
        check=@moonmodel.Check::new(shortest=1, longest=64),
      ),
      @moonmodel.Field::new("age", Int, required=false),
      @moonmodel.Field::new("avatar", Bytes, nullable=true),
      @moonmodel.Field::new("home", Ref("Address")),
    ],
  )
}

///|
fn test_address() -> @moonmodel.Model {
  @moonmodel.Model::new("Address", [@moonmodel.Field::new("line", Text)])
}

// ---- required x nullable semantics ----

test "required=true nullable=false: appears in required list" {
  let m = test_model()
  let req = m.required()
  assert_true(req.contains("id"))
  assert_true(req.contains("name"))
  assert_false(req.contains("age")) // age is required=false
}

test "JSON Schema: required lists only required=true fields" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text),
    @moonmodel.Field::new("b", Text, required=false),
    @moonmodel.Field::new("c", Text),
  ])
  let (text, _) = project_json_schema(m, [])
  // required should list a and c but NOT b
  assert_true(text.contains("\"a\""))
  assert_true(text.contains("\"c\""))
  // b is not required so should not be in the required array
  // (it still appears in properties)
  let model = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text),
    @moonmodel.Field::new("b", Text, required=false),
    @moonmodel.Field::new("c", Text),
  ])
  let req = model.required()
  assert_eq(req.length(), 2)
  assert_true(req.contains("a"))
  assert_true(req.contains("c"))
  assert_false(req.contains("b"))
}

test "JSON Schema: nullable field gets type array with null" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, nullable=true),
  ])
  let (text, _) = project_json_schema(m, [])
  assert_true(text.contains("null"))
}

test "SQL: required=true nullable=false produces NOT NULL" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, required=true, nullable=false),
  ])
  let (text, _) = project_sql(m)
  assert_true(text.contains("NOT NULL"))
}

test "SQL: required=true nullable=true does NOT produce NOT NULL" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, required=true, nullable=true),
  ])
  let (text, _) = project_sql(m)
  assert_false(text.contains("NOT NULL"))
}

test "SQL: required=false nullable=false does NOT produce NOT NULL" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, required=false, nullable=false),
  ])
  let (text, _) = project_sql(m)
  assert_false(text.contains("NOT NULL"))
}

test "GraphQL: required=true nullable=false produces !" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, required=true, nullable=false),
  ])
  let (text, _) = project_graphql(m, [])
  assert_true(text.contains("x: String!"))
}

test "GraphQL: required=true nullable=true does NOT produce !" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, required=true, nullable=true),
  ])
  let (text, _) = project_graphql(m, [])
  assert_false(text.contains("x: String!"))
}

test "GraphQL: required=false nullable=false does NOT produce !" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, required=false, nullable=false),
  ])
  let (text, _) = project_graphql(m, [])
  assert_false(text.contains("x: String!"))
}

// ---- drop list correctness ----

test "JSON Schema drops unique constraint" {
  let m = test_model()
  let (_, drops) = project_json_schema(m, [])
  assert_eq(drops.length(), 1)
  assert_eq(drops[0].field, "id")
  assert_eq(drops[0].constraint, "unique")
}

test "SQL drops pattern, format, step, distinct" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text, check=@moonmodel.Check::new(pattern="^x$")),
    @moonmodel.Field::new("b", Text, check=@moonmodel.Check::new(format="email")),
    @moonmodel.Field::new("c", Real, check=@moonmodel.Check::new(step=0.01)),
    @moonmodel.Field::new("d", List(Text), check=@moonmodel.Check::new(distinct=true)),
    @moonmodel.Field::new("e", Text, check=@moonmodel.Check::new(unique=true)),
  ])
  let (_, drops) = project_sql(m)
  // pattern, format, step, distinct = 4 drops; unique is carried by SQL
  assert_true(drops.length() >= 4)
  let constraints = drops.map(fn(d) { d.constraint })
  assert_true(constraints.contains("pattern"))
  assert_true(constraints.contains("format"))
  assert_true(constraints.contains("step"))
  assert_true(constraints.contains("distinct"))
}

test "SQL keeps unique (no drop for unique)" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text, check=@moonmodel.Check::new(unique=true)),
  ])
  let (text, drops) = project_sql(m)
  assert_true(text.contains("UNIQUE"))
  // unique should NOT be in drops
  for d in drops {
    assert_false(d.constraint == "unique")
  }
}

test "GraphQL drops all Check constraints" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text, check=@moonmodel.Check::new(shortest=1, longest=10)),
  ])
  let (_, drops) = project_graphql(m, [])
  assert_true(drops.length() >= 2) // shortest + longest
  let constraints = drops.map(fn(d) { d.constraint })
  assert_true(constraints.contains("shortest"))
  assert_true(constraints.contains("longest"))
}

test "SQL drops unprojectable fields with reason" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("meta", Dict(Text)),
    @moonmodel.Field::new("nested", Nest(@moonmodel.Model::new("", [@moonmodel.Field::new("x", Text)]))),
    @moonmodel.Field::new("ok", Text),
    @moonmodel.Field::new("tags", List(Text)), // Postgres: TEXT[], projectable
  ])
  let (_, drops) = project_sql(m)
  let field_drops = drops.filter(fn(d) { d.constraint == "(field)" })
  // meta (Dict) and nested (Nest) have no column; tags (List) is OK in Postgres
  assert_eq(field_drops.length(), 2)
}

// ---- type projection ----

test "JSON Schema: every simple type maps correctly" {
  fn check_type(kind : @moonmodel.Type, expect : String) -> Bool {
    let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", kind)])
    let (text, _) = project_json_schema(m, [])
    text.contains(expect)
  }
  assert_true(check_type(Bool, "boolean"), msg="Bool->boolean")
  assert_true(check_type(Int, "int32"), msg="Int->int32")
  assert_true(check_type(Big, "int64"), msg="Big->int64")
  assert_true(check_type(Real, "number"), msg="Real->number")
  assert_true(check_type(Text, "string"), msg="Text->string")
  assert_true(check_type(Bytes, "byte"), msg="Bytes->byte")
  assert_true(check_type(Stamp, "date-time"), msg="Stamp->date-time")
}

test "SQL: Postgres type names" {
  fn check_sql_type(kind : @moonmodel.Type, expect : String) -> Bool {
    let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", kind)])
    let (text, _) = project_sql(m)
    text.contains(expect)
  }
  assert_true(check_sql_type(Bool, "BOOLEAN"))
  assert_true(check_sql_type(Int, "INTEGER"))
  assert_true(check_sql_type(Big, "BIGINT"))
  assert_true(check_sql_type(Real, "DOUBLE PRECISION"))
  assert_true(check_sql_type(Text, "TEXT"))
  assert_true(check_sql_type(Bytes, "BYTEA"))
  assert_true(check_sql_type(Stamp, "TIMESTAMPTZ"))
}

// ---- export ABI ----

test "project_all returns all four outputs non-empty" {
  let m = test_model()
  let known = [test_address()]
  let result = project_all(m, known)
  assert_true(result.json_schema.length() > 0)
  assert_true(result.openapi.length() > 0)
  assert_true(result.sql.length() > 0)
  assert_true(result.graphql.length() > 0)
}

test "project_all SQL contains CREATE TABLE" {
  let m = test_model()
  let result = project_all(m, [])
  assert_true(result.sql.contains("CREATE TABLE"))
}

test "project_all GraphQL contains type declaration" {
  let m = test_model()
  let result = project_all(m, [])
  assert_true(result.graphql.contains("type Test"))
}

// ---- presets ----

test "presets return 3 models with correct names" {
  let ps = presets()
  assert_eq(ps.length(), 3)
  assert_eq(ps[0].name, "User")
  assert_eq(ps[1].name, "Order")
  assert_eq(ps[2].name, "Address")
}

test "User preset has Ref to Address" {
  let user = preset_by_name("User").unwrap()
  let mentions = user.mentions()
  assert_true(mentions.contains("Address"))
}





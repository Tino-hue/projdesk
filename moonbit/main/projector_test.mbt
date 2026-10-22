// Contract tests for Projector trait, DropReason ADT, and core projections

///|
/// Helper: build a simple test model
fn make_test_model() -> @moonmodel.Model {
  @moonmodel.Model::new("User", [
    @moonmodel.Field::new("id", Big, check=@moonmodel.Check::new(unique=true)),
    @moonmodel.Field::new("name", Text, check=@moonmodel.Check::new(shortest=1, longest=64)),
    @moonmodel.Field::new("email", Text, check=@moonmodel.Check::new(format="email")),
    @moonmodel.Field::new("tags", List(Text), check=@moonmodel.Check::new(distinct=true)),
    @moonmodel.Field::new("avatar", Bytes, required=false, nullable=true),
  ])
}

// ---- Projector trait ----

test "JsonProjector implements Projector trait" {
  let p = JsonProjector::{}
  assert_eq(p.target_name(), "JSON Schema 2020-12")
  let (text, drops) = p.project(make_test_model(), [])
  assert_true(text.contains("User"))
  assert_true(drops.any(fn(d) { d.constraint() == "unique" }))
}

test "OpenApiProj implements Projector trait" {
  let p = OpenApiProj::{}
  assert_eq(p.target_name(), "OpenAPI Schema Object")
  let (text, drops) = p.project(make_test_model(), [])
  assert_true(text.contains("User"))
  assert_true(drops.any(fn(d) { d.constraint() == "unique" }))
}

test "SqlProj implements Projector trait" {
  let p = SqlProj::{ dialect: Postgres }
  assert_eq(p.target_name(), "SQL DDL")
  let (text, drops) = p.project(make_test_model(), [])
  assert_true(text.contains("CREATE TABLE"))
  assert_true(text.contains("UNIQUE"))
  // SQL carries unique but drops pattern/format/distinct
  assert_false(drops.any(fn(d) { d.constraint() == "unique" }))
  assert_true(drops.any(fn(d) { d.constraint() == "format" }))
  assert_true(drops.any(fn(d) { d.constraint() == "distinct" }))
}

test "GraphqlProj implements Projector trait" {
  let p = GraphqlProj::{}
  assert_eq(p.target_name(), "GraphQL SDL")
  let (text, drops) = p.project(make_test_model(), [])
  assert_true(text.contains("type User"))
  // GraphQL drops almost everything
  assert_true(drops.length() >= 5)
}

// ---- DropReason ADT ----

test "DropReason::to_text produces human-readable text" {
  assert_true(DropReason::UniqueNotCarried("id").to_text().contains("id"))
  assert_true(DropReason::PatternNotCarried("email").to_text().contains("pattern"))
  assert_true(DropReason::FieldNotCarried("meta", "Dict", "no column").to_text().contains("meta"))
}

test "DropReason::constraint extracts constraint name" {
  assert_eq(DropReason::UniqueNotCarried("x").constraint(), "unique")
  assert_eq(DropReason::PatternNotCarried("x").constraint(), "pattern")
  assert_eq(DropReason::FormatNotCarried("x").constraint(), "format")
  assert_eq(DropReason::StepNotCarried("x").constraint(), "step")
  assert_eq(DropReason::DistinctNotCarried("x").constraint(), "distinct")
  assert_eq(DropReason::BoundsNotCarried("x", "least").constraint(), "least")
  assert_eq(DropReason::LengthNotCarried("x").constraint(), "length")
  assert_eq(DropReason::OptionsNotCarried("x").constraint(), "options")
}

test "DropReason::field extracts field name" {
  assert_eq(DropReason::UniqueNotCarried("id").field(), "id")
  assert_eq(DropReason::FieldNotCarried("meta", "Dict", "why").field(), "meta")
}

test "DropReason Eq works" {
  assert_eq(DropReason::UniqueNotCarried("id"), DropReason::UniqueNotCarried("id"))
  assert_not_eq(DropReason::UniqueNotCarried("a"), DropReason::UniqueNotCarried("b"))
}

// ---- Core projection contract tests ----

test "required=true nullable=false: SQL has NOT NULL, GraphQL has !" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, required=true, nullable=false),
  ])
  let sql = SqlProj::{ dialect: Postgres }
  let (sql_text, _) = sql.project(m, [])
  assert_true(sql_text.contains("NOT NULL"))
  let gql = GraphqlProj::{}
  let (gql_text, _) = gql.project(m, [])
  assert_true(gql_text.contains("x: String!"))
}

test "required=true nullable=true: no NOT NULL, no !" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, required=true, nullable=true),
  ])
  let sql = SqlProj::{ dialect: Postgres }
  let (sql_text, _) = sql.project(m, [])
  assert_false(sql_text.contains("NOT NULL"))
  let gql = GraphqlProj::{}
  let (gql_text, _) = gql.project(m, [])
  assert_false(gql_text.contains("x: String!"))
}

test "JSON Schema: every Type variant produces output" {
  let types : Array[@moonmodel.Type] = [
    Bool, Int, Big, Real, Text, Bytes, Stamp, Any,
    List(Text), Dict(Int), Ref("Address"),
  ]
  for t in types {
    let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", t)])
    let p = JsonProjector::{}
    let (text, _) = p.project(m, [])
    assert_true(text.length() > 0)
  }
}

test "SQL Postgres vs Sqlite type names differ" {
  let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", Bool)])
  let pg = SqlProj::{ dialect: Postgres }
  let lite = SqlProj::{ dialect: Sqlite }
  let (pg_text, _) = pg.project(m, [])
  let (lite_text, _) = lite.project(m, [])
  assert_true(pg_text.contains("BOOLEAN"))
  assert_true(lite_text.contains("INTEGER"))
}

// ---- Codegen tests ----

test "TypeScript projection produces interface" {
  let m = make_test_model()
  let ts = project_typescript(m, [])
  assert_true(ts.contains("export interface User"))
  assert_true(ts.contains("id: number"))
  assert_true(ts.contains("tags"))
}

test "Zod projection produces schema" {
  let m = make_test_model()
  let zod = project_zod(m, [])
  assert_true(zod.contains("z.object"))
  assert_true(zod.contains("UserSchema"))
}

test "Prisma projection produces model" {
  let m = make_test_model()
  let prisma = project_prisma(m, [])
  assert_true(prisma.contains("model User"))
  assert_true(prisma.contains("@unique"))
}

// ---- ABI round-trip ----

test "parse_input with full model reconstructs correctly" {
  let input = parse_input("{\"name\":\"User\",\"doc\":\"test\",\"fields\":[{\"name\":\"id\",\"kind\":\"Big\",\"required\":true,\"nullable\":false,\"doc\":\"ID\",\"default\":null,\"check\":{\"unique\":true}}],\"known\":[]}")
  assert_eq(input.model.name, "User")
  assert_eq(input.model.fields.length(), 1)
  assert_eq(input.model.fields[0].check.unique, true)
}

test "project_all produces all seven outputs" {
  let result = project_all(make_test_model(), [])
  assert_true(result.json_schema.length() > 0)
  assert_true(result.openapi.length() > 0)
  assert_true(result.sql.length() > 0)
  assert_true(result.graphql.length() > 0)
  assert_true(result.typescript.length() > 0)
  assert_true(result.zod.length() > 0)
  assert_true(result.prisma.length() > 0)
}

// ---- Preset integrity ----

test "presets load and project successfully" {
  let ps = presets()
  assert_eq(ps.length(), 3)
  for m in ps {
    let result = project_all(m, [])
    assert_true(result.json_schema.length() > 0, msg=m.name)
    assert_true(result.sql.length() > 0, msg=m.name)
  }
}

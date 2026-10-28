// Contract tests for Projector trait, DropReason ADT, and core projections

///|
/// Helper: build a simple test model
fn make_test_model() -> @moonmodel.Model {
  @moonmodel.Model::new("User", [
    @moonmodel.Field::new("id", Big, check=@moonmodel.Check::new(unique=true)),
    @moonmodel.Field::new(
      "name",
      Text,
      check=@moonmodel.Check::new(shortest=1, longest=64),
    ),
    @moonmodel.Field::new(
      "email",
      Text,
      check=@moonmodel.Check::new(format="email"),
    ),
    @moonmodel.Field::new(
      "tags",
      List(Text),
      check=@moonmodel.Check::new(distinct=true),
    ),
    @moonmodel.Field::new("avatar", Bytes, required=false, nullable=true),
  ])
}

// ---- Projector trait ----

///|
test "JsonProjector implements Projector trait" {
  let p = @main.JsonProjector::{ }
  assert_eq(p.target_name(), "JSON Schema 2020-12")
  let (text, drops) = p.project(make_test_model(), [])
  assert_true(text.contains("User"))
  assert_true(drops.any(fn(d) { d.constraint() == "unique" }))
}

///|
test "OpenApiProj implements Projector trait" {
  let p = @main.OpenApiProj::{ dialect: OpenApi30, }
  assert_eq(p.target_name(), "OpenAPI Schema Object")
  let (text, _drops) = p.project(make_test_model(), [])
  assert_true(text.contains("User"))
}

///|
test "SqlProj implements Projector trait" {
  let p = @main.SqlProj::{ dialect: Postgres, }
  assert_eq(p.target_name(), "SQL DDL")
  let (text, drops) = p.project(make_test_model(), [])
  assert_true(text.contains("CREATE TABLE"))
  assert_true(text.contains("UNIQUE"))
  assert_false(drops.any(fn(d) { d.constraint() == "unique" }))
}

///|
test "GraphqlProj implements Projector trait" {
  let p = @main.GraphqlProj::{ }
  assert_eq(p.target_name(), "GraphQL SDL")
  let (text, drops) = p.project(make_test_model(), [])
  assert_true(text.contains("type User"))
  // id.unique, name.length, email.format, tags.distinct
  assert_eq(drops.length(), 4)
  assert_true(drops.any(fn(d) { d.constraint() == "unique" }))
  assert_true(drops.any(fn(d) { d.constraint() == "length" }))
}

// ---- DropReason ADT ----

///|
test "@main.DropReason::to_text produces human-readable text" {
  assert_true(@main.DropReason::UniqueNotCarried("id").to_text().contains("id"))
  assert_true(
    @main.DropReason::PatternNotCarried("email").to_text().contains("pattern"),
  )
}

///|
test "@main.DropReason::constraint extracts constraint name" {
  assert_eq(@main.DropReason::UniqueNotCarried("x").constraint(), "unique")
  assert_eq(@main.DropReason::PatternNotCarried("x").constraint(), "pattern")
  assert_eq(
    @main.DropReason::BoundsNotCarried("x", "least").constraint(),
    "least",
  )
}

///|
test "@main.DropReason::field extracts field name" {
  assert_eq(@main.DropReason::UniqueNotCarried("id").field(), "id")
}

// ---- Core projection contract tests ----

///|
test "required=true nullable=false: SQL has NOT NULL, GraphQL has !" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, required=true, nullable=false),
  ])
  let sql = @main.SqlProj::{ dialect: Postgres, }
  let (sql_text, _) = sql.project(m, [])
  assert_true(sql_text.contains("NOT NULL"))
  let gql = @main.GraphqlProj::{ }
  let (gql_text, _) = gql.project(m, [])
  assert_true(gql_text.contains("x: String!"))
}

///|
test "SQL Postgres vs Sqlite type names differ" {
  let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", Bool)])
  let pg = @main.SqlProj::{ dialect: Postgres, }
  let lite = @main.SqlProj::{ dialect: Sqlite, }
  let (pg_text, _) = pg.project(m, [])
  let (lite_text, _) = lite.project(m, [])
  assert_true(pg_text.contains("BOOLEAN"))
  assert_true(lite_text.contains("INTEGER"))
}

// ---- Codegen tests ----

///|
test "TypeScript projection produces interface" {
  let p = @main.TsProjector::{ }
  let (ts, _drops) = p.project(make_test_model(), [])
  assert_true(ts.contains("export interface User"))
}

///|
test "Zod projection produces schema" {
  let p = @main.ZodProjector::{ }
  let (zod, _drops) = p.project(make_test_model(), [])
  assert_true(zod.contains("z.object"))
}

///|
test "Prisma projection produces model" {
  let p = @main.PrismaProjector::{ }
  let (prisma, _drops) = p.project(make_test_model(), [])
  assert_true(prisma.contains("model User"))
  assert_true(prisma.contains("@unique"))
}

// ---- Codegen drop reporting ----

///|
test "TypeScript reports every constraint it cannot carry" {
  let p = @main.TsProjector::{ }
  let (_text, drops) = p.project(make_test_model(), [])
  assert_true(
    drops.any(fn(d) { d.constraint() == "unique" && d.field() == "id" }),
  )
  assert_true(
    drops.any(fn(d) { d.constraint() == "length" && d.field() == "name" }),
  )
  assert_true(
    drops.any(fn(d) { d.constraint() == "format" && d.field() == "email" }),
  )
  assert_true(
    drops.any(fn(d) { d.constraint() == "distinct" && d.field() == "tags" }),
  )
}

///|
test "Prisma carries unique but reports the rest" {
  let p = @main.PrismaProjector::{ }
  let (_text, drops) = p.project(make_test_model(), [])
  assert_false(drops.any(fn(d) { d.constraint() == "unique" }))
  assert_true(
    drops.any(fn(d) { d.constraint() == "length" && d.field() == "name" }),
  )
  assert_true(
    drops.any(fn(d) { d.constraint() == "format" && d.field() == "email" }),
  )
}

///|
test "Zod carries length bounds, formats and list distinctness" {
  let p = @main.ZodProjector::{ }
  let (zod, drops) = p.project(make_test_model(), [])
  assert_true(zod.contains(".min(1)"))
  assert_true(zod.contains(".max(64)"))
  assert_true(zod.contains(".email()"))
  assert_true(zod.contains(".refine("))
  assert_false(drops.any(fn(d) { d.constraint() == "length" }))
  assert_false(drops.any(fn(d) { d.constraint() == "format" }))
  assert_false(drops.any(fn(d) { d.constraint() == "distinct" }))
  // record-level uniqueness is not a property of a single value
  assert_true(drops.any(fn(d) { d.constraint() == "unique" }))
}

///|
test "Zod carries numeric bounds and exclusive bounds" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new(
      "n",
      Int,
      check=@moonmodel.Check::new(least=1.0, most=10.0, over=0.0, under=11.0),
    ),
  ])
  let p = @main.ZodProjector::{ }
  let (zod, drops) = p.project(m, [])
  assert_true(zod.contains(".min(1)"))
  assert_true(zod.contains(".max(10)"))
  assert_true(zod.contains(".gt(0)"))
  assert_true(zod.contains(".lt(11)"))
  assert_eq(drops.length(), 0)
}

///|
test "Zod renders a closed value set as an enum" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new(
      "status",
      Text,
      check=@moonmodel.Check::new(options=[
        Json::string("open"),
        Json::string("closed"),
      ]),
    ),
  ])
  let p = @main.ZodProjector::{ }
  let (zod, drops) = p.project(m, [])
  assert_true(zod.contains(".enum(["))
  assert_true(zod.contains("\"open\""))
  assert_eq(drops.length(), 0)
}

///|
test "Zod reports constraints that do not apply to the field type" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("name", Text, check=@moonmodel.Check::new(least=1.0)),
  ])
  let p = @main.ZodProjector::{ }
  let (_zod, drops) = p.project(m, [])
  assert_true(drops.any(fn(d) { d.constraint() == "least" }))
}

///|
test "Zod escapes a regex pattern into a JavaScript literal" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new(
      "code",
      Text,
      check=@moonmodel.Check::new(pattern="a\"b"),
    ),
  ])
  let p = @main.ZodProjector::{ }
  let (zod, _drops) = p.project(m, [])
  assert_true(zod.contains("new RegExp(\"a\\\"b\")"))
}

// ---- ABI round-trip ----

///|
test "parse_input with full model reconstructs correctly" {
  let input = @main.parse_input(
    "{\"name\":\"User\",\"doc\":\"test\",\"fields\":[{\"name\":\"id\",\"kind\":\"Big\",\"required\":true,\"nullable\":false,\"doc\":\"ID\",\"default\":null,\"check\":{\"unique\":true}}],\"known\":[]}",
  )
  assert_eq(input.model.name, "User")
  assert_eq(input.model.fields.length(), 1)
}

///|
test "project_all produces all seven outputs" {
  let result = @main.project_all(make_test_model(), [])
  assert_true(result.json_schema.length() > 0)
  assert_true(result.openapi.length() > 0)
  assert_true(result.sql.length() > 0)
  assert_true(result.graphql.length() > 0)
  assert_true(result.typescript.length() > 0)
  assert_true(result.zod.length() > 0)
  assert_true(result.prisma.length() > 0)
}

// ---- Preset integrity ----

///|
test "presets load and project successfully" {
  let ps = @main.presets()
  assert_eq(ps.length(), 3)
  for m in ps {
    let result = @main.project_all(m, [])
    assert_true(result.json_schema.length() > 0)
  }
}

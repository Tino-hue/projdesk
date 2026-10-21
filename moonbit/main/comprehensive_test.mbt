// Comprehensive contract tests: edge cases, matrices, boundaries, dialects

// ---- Type projection: every Type variant x every target ----

fn one_field_model(kind : @moonmodel.Type) -> @moonmodel.Model {
  @moonmodel.Model::new("T", [@moonmodel.Field::new("x", kind)])
}

test "every Type variant produces non-empty output in all four targets" {
  let types : Array[@moonmodel.Type] = [
    Bool, Int, Big, Real, Text, Bytes, Stamp, Any,
    List(Text), List(Int), List(List(Text)),
    Dict(Text), Dict(Int),
  ]
  for t in types {
    let m = one_field_model(t)
    let result = project_all(m, [])
    assert_true(result.json_schema.length() > 0, msg="json_schema empty")
    assert_true(result.openapi.length() > 0, msg="openapi empty")
    assert_true(result.sql.length() > 0, msg="sql empty")
    assert_true(result.graphql.length() > 0, msg="graphql empty")
  }
}

test "Ref type produces reference in JSON Schema and GraphQL" {
  let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("home", Ref("Address"))])
  let known = [@moonmodel.Model::new("Address", [@moonmodel.Field::new("line", Text)])]
  let (js, _) = project_json_schema(m, known)
  let (gql, _) = project_graphql(m, known)
  assert_true(js.contains("Address"))
  assert_true(gql.contains("Address"))
}

test "Nest type is inlined in JSON Schema but skipped in SQL and GraphQL" {
  let nested = @moonmodel.Model::new("", [@moonmodel.Field::new("inner", Text)])
  let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", Nest(nested))])
  let (js, _) = project_json_schema(m, [])
  let (_, sql_drops) = project_sql(m)
  let (_, gql_drops) = project_graphql(m, [])
  assert_true(js.contains("inner"), msg="Nest inlined in JSON Schema")
  assert_true(sql_drops.length() > 0, msg="Nest dropped in SQL")
  assert_true(gql_drops.length() > 0, msg="Nest dropped in GraphQL")
}

// ---- required x nullable: full truth table x four targets ----

test "required=true nullable=false: all four targets enforce non-null" {
  let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", Text, required=true, nullable=false)])
  let req = m.required()
  assert_true(req.contains("x"))
  let (js, _) = project_json_schema(m, [])
  let (sql, _) = project_sql(m)
  let (gql, _) = project_graphql(m, [])
  assert_true(js.contains("\"required\""))
  assert_true(sql.contains("NOT NULL"))
  assert_true(gql.contains("x: String!"))
}

test "required=true nullable=true: required in list, nullable in type, no NOT NULL, no !" {
  let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", Text, required=true, nullable=true)])
  let req = m.required()
  assert_true(req.contains("x"))
  let (js, _) = project_json_schema(m, [])
  let (sql, _) = project_sql(m)
  let (gql, _) = project_graphql(m, [])
  assert_true(js.contains("null"), msg="nullable in JSON Schema")
  assert_false(sql.contains("NOT NULL"), msg="no NOT NULL when nullable")
  assert_false(gql.contains("x: String!"), msg="no ! when nullable")
}

test "required=false nullable=false: not in required list, no NOT NULL, no !" {
  let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", Text, required=false, nullable=false)])
  let req = m.required()
  assert_false(req.contains("x"))
  let (sql, _) = project_sql(m)
  let (gql, _) = project_graphql(m, [])
  assert_false(sql.contains("NOT NULL"))
  assert_false(gql.contains("x: String!"))
}

test "required=false nullable=true: fully optional" {
  let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", Text, required=false, nullable=true)])
  let req = m.required()
  assert_false(req.contains("x"))
  let (js, _) = project_json_schema(m, [])
  let (sql, _) = project_sql(m)
  let (gql, _) = project_graphql(m, [])
  assert_true(js.contains("null"))
  assert_false(sql.contains("NOT NULL"))
  assert_false(gql.contains("x: String!"))
}

// ---- Every Check constraint x four targets: carry or drop ----

test "least/most/over/under/step are carried by JSON Schema and SQL, dropped by GraphQL" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Real, check=@moonmodel.Check::new(
      least=0.0, most=100.0, over=-1.0, under=101.0, step=0.5,
    )),
  ])
  let (js, js_drops) = project_json_schema(m, [])
  let (sql, _) = project_sql(m)
  let (_, gql_drops) = project_graphql(m, [])
  assert_true(js.contains("minimum"))
  assert_true(js.contains("maximum"))
  assert_true(js.contains("exclusiveMinimum"))
  assert_true(js.contains("exclusiveMaximum"))
  assert_true(js.contains("multipleOf"))
  assert_true(sql.contains("CHECK"))
  assert_eq(gql_drops.length(), 5, msg="GraphQL drops all 5 numeric bounds")
}

test "shortest/longest carried by JSON Schema and SQL, dropped by GraphQL" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, check=@moonmodel.Check::new(shortest=1, longest=64)),
  ])
  let (js, _) = project_json_schema(m, [])
  let (sql, _) = project_sql(m)
  let (_, gql_drops) = project_graphql(m, [])
  assert_true(js.contains("minLength"))
  assert_true(js.contains("maxLength"))
  assert_true(sql.contains("length"))
  assert_eq(gql_drops.length(), 2)
}

test "pattern carried by JSON Schema, dropped by SQL and GraphQL" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, check=@moonmodel.Check::new(pattern="^a+$")),
  ])
  let (js, js_drops) = project_json_schema(m, [])
  let (_, sql_drops) = project_sql(m)
  let (_, gql_drops) = project_graphql(m, [])
  assert_true(js.contains("pattern"))
  assert_eq(js_drops.length(), 0, msg="JSON Schema carries pattern")
  assert_true(sql_drops.any(fn(d) { d.constraint == "pattern" }))
  assert_true(gql_drops.any(fn(d) { d.constraint == "pattern" }))
}

test "format carried by JSON Schema, dropped by SQL and GraphQL" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, check=@moonmodel.Check::new(format="email")),
  ])
  let (js, _) = project_json_schema(m, [])
  let (_, sql_drops) = project_sql(m)
  let (_, gql_drops) = project_graphql(m, [])
  assert_true(js.contains("email"))
  assert_true(sql_drops.any(fn(d) { d.constraint == "format" }))
  assert_true(gql_drops.any(fn(d) { d.constraint == "format" }))
}

test "options carried by JSON Schema and SQL, dropped by GraphQL" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, check=@moonmodel.Check::new(options=[
      Json::string("a"), Json::string("b"),
    ])),
  ])
  let (js, _) = project_json_schema(m, [])
  let (sql, _) = project_sql(m)
  let (_, gql_drops) = project_graphql(m, [])
  assert_true(js.contains("enum"))
  assert_true(sql.contains("IN"))
  assert_true(gql_drops.any(fn(d) { d.constraint == "options" }))
}

test "distinct carried by JSON Schema, dropped by SQL and GraphQL" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", List(Text), check=@moonmodel.Check::new(distinct=true)),
  ])
  let (js, _) = project_json_schema(m, [])
  let (_, sql_drops) = project_sql(m)
  let (_, gql_drops) = project_graphql(m, [])
  assert_true(js.contains("uniqueItems"))
  assert_true(sql_drops.any(fn(d) { d.constraint == "distinct" }))
  assert_true(gql_drops.any(fn(d) { d.constraint == "distinct" }))
}

test "unique dropped by JSON Schema, OpenAPI, GraphQL; carried by SQL" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, check=@moonmodel.Check::new(unique=true)),
  ])
  let (sql, sql_drops) = project_sql(m)
  let (_, js_drops) = project_json_schema(m, [])
  let (_, gql_drops) = project_graphql(m, [])
  assert_true(sql.contains("UNIQUE"))
  assert_eq(sql_drops.length(), 0, msg="SQL carries unique")
  assert_true(js_drops.any(fn(d) { d.constraint == "unique" }))
  assert_true(gql_drops.any(fn(d) { d.constraint == "unique" }))
}

// ---- Boundary values ----

test "zero and negative bounds are preserved" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Real, check=@moonmodel.Check::new(least=0.0, under=0.0)),
  ])
  let (js, _) = project_json_schema(m, [])
  assert_true(js.contains("minimum"))
  assert_true(js.contains("exclusiveMaximum"))
}

test "very large longest value is preserved" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, check=@moonmodel.Check::new(longest=999999)),
  ])
  let (js, _) = project_json_schema(m, [])
  assert_true(js.contains("999999"))
}

test "single-character pattern is valid" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, check=@moonmodel.Check::new(pattern="a")),
  ])
  let (js, _) = project_json_schema(m, [])
  assert_true(js.contains("pattern"))
}

test "empty options array produces no enum" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, check=@moonmodel.Check::new(options=[])),
  ])
  let (js, _) = project_json_schema(m, [])
  assert_false(js.contains("enum"))
}

// ---- Dialect matrix: every SQL dialect x every basic type ----

test "SQL dialect matrix: Bool/Int/Big/Real/Text/Bytes/Stamp across 3 dialects" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Bool),
    @moonmodel.Field::new("b", Int),
    @moonmodel.Field::new("c", Big),
    @moonmodel.Field::new("d", Real),
    @moonmodel.Field::new("e", Text),
    @moonmodel.Field::new("f", Bytes),
    @moonmodel.Field::new("g", Stamp),
  ])
  // Postgres
  let (pg, pg_d) = project_sql(m, dialect="Postgres")
  assert_true(pg.contains("BOOLEAN"))
  assert_true(pg.contains("INTEGER"))
  assert_true(pg.contains("BIGINT"))
  assert_true(pg.contains("DOUBLE PRECISION"))
  assert_true(pg.contains("TEXT"))
  assert_true(pg.contains("BYTEA"))
  assert_true(pg.contains("TIMESTAMPTZ"))
  assert_eq(pg_d.length(), 0, msg="all basic types fit Postgres")
  // Sqlite
  let (lite, lite_d) = project_sql(m, dialect="Sqlite")
  assert_true(lite.contains("INTEGER"))
  assert_true(lite.contains("REAL"))
  assert_true(lite.contains("TEXT"))
  assert_true(lite.contains("BLOB"))
  assert_eq(lite_d.length(), 0, msg="all basic types fit SQLite")
  // Mysql
  let (my, my_d) = project_sql(m, dialect="Mysql")
  assert_true(my.contains("TINYINT(1)"))
  assert_true(my.contains("INT"))
  assert_true(my.contains("BIGINT"))
  assert_true(my.contains("DOUBLE"))
  assert_true(my.contains("TEXT"))
  assert_true(my.contains("BLOB"))
  assert_true(my.contains("DATETIME"))
  assert_eq(my_d.length(), 0, msg="all basic types fit MySQL")
}

test "OpenAPI dialect matrix: nullable representation differs" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Text, nullable=true),
  ])
  let (oa30, _) = project_openapi(m, dialect="OpenApi30")
  let (oa31, _) = project_openapi(m, dialect="OpenApi31")
  let (sw20, _) = project_openapi(m, dialect="Swagger20")
  assert_true(oa30.contains("nullable"))
  assert_true(oa31.contains("null"))
  assert_true(sw20.contains("x-nullable"))
}

test "OpenAPI dialect matrix: exclusive bounds differ" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("x", Real, check=@moonmodel.Check::new(over=0.0)),
  ])
  let (oa30, _) = project_openapi(m, dialect="OpenApi30")
  let (oa31, _) = project_openapi(m, dialect="OpenApi31")
  assert_true(oa31.contains("exclusiveMinimum"))
  // 3.0 rewrites exclusive to boolean form
  assert_true(oa30.contains("exclusiveMinimum") || oa30.contains("true"))
}

// ---- Field-level drops for complex types ----

test "Dict dropped by SQL and GraphQL in all dialects" {
  let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("meta", Dict(Text))])
  for d in ["Postgres", "Sqlite", "Mysql"] {
    let (_, drops) = project_sql(m, dialect=d)
    assert_true(drops.any(fn(x) { x.field == "meta" }), msg="Dict dropped in " + d)
  }
  let (_, gql_d) = project_graphql(m, [])
  assert_true(gql_d.any(fn(x) { x.field == "meta" }), msg="Dict dropped in GraphQL")
}

test "List dropped by SQLite and MySQL but carried by Postgres" {
  let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("tags", List(Text))])
  let (_, pg_d) = project_sql(m, dialect="Postgres")
  let (_, lite_d) = project_sql(m, dialect="Sqlite")
  let (_, my_d) = project_sql(m, dialect="Mysql")
  assert_eq(pg_d.length(), 0, msg="List fits Postgres")
  assert_true(lite_d.any(fn(x) { x.field == "tags" }), msg="List dropped in SQLite")
  assert_true(my_d.any(fn(x) { x.field == "tags" }), msg="List dropped in MySQL")
}

test "Any type dropped by SQL and GraphQL" {
  let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("x", Any)])
  let (_, sql_d) = project_sql(m)
  let (_, gql_d) = project_graphql(m, [])
  assert_true(sql_d.any(fn(x) { x.field == "x" }))
  assert_true(gql_d.any(fn(x) { x.field == "x" }))
}

// ---- Default values ----

test "default values appear in JSON Schema and SQL" {
  let m = @moonmodel.Model::new("T", [
    @moonmodel.Field::new("a", Text, default=Json::string("hello")),
    @moonmodel.Field::new("b", Int, default=Json::number(42.0)),
    @moonmodel.Field::new("c", Bool, default=Json::boolean(true)),
  ])
  let (js, _) = project_json_schema(m, [])
  let (sql, _) = project_sql(m)
  assert_true(js.contains("\"hello\""))
  assert_true(js.contains("42"))
  assert_true(js.contains("true"))
  assert_true(sql.contains("DEFAULT"))
  assert_true(sql.contains("'hello'"))
}

// ---- Multiple fields ----

test "model with 10 fields produces all fields in all targets" {
  let fields = []
  for i = 0; i < 10; i = i + 1 {
    fields.push(@moonmodel.Field::new("field_\{i}", Text))
  }
  let m = @moonmodel.Model::new("Big", fields)
  let (js, _) = project_json_schema(m, [])
  let (sql, _) = project_sql(m)
  for i = 0; i < 10; i = i + 1 {
    assert_true(js.contains("field_\{i}"), msg="field_\{i} in JSON Schema")
    assert_true(sql.contains("field_\{i}"), msg="field_\{i} in SQL")
  }
}

// ---- Preset integrity ----

test "User preset fields match expected names and types" {
  let user = preset_by_name("User").unwrap()
  assert_eq(user.fields.length(), 11)
  assert_eq(user.fields[0].name, "id")
  assert_eq(user.fields[1].name, "name")
  assert_eq(user.fields[2].name, "email")
  let _ = project_all(user, presets())
}

test "Order preset references User and Address" {
  let order = preset_by_name("Order").unwrap()
  let mentions = order.mentions()
  assert_true(mentions.contains("User"))
  assert_true(mentions.contains("Address"))
}

test "Address preset has country with length constraint" {
  let addr = preset_by_name("Address").unwrap()
  let country = addr.field("country").unwrap()
  assert_eq(country.check.shortest, Some(2))
  assert_eq(country.check.longest, Some(2))
}

// ---- ABI round-trip ----

test "parse_input with full model JSON reconstructs fields correctly" {
  let input_json = "{\"name\":\"User\",\"doc\":\"test\",\"fields\":[{\"name\":\"id\",\"kind\":\"Big\",\"required\":true,\"nullable\":false,\"doc\":\"ID\",\"default\":null,\"check\":{\"unique\":true}},{\"name\":\"tags\",\"kind\":{\"list\":\"Text\"},\"required\":false,\"nullable\":false,\"doc\":\"\",\"default\":null,\"check\":{\"distinct\":true,\"longest\":10}}],\"known\":[{\"name\":\"Address\",\"doc\":\"\",\"fields\":[{\"name\":\"line\",\"kind\":\"Text\",\"required\":true,\"nullable\":false,\"doc\":\"\",\"default\":null,\"check\":{}}]}]}"
  let input = parse_input(input_json)
  assert_eq(input.model.name, "User")
  assert_eq(input.model.fields.length(), 2)
  assert_eq(input.model.fields[0].name, "id")
  assert_eq(input.model.fields[0].check.unique, true)
  assert_eq(input.model.fields[1].name, "tags")
  assert_eq(input.known.length(), 1)
  assert_eq(input.known[0].name, "Address")
}

test "parse_input with empty fields list works" {
  let input = parse_input("{\"name\":\"Empty\",\"doc\":\"\",\"fields\":[]}")
  assert_eq(input.model.name, "Empty")
  assert_eq(input.model.fields.length(), 0)
}

test "parse_input with malformed JSON returns empty model" {
  let input = parse_input("not json at all")
  assert_eq(input.model.name, "")
}

// ---- TypeScript / Zod / Prisma codegen ----

test "TypeScript projection produces valid interface" {
  let m = @moonmodel.Model::new("User", [
    @moonmodel.Field::new("id", Big),
    @moonmodel.Field::new("name", Text),
    @moonmodel.Field::new("age", Int, required=false),
    @moonmodel.Field::new("active", Bool),
    @moonmodel.Field::new("tags", List(Text), required=false),
    @moonmodel.Field::new("meta", Dict(Text), required=false),
    @moonmodel.Field::new("home", Ref("Address"), required=false),
  ])
  let known = [@moonmodel.Model::new("Address", [@moonmodel.Field::new("line", Text)])]
  let ts = project_typescript(m, known)
  assert_true(ts.contains("export interface User {"))
  assert_true(ts.contains("export interface Address {"))
  assert_true(ts.contains("id: number"))
  assert_true(ts.contains("name: string"))
  assert_true(ts.contains("age?: number"))
  assert_true(ts.contains("tags?: string[]"))
  assert_true(ts.contains("home?: Address"))
}

test "Zod projection produces valid schema" {
  let m = @moonmodel.Model::new("User", [
    @moonmodel.Field::new("id", Big),
    @moonmodel.Field::new("name", Text),
    @moonmodel.Field::new("avatar", Bytes, nullable=true, required=false),
  ])
  let zod = project_zod(m, [])
  assert_true(zod.contains("import { z }"))
  assert_true(zod.contains("export const UserSchema = z.object({"))
  assert_true(zod.contains("z.number().int()"))
  assert_true(zod.contains("z.string()"))
  assert_true(zod.contains(".optional()"))
  assert_true(zod.contains(".nullable()"))
  assert_true(zod.contains("export type User = z.infer"))
}

test "Prisma projection produces valid model" {
  let m = @moonmodel.Model::new("User", [
    @moonmodel.Field::new("id", Big, check=@moonmodel.Check::new(unique=true)),
    @moonmodel.Field::new("name", Text),
    @moonmodel.Field::new("created", Stamp),
  ])
  let prisma = project_prisma(m, [])
  assert_true(prisma.contains("model User {"))
  assert_true(prisma.contains("id BigInt @unique"))
  assert_true(prisma.contains("name String"))
  assert_true(prisma.contains("created DateTime"))
}

test "TypeScript Nest type inlines fields" {
  let nested = @moonmodel.Model::new("", [@moonmodel.Field::new("city", Text)])
  let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("addr", Nest(nested))])
  let ts = project_typescript(m, [])
  assert_true(ts.contains("city: string"))
}

test "Prisma List type uses array syntax" {
  let m = @moonmodel.Model::new("T", [@moonmodel.Field::new("tags", List(Text))])
  let prisma = project_prisma(m, [])
  assert_true(prisma.contains("tags String[]"))
}

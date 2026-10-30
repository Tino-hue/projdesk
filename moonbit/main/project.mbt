// Projection pipeline using the Projector trait

///|
/// Full result of all projections
pub(all) struct ProjectionResult {
  json_schema : String
  openapi : String
  sql : String
  graphql : String
  typescript : String
  zod : String
  prisma : String
  drops_json : Array[DropReason]
  drops_open : Array[DropReason]
  drops_sql : Array[DropReason]
  drops_gql : Array[DropReason]
  drops_ts : Array[DropReason]
  drops_zod : Array[DropReason]
  drops_prisma : Array[DropReason]
}

///|
/// Parse OpenAPI dialect
fn parse_open_dialect(s : String) -> @open.Dialect {
  match s {
    "Swagger20" => Swagger20
    "OpenApi31" => OpenApi31
    _ => OpenApi30
  }
}

///|
/// Parse SQL dialect
fn parse_sql_dialect(s : String) -> @sql.Dialect {
  match s {
    "Sqlite" => Sqlite
    "Mysql" => Mysql
    _ => Postgres
  }
}

///|
/// Run all projections using the Projector trait
pub fn project_all(
  model : @moonmodel.Model,
  known : Array[@moonmodel.Model],
  openapi_dialect~ : String = "OpenApi30",
  sql_dialect~ : String = "Postgres",
) -> ProjectionResult {
  // Use Projector trait implementations
  let json_p = JsonProjector::{ }
  let open_p = OpenApiProj::{ dialect: parse_open_dialect(openapi_dialect), }
  let sql_p = SqlProj::{ dialect: parse_sql_dialect(sql_dialect), }
  let gql_p = GraphqlProj::{ }
  let ts_p = TsProjector::{ }
  let zod_p = ZodProjector::{ }
  let prisma_p = PrismaProjector::{ }

  let (json_text, drops_json) = json_p.project(model, known)
  let (open_text, drops_open) = open_p.project(model, known)
  let (sql_text, drops_sql) = sql_p.project(model, known)
  let (gql_text, drops_gql) = gql_p.project(model, known)
  let (ts_text, drops_ts) = ts_p.project(model, known)
  let (zod_text, drops_zod) = zod_p.project(model, known)
  let (prisma_text, drops_prisma) = prisma_p.project(model, known)

  {
    json_schema: json_text,
    openapi: open_text,
    sql: sql_text,
    graphql: gql_text,
    typescript: ts_text,
    zod: zod_text,
    prisma: prisma_text,
    drops_json,
    drops_open,
    drops_sql,
    drops_gql,
    drops_ts,
    drops_zod,
    drops_prisma,
  }
}

///|
/// One dropped constraint as it goes on the wire
priv struct WireDrop {
  field : String
  constraint : String
  why : String
} derive(ToJson)

///|
/// The drop report of every target as it goes on the wire
priv struct WireDrops {
  jsonSchema : Array[WireDrop]
  openapi : Array[WireDrop]
  sql : Array[WireDrop]
  graphql : Array[WireDrop]
  typescript : Array[WireDrop]
  zod : Array[WireDrop]
  prisma : Array[WireDrop]
} derive(ToJson)

///|
/// Build the per-target drop report as JSON
pub fn drops_map_to_json(result : ProjectionResult) -> Json {
  ToJson::to_json(WireDrops::{
    jsonSchema: drop_reasons_to_json(result.drops_json),
    openapi: drop_reasons_to_json(result.drops_open),
    sql: drop_reasons_to_json(result.drops_sql),
    graphql: drop_reasons_to_json(result.drops_gql),
    typescript: drop_reasons_to_json(result.drops_ts),
    zod: drop_reasons_to_json(result.drops_zod),
    prisma: drop_reasons_to_json(result.drops_prisma),
  })
}

///|
/// Convert DropReason list to JSON-compatible format
pub fn drops_to_json(drops : Array[DropReason]) -> Json {
  ToJson::to_json(drop_reasons_to_json(drops))
}

///|
fn drop_reasons_to_json(drops : Array[DropReason]) -> Array[WireDrop] {
  let arr : Array[WireDrop] = []
  for d in drops {
    arr.push(WireDrop::{
      field: d.field(),
      constraint: d.constraint(),
      why: d.to_text(),
    })
  }
  arr
}

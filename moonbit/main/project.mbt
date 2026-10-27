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
  openapi_dialect? : String = "OpenApi30",
  sql_dialect? : String = "Postgres",
) -> ProjectionResult {
  // Use Projector trait implementations
  let json_p = JsonProjector::{ }
  let open_p = OpenApiProj::{ dialect: parse_open_dialect(openapi_dialect), }
  let sql_p = SqlProj::{ dialect: parse_sql_dialect(sql_dialect), }
  let gql_p = GraphqlProj::{ }

  let (json_text, drops_json) = json_p.project(model, known)
  let (open_text, drops_open) = open_p.project(model, known)
  let (sql_text, drops_sql) = sql_p.project(model, known)
  let (gql_text, drops_gql) = gql_p.project(model, known)

  // Codegen projections (TypeScript / Zod / Prisma)
  let ts_text = project_typescript(model, known)
  let zod_text = project_zod(model, known)
  let prisma_text = project_prisma(model, known)

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
  }
}

///|
/// Convert DropReason list to JSON-compatible format
pub fn drops_to_json(drops : Array[DropReason]) -> Json {
  let arr : Array[Json] = []
  for d in drops {
    let m : Map[String, Json] = Map([])
    m["field"] = Json::string(d.field())
    m["constraint"] = Json::string(d.constraint())
    m["why"] = Json::string(d.to_text())
    arr.push(Json::object(m))
  }
  Json::array(arr)
}

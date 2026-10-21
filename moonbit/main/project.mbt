// Projection pipeline: one moonmodel.Model -> four outputs + drop reports

///|
/// Full result of all four projections
pub(all) struct ProjectionResult {
  json_schema : String
  openapi : String
  sql : String
  graphql : String
  drops_json : Array[DropReason]
  drops_open : Array[DropReason]
  drops_sql : Array[DropReason]
  drops_gql : Array[DropReason]
}

///|
/// Parse OpenAPI dialect string to enum
fn parse_open_dialect(s : String) -> @open.Dialect {
  match s {
    "Swagger20" => Swagger20
    "OpenApi31" => OpenApi31
    _ => OpenApi30
  }
}

///|
/// Parse SQL dialect string to enum
fn parse_sql_dialect(s : String) -> @sql.Dialect {
  match s {
    "Sqlite" => Sqlite
    "Mysql" => Mysql
    _ => Postgres
  }
}

///|
/// Run all four projections with dialect options
pub fn project_all(
  model : @moonmodel.Model,
  known : Array[@moonmodel.Model],
  openapi_dialect~ : String = "OpenApi30",
  sql_dialect~ : String = "Postgres",
) -> ProjectionResult {
  // JSON Schema 2020-12
  let json_doc = @json.document(model, known~)
  let json_text = json_doc.stringify(indent=2)
  let dj = drops_json_schema(model)
  // OpenAPI Schema Object
  let od = parse_open_dialect(openapi_dialect)
  let open_schema = @open.of(model, dialect=od)
  let open_text = open_schema.stringify(indent=2)
  let dopen = drops_openapi(model)
  // SQL DDL
  let sd = parse_sql_dialect(sql_dialect)
  let sql_text = @sql.table(model, dialect=sd)
  let (_cols, sql_skipped) = @sql.of(model, dialect=sd)
  let dsql = drops_sql(model, sql_skipped)
  // GraphQL SDL
  let all_models : Array[@moonmodel.Model] = [model]
  for k in known {
    all_models.push(k)
  }
  let gql_text = @sdl.document(all_models[:])
  let (_s, gql_skipped) = @sdl.of(model)
  let dgql = drops_graphql(model, gql_skipped)
  {
    json_schema: json_text,
    openapi: open_text,
    sql: sql_text,
    graphql: gql_text,
    drops_json: dj,
    drops_open: dopen,
    drops_sql: dsql,
    drops_gql: dgql,
  }
}

///|
/// JSON Schema 2020-12 projection
pub fn project_json_schema(
  model : @moonmodel.Model,
  known : Array[@moonmodel.Model],
) -> (String, Array[DropReason]) {
  let doc = @json.document(model, known~)
  (doc.stringify(indent=2), drops_json_schema(model))
}

///|
/// OpenAPI projection with dialect
pub fn project_openapi(
  model : @moonmodel.Model,
  dialect~ : String = "OpenApi30",
) -> (String, Array[DropReason]) {
  let od = parse_open_dialect(dialect)
  let schema = @open.of(model, dialect=od)
  (schema.stringify(indent=2), drops_openapi(model))
}

///|
/// SQL projection with dialect
pub fn project_sql(
  model : @moonmodel.Model,
  dialect~ : String = "Postgres",
) -> (String, Array[DropReason]) {
  let sd = parse_sql_dialect(dialect)
  let ddl = @sql.table(model, dialect=sd)
  let (_cols, skipped) = @sql.of(model, dialect=sd)
  (ddl, drops_sql(model, skipped))
}

///|
/// GraphQL SDL projection
pub fn project_graphql(
  model : @moonmodel.Model,
  known : Array[@moonmodel.Model],
) -> (String, Array[DropReason]) {
  let all : Array[@moonmodel.Model] = [model]
  for k in known {
    all.push(k)
  }
  let text = @sdl.document(all[:])
  let (_s, skipped) = @sdl.of(model)
  (text, drops_graphql(model, skipped))
}

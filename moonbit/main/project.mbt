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
/// Run all four projections
pub fn project_all(
  model : @moonmodel.Model,
  known : Array[@moonmodel.Model],
) -> ProjectionResult {
  // JSON Schema 2020-12
  let json_doc = @json.document(model, known~)
  let json_text = json_doc.stringify(indent=2)
  let dj = drops_json_schema(model)
  // OpenAPI 3.0 Schema Object
  let open_schema = @open.of(model, dialect=OpenApi30)
  let open_text = open_schema.stringify(indent=2)
  let dopen = drops_openapi(model)
  // SQL DDL (Postgres)
  let sql_text = @sql.table(model, dialect=Postgres)
  let (_cols, sql_skipped) = @sql.of(model, dialect=Postgres)
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

// ---- Pluggable projector functions (bonus: each returns text + drop list) ----

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
/// OpenAPI 3.0 Schema Object projection
pub fn project_openapi(
  model : @moonmodel.Model,
) -> (String, Array[DropReason]) {
  let schema = @open.of(model, dialect=OpenApi30)
  (schema.stringify(indent=2), drops_openapi(model))
}

///|
/// SQL DDL (Postgres) projection
pub fn project_sql(
  model : @moonmodel.Model,
) -> (String, Array[DropReason]) {
  let ddl = @sql.table(model, dialect=Postgres)
  let (_cols, skipped) = @sql.of(model, dialect=Postgres)
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

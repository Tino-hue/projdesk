// Drop-reason analysis: honestly report constraints each projection target cannot carry

///|
/// One dropped constraint and why
pub(all) struct DropReason {
  field : String
  constraint : String
  why : String
} derive(Eq, @debug.Debug)

///|
pub extend DropReason with Eq::{equal, not_equal}

///|
pub extend DropReason with Debug::{to_repr}

///|
/// Drops for JSON Schema 2020-12
pub fn drops_json_schema(model : @moonmodel.Model) -> Array[DropReason] {
  let out : Array[DropReason] = []
  for field in model.fields {
    if field.check.unique {
      out.push({
        field: field.name,
        constraint: "unique",
        why: "JSON Schema only has uniqueItems (within one array); it cannot express record-level unique",
      })
    }
  }
  out
}

///|
/// Drops for OpenAPI Schema Object
pub fn drops_openapi(model : @moonmodel.Model) -> Array[DropReason] {
  let out : Array[DropReason] = []
  for field in model.fields {
    if field.check.unique {
      out.push({
        field: field.name,
        constraint: "unique",
        why: "OpenAPI Schema Object has no record-level unique; only uniqueItems",
      })
    }
  }
  out
}

///|
/// Drops for SQL DDL
pub fn drops_sql(
  model : @moonmodel.Model,
  skipped : Array[@sql.Skipped],
) -> Array[DropReason] {
  let out : Array[DropReason] = []
  for s in skipped {
    out.push({ field: s.field, constraint: "(field)", why: s.why })
  }
  for field in model.fields {
    let field_skipped = skipped.any(fn(s) { s.field == field.name })
    if field_skipped {
      continue
    }
    let c = field.check
    if c.pattern is Some(_) {
      out.push({
        field: field.name,
        constraint: "pattern",
        why: "SQL CHECK does not use regex (each dialect has different operators); validate in application layer",
      })
    }
    if c.format is Some(_) {
      out.push({
        field: field.name,
        constraint: "format",
        why: "format is documentation semantics (e.g. email/uuid); SQL has no such constraint",
      })
    }
    if c.step is Some(_) {
      out.push({
        field: field.name,
        constraint: "step",
        why: "SQL has no multipleOf predicate; validate in application layer",
      })
    }
    if c.distinct {
      out.push({
        field: field.name,
        constraint: "distinct",
        why: "distinct is about list items; SQL unique is row-level, different semantics",
      })
    }
  }
  out
}

///|
/// Drops for GraphQL SDL
pub fn drops_graphql(
  model : @moonmodel.Model,
  skipped : Array[@sdl.Skipped],
) -> Array[DropReason] {
  let out : Array[DropReason] = []
  for s in skipped {
    out.push({ field: s.field, constraint: "(field)", why: s.why })
  }
  for field in model.fields {
    let field_skipped = skipped.any(fn(s) { s.field == field.name })
    if field_skipped {
      continue
    }
    let c = field.check
    if c.least is Some(_) {
      out.push({ field: field.name, constraint: "least", why: "GraphQL SDL only declares types and nullability; it cannot carry numeric bounds" })
    }
    if c.most is Some(_) {
      out.push({ field: field.name, constraint: "most", why: "GraphQL SDL only declares types and nullability; it cannot carry numeric bounds" })
    }
    if c.over is Some(_) {
      out.push({ field: field.name, constraint: "over", why: "GraphQL SDL only declares types and nullability; it cannot carry numeric bounds" })
    }
    if c.under is Some(_) {
      out.push({ field: field.name, constraint: "under", why: "GraphQL SDL only declares types and nullability; it cannot carry numeric bounds" })
    }
    if c.step is Some(_) {
      out.push({ field: field.name, constraint: "step", why: "GraphQL SDL cannot carry multipleOf constraint" })
    }
    if c.shortest is Some(_) {
      out.push({ field: field.name, constraint: "shortest", why: "GraphQL SDL cannot carry length constraints" })
    }
    if c.longest is Some(_) {
      out.push({ field: field.name, constraint: "longest", why: "GraphQL SDL cannot carry length constraints" })
    }
    if c.pattern is Some(_) {
      out.push({ field: field.name, constraint: "pattern", why: "GraphQL SDL cannot carry regex constraints" })
    }
    if c.format is Some(_) {
      out.push({ field: field.name, constraint: "format", why: "GraphQL SDL cannot carry format constraints" })
    }
    if c.options.length() > 0 {
      out.push({ field: field.name, constraint: "options", why: "GraphQL SDL can express closed sets as enum types, but moonmodel projection does not auto-generate enums" })
    }
    if c.distinct {
      out.push({ field: field.name, constraint: "distinct", why: "GraphQL SDL cannot carry list dedup constraints" })
    }
    if c.unique {
      out.push({ field: field.name, constraint: "unique", why: "GraphQL SDL cannot carry record-level unique constraints" })
    }
  }
  out
}

///|
/// Serialize DropReason list to JSON array
pub fn drops_to_json(drops : Array[DropReason]) -> Json {
  let arr : Array[Json] = []
  for d in drops {
    let m : Map[String, Json] = Map([])
    m["field"] = Json::string(d.field)
    m["constraint"] = Json::string(d.constraint)
    m["why"] = Json::string(d.why)
    arr.push(Json::object(m))
  }
  Json::array(arr)
}

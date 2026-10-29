// DSL Codegen: AST -> moonmodel.Model
// Converts parsed DSL into moonmodel types for projection

///|
/// Convert AstType to moonmodel.Type
fn ast_type_to_moon(t : AstType) -> @moonmodel.Type {
  match t {
    Named(s) =>
      match s {
        "Bool" => Bool
        "Int" => Int
        "Big" => Big
        "Real" => Real
        "Text" => Text
        "Bytes" => Bytes
        "Stamp" => Stamp
        "Any" => Any
        _ => Text
      }
    ListOf(inner) => List(ast_type_to_moon(inner))
    DictOf(inner) => Dict(ast_type_to_moon(inner))
    RefTo(name) => Ref(name)
    Nested(model) => Nest(ast_model_to_moon(model))
  }
}

///|
/// Convert AstCheck array to moonmodel.Check
fn ast_checks_to_moon(checks : Array[AstCheck]) -> @moonmodel.Check {
  let mut least = None
  let mut most = None
  let mut over = None
  let mut under = None
  let mut step = None
  let mut shortest = None
  let mut longest = None
  let mut pattern = None
  let mut format = None
  let mut options : Array[Json] = []
  let mut distinct = false
  let mut unique = false
  for c in checks {
    match c {
      Least(b) => least = b.value
      Most(b) => most = b.value
      Over(b) => over = b.value
      Under(b) => under = b.value
      Step(b) => step = b.value
      Shortest(b) => shortest = b.value.map(fn(v) { v.to_int() })
      Longest(b) => longest = b.value.map(fn(v) { v.to_int() })
      Pattern(s) => pattern = Some(s)
      Format(s) => format = Some(s)
      Options(vals) => {
        options = []
        for v in vals {
          options.push(Json::string(v))
        }
      }
      Distinct => distinct = true
      Unique => unique = true
    }
  }
  {
    least,
    most,
    over,
    under,
    step,
    shortest,
    longest,
    pattern,
    format,
    options,
    distinct,
    unique,
  }
}

///|
/// Convert AstField to moonmodel.Field
fn ast_field_to_moon(f : AstField) -> @moonmodel.Field {
  let kind = ast_type_to_moon(f.kind)
  let check = ast_checks_to_moon(f.checks)
  @moonmodel.Field::new(
    f.name,
    kind,
    required=f.required,
    nullable=f.nullable,
    doc=f.doc,
    check~,
  )
}

///|
/// Convert AstModel to moonmodel.Model
fn ast_model_to_moon(m : AstModel) -> @moonmodel.Model {
  let fields = m.fields.map(ast_field_to_moon)
  @moonmodel.Model::new(m.name, fields, doc=m.doc)
}

///|
/// Convert parsed DSL models to moonmodel.Model array
/// Returns the first model as primary, rest as known references
pub fn dsl_to_models(
  models : Array[AstModel],
) -> (@moonmodel.Model, Array[@moonmodel.Model]) {
  if models.length() == 0 {
    return (@moonmodel.Model::new("", []), [])
  }
  let primary = ast_model_to_moon(models[0])
  let known = []
  for i = 1; i < models.length(); i = i + 1 {
    known.push(ast_model_to_moon(models[i]))
  }
  (primary, known)
}

///|
/// Full pipeline: DSL source -> projections
/// Returns: (primary model text outputs, errors)
pub fn dsl_project(
  src : String,
  openapi_dialect~ : String = "OpenApi30",
  sql_dialect~ : String = "Postgres",
) -> (String, Array[String]) {
  let (models, lex_errors, parse_errors) = dsl_parse(src)
  let errors = []
  for e in lex_errors {
    errors.push(e.to_text())
  }
  for e in parse_errors {
    errors.push(e.to_text())
  }
  // A constraint bound that cannot be settled has no value to project, so the
  // source is rejected rather than projected without it.
  for p in resolve_all_bounds(models) {
    errors.push(p)
  }
  for m in models {
    for b in unresolved_bounds(m) {
      errors.push("constraint " + b + " could not be resolved")
    }
  }
  if errors.length() > 0 || models.length() == 0 {
    let err_msg = if errors.length() > 0 {
      errors[0]
    } else {
      "no models found in source"
    }
    let err_arr : Array[Json] = []
    for e in errors {
      err_arr.push(Json::string(e))
    }
    let out : Map[String, Json] = Map([])
    out["error"] = Json::string(err_msg)
    out["errors"] = Json::array(err_arr)
    out["jsonSchema"] = Json::string("")
    out["openapi"] = Json::string("")
    out["sql"] = Json::string("")
    out["graphql"] = Json::string("")
    out["typescript"] = Json::string("")
    out["zod"] = Json::string("")
    out["prisma"] = Json::string("")
    out["drops"] = Json::object(Map([]))
    return (Json::object(out).stringify(), errors)
  }
  let (primary, known) = dsl_to_models(models)
  let result = project_all(primary, known, openapi_dialect~, sql_dialect~)
  // Return JSON with all outputs
  let out : Map[String, Json] = Map([])
  out["jsonSchema"] = Json::string(result.json_schema)
  out["openapi"] = Json::string(result.openapi)
  out["sql"] = Json::string(result.sql)
  out["graphql"] = Json::string(result.graphql)
  out["typescript"] = Json::string(result.typescript)
  out["zod"] = Json::string(result.zod)
  out["prisma"] = Json::string(result.prisma)
  out["drops"] = drops_map_to_json(result)
  (Json::object(out).stringify(), errors)
}

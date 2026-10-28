// ProjDesk WASM API
//
// Compile: moon build --target wasm-gc --release
// JS instantiate: { builtins: ["js-string"], importedStringConstants: "_" }

///|
/// Main entry: run the seven projections from input JSON, return result JSON string
#export_name("project_from_json")
pub fn project_from_json(input_json : String) -> String {
  let input = parse_input(input_json)
  if input.model.name == "" {
    return error_json("input JSON missing model name")
  }
  let result = project_all(
    input.model,
    input.known,
    openapi_dialect=input.openapi_dialect,
    sql_dialect=input.sql_dialect,
  )
  result_to_json(result)
}

///|
/// Get preset models JSON (frontend calls this on startup)
#export_name("dsl_project")
pub fn dsl_project_entry(dsl : String) -> String {
  let (output, _errors) = dsl_project(dsl)
  output
}

///|
#export_name("solve_constraints")
pub fn solve_constraints_entry(model_json : String) -> String {
  let input = parse_input(model_json)
  solve_constraints(input.model)
}

///|
#export_name("generate_migration")
pub fn generate_migration_entry(old_json : String, new_json : String) -> String {
  let old_input = parse_input(old_json)
  let new_input = parse_input(new_json)
  generate_migration(old_input.model, new_input.model)
}

///|
#export_name("check_equivalence")
pub fn check_equivalence_entry(a_json : String, b_json : String) -> String {
  let a_input = parse_input(a_json)
  let b_input = parse_input(b_json)
  check_equivalence(a_input.model, b_input.model)
}

///|
#export_name("verify_roundtrip")
pub fn verify_roundtrip_entry(model_json : String) -> String {
  let input = parse_input(model_json)
  let result = roundtrip_model(input.model, input.known)
  roundtrip_result_to_json(
    result, "round-trip verified: model -> DSL -> parse preserves every field, type and constraint",
  )
}

///|
#export_name("verify_roundtrip_dsl")
pub fn verify_roundtrip_dsl_entry(dsl : String) -> String {
  let result = roundtrip_dsl(dsl)
  roundtrip_result_to_json(
    result, "round-trip verified: DSL -> AST -> DSL -> AST preserves every field, type and constraint",
  )
}

///|
/// Render a round-trip result as the ABI's JSON shape
fn roundtrip_result_to_json(result : RoundTrip, ok_message : String) -> String {
  let out : Map[String, Json] = Map([])
  match result {
    Pass => {
      out["ok"] = Json::boolean(true)
      out["message"] = Json::string(ok_message)
    }
    Fail(msg) => {
      out["ok"] = Json::boolean(false)
      out["message"] = Json::string(msg)
    }
  }
  Json::object(out).stringify()
}

///|
#export_name("check_semantics")
pub fn check_semantics_entry(dsl : String) -> String {
  let (models, lex_errors, parse_errors) = dsl_parse(dsl)
  if lex_errors.length() > 0 || parse_errors.length() > 0 {
    let out : Map[String, Json] = Map([])
    out["issue_count"] = Json::number(0.0)
    out["issues"] = Json::array([])
    out["parse_error"] = Json::string(
      if lex_errors.length() > 0 {
        lex_errors[0].to_text()
      } else {
        parse_errors[0].to_text()
      },
    )
    return Json::object(out).stringify()
  }
  check_semantics_json(models)
}

///|
#export_name("get_presets_json")
pub fn get_presets_json() -> String {
  let arr : Array[Json] = []
  for m in presets() {
    arr.push(model_to_json(m))
  }
  Json::array(arr).stringify()
}

///|
/// Serialize ProjectionResult to JSON string
fn result_to_json(result : ProjectionResult) -> String {
  let out : Map[String, Json] = Map([])
  out["ok"] = Json::boolean(true)
  out["jsonSchema"] = Json::string(result.json_schema)
  out["openapi"] = Json::string(result.openapi)
  out["sql"] = Json::string(result.sql)
  out["graphql"] = Json::string(result.graphql)
  out["typescript"] = Json::string(result.typescript)
  out["zod"] = Json::string(result.zod)
  out["prisma"] = Json::string(result.prisma)
  out["drops"] = drops_map_to_json(result)
  Json::object(out).stringify()
}

///|
/// Serialize Model to JSON (for preset export)
fn model_to_json(m : @moonmodel.Model) -> Json {
  let out : Map[String, Json] = Map([])
  out["name"] = Json::string(m.name)
  out["doc"] = Json::string(m.doc)
  let fields : Array[Json] = []
  for f in m.fields {
    fields.push(field_to_json(f))
  }
  out["fields"] = Json::array(fields)
  Json::object(out)
}

///|
fn field_to_json(f : @moonmodel.Field) -> Json {
  let out : Map[String, Json] = Map([])
  out["name"] = Json::string(f.name)
  out["kind"] = type_to_json(f.kind)
  out["required"] = Json::boolean(f.required)
  out["nullable"] = Json::boolean(f.nullable)
  out["doc"] = Json::string(f.doc)
  match f.default {
    Some(v) => out["default"] = v
    None => out["default"] = Json::null()
  }
  out["check"] = check_to_json(f.check)
  Json::object(out)
}

///|
fn type_to_json(t : @moonmodel.Type) -> Json {
  match t {
    Bool => Json::string("Bool")
    Int => Json::string("Int")
    Big => Json::string("Big")
    Real => Json::string("Real")
    Text => Json::string("Text")
    Bytes => Json::string("Bytes")
    Stamp => Json::string("Stamp")
    Any => Json::string("Any")
    List(inner) => {
      let m : Map[String, Json] = Map([])
      m["list"] = type_to_json(inner)
      Json::object(m)
    }
    Dict(inner) => {
      let m : Map[String, Json] = Map([])
      m["dict"] = type_to_json(inner)
      Json::object(m)
    }
    Ref(name) => {
      let m : Map[String, Json] = Map([])
      m["ref"] = Json::string(name)
      Json::object(m)
    }
    Nest(model) => {
      let m : Map[String, Json] = Map([])
      m["nest"] = model_to_json(model)
      Json::object(m)
    }
    Raw(j) => {
      let m : Map[String, Json] = Map([])
      m["raw"] = j
      Json::object(m)
    }
  }
}

///|
fn check_to_json(c : @moonmodel.Check) -> Json {
  let out : Map[String, Json] = Map([])
  match c.least {
    Some(v) => out["least"] = Json::number(v)
    None => ()
  }
  match c.most {
    Some(v) => out["most"] = Json::number(v)
    None => ()
  }
  match c.over {
    Some(v) => out["over"] = Json::number(v)
    None => ()
  }
  match c.under {
    Some(v) => out["under"] = Json::number(v)
    None => ()
  }
  match c.step {
    Some(v) => out["step"] = Json::number(v)
    None => ()
  }
  match c.shortest {
    Some(v) => out["shortest"] = Json::number(v.to_double())
    None => ()
  }
  match c.longest {
    Some(v) => out["longest"] = Json::number(v.to_double())
    None => ()
  }
  match c.pattern {
    Some(v) => out["pattern"] = Json::string(v)
    None => ()
  }
  match c.format {
    Some(v) => out["format"] = Json::string(v)
    None => ()
  }
  if c.options.length() > 0 {
    out["options"] = Json::array(c.options)
  }
  if c.distinct {
    out["distinct"] = Json::boolean(true)
  }
  if c.unique {
    out["unique"] = Json::boolean(true)
  }
  Json::object(out)
}

///|
fn error_json(msg : String) -> String {
  let out : Map[String, Json] = Map([])
  out["ok"] = Json::boolean(false)
  out["error"] = Json::string(msg)
  Json::object(out).stringify()
}

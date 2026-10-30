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
#export_name("dsl_to_model")
pub fn dsl_to_model_entry(dsl : String) -> String {
  let (models, lex_errors, parse_errors) = dsl_parse(dsl)
  if lex_errors.length() > 0 || parse_errors.length() > 0 {
    let msg = if lex_errors.length() > 0 {
      lex_errors[0].to_text()
    } else {
      parse_errors[0].to_text()
    }
    return error_json(msg)
  }
  let (primary, known) = dsl_to_models(models)
  let fields : Array[WireField] = []
  for f in primary.fields {
    fields.push(field_to_json(f))
  }
  let knowns : Array[WireModel] = []
  for k in known {
    knowns.push(model_to_json(k))
  }
  ToJson::to_json(WireCompiledModel::{
    name: primary.name,
    doc: primary.doc,
    fields,
    known: knowns,
  }).stringify()
}

///|
/// Render a round-trip result as the ABI's JSON shape
fn roundtrip_result_to_json(result : RoundTrip, ok_message : String) -> String {
  let json = match result {
    Pass =>
      ToJson::to_json(WireRoundTripResult::{
        ok: true,
        message: ok_message,
        reason: None,
        stage: None,
      })
    Fail(e) => {
      let stage = roundtrip_error_stage(e)
      ToJson::to_json(WireRoundTripResult::{
        ok: false,
        message: roundtrip_error_message(e),
        // The kind and the stage are there so a program can branch on them
        // instead of reading the message.
        reason: Some(roundtrip_error_kind(e)),
        stage: if stage == "" {
          None
        } else {
          Some(stage)
        },
      })
    }
  }
  json.stringify()
}

///|
#export_name("check_semantics")
pub fn check_semantics_entry(dsl : String) -> String {
  let (models, lex_errors, parse_errors) = dsl_parse(dsl)
  if lex_errors.length() > 0 || parse_errors.length() > 0 {
    return ToJson::to_json(WireSemanticsError::{
      issue_count: 0.0,
      issues: [],
      parse_error: if lex_errors.length() > 0 {
        lex_errors[0].to_text()
      } else {
        parse_errors[0].to_text()
      },
    }).stringify()
  }
  check_semantics_json(models)
}

///|
/// Check a JSON Schema for contradictions: does anything satisfy it at all?
#export_name("check_schema_satisfiability")
pub fn check_schema_satisfiability_entry(schema_json : String) -> String {
  check_json_schema_str(schema_json)
}

///|
#export_name("get_presets_json")
pub fn get_presets_json() -> String {
  let arr : Array[Json] = []
  for m in presets() {
    arr.push(ToJson::to_json(model_to_json(m)))
  }
  Json::array(arr).stringify()
}

///|
/// One model as it goes on the wire
priv struct WireModel {
  name : String
  doc : String
  fields : Array[WireField]
} derive(ToJson)

///|
/// One field as it goes on the wire
priv struct WireField {
  name : String
  kind : Json
  required : Bool
  nullable : Bool
  doc : String
  default : Json
  check : Json
} derive(ToJson)

///|
/// One constraint set as it goes on the wire. A constraint the model does not
/// carry is left out, which is what the projection does with it too.
priv struct WireCheck {
  least : Double?
  most : Double?
  over : Double?
  under : Double?
  step : Double?
  shortest : Double?
  longest : Double?
  pattern : String?
  format : String?
  options : Array[Json]?
  distinct : Bool?
  unique : Bool?
} derive(ToJson)

///|
/// The seven projections as they go on the wire
priv struct WireProjectionResult {
  ok : Bool
  jsonSchema : String
  openapi : String
  sql : String
  graphql : String
  typescript : String
  zod : String
  prisma : String
  drops : Json
} derive(ToJson)

///|
/// The round-trip verdict as it goes on the wire
priv struct WireRoundTripResult {
  ok : Bool
  message : String
  reason : String?
  stage : String?
} derive(ToJson)

///|
/// The semantic report as it goes on the wire
priv struct WireSemanticsError {
  issue_count : Double
  issues : Array[WireSemanticIssue]
  parse_error : String
} derive(ToJson)

///|
/// A model with its known models, as they go on the wire
priv struct WireCompiledModel {
  name : String
  doc : String
  fields : Array[WireField]
  known : Array[WireModel]
} derive(ToJson)

///|
/// An error as it goes on the wire
priv struct WireError {
  ok : Bool
  error : String
} derive(ToJson)

///|
/// Serialize ProjectionResult to JSON string
fn result_to_json(result : ProjectionResult) -> String {
  ToJson::to_json(WireProjectionResult::{
    ok: true,
    jsonSchema: result.json_schema,
    openapi: result.openapi,
    sql: result.sql,
    graphql: result.graphql,
    typescript: result.typescript,
    zod: result.zod,
    prisma: result.prisma,
    drops: drops_map_to_json(result),
  }).stringify()
}

///|
/// Serialize Model to JSON (for preset export)
fn model_to_json(m : @moonmodel.Model) -> WireModel {
  let fields : Array[WireField] = []
  for f in m.fields {
    fields.push(field_to_json(f))
  }
  WireModel::{ name: m.name, doc: m.doc, fields, }
}

///|
fn field_to_json(f : @moonmodel.Field) -> WireField {
  let default = match f.default {
    Some(v) => v
    None => Json::null()
  }
  WireField::{
    name: f.name,
    kind: type_to_json(f.kind),
    required: f.required,
    nullable: f.nullable,
    doc: f.doc,
    default,
    check: ToJson::to_json(check_to_json(f.check)),
  }
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
      m["nest"] = ToJson::to_json(model_to_json(model))
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
fn check_to_json(c : @moonmodel.Check) -> WireCheck {
  let shortest = match c.shortest {
    Some(v) => Some(v.to_double())
    None => None
  }
  let longest = match c.longest {
    Some(v) => Some(v.to_double())
    None => None
  }
  let options = if c.options.length() > 0 { Some(c.options) } else { None }
  let distinct = if c.distinct { Some(true) } else { None }
  let unique = if c.unique { Some(true) } else { None }
  WireCheck::{
    least: c.least,
    most: c.most,
    over: c.over,
    under: c.under,
    step: c.step,
    shortest,
    longest,
    pattern: c.pattern,
    format: c.format,
    options,
    distinct,
    unique,
  }
}

///|
fn error_json(msg : String) -> String {
  ToJson::to_json(WireError::{ ok: false, error: msg, }).stringify()
}

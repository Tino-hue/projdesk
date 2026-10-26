// Round-trip test framework: generate -> parse -> compare
// Formal verification of projection correctness

///|
/// Round-trip test result
pub(all) enum RoundTrip {
  Pass
  Fail(String)
} derive(Eq, Debug)

///|
pub extend RoundTrip with Eq::{equal, not_equal}

///|
pub extend RoundTrip with Debug::{to_repr}


///|

///|
/// Generate a DSL string from a moonmodel.Model
pub fn model_to_dsl_public(m : @moonmodel.Model) -> String {
  model_to_dsl(m)
}

///|
fn model_to_dsl(m : @moonmodel.Model) -> String {
  let out = StringBuilder()
  out.write_string("model " + m.name + " {\n")
  for f in m.fields {
    out.write_string("  " + f.name + ": ")
    out.write_string(type_to_dsl(f.kind))
    if !f.required {
      out.write_string(" @optional")
    }
    if f.nullable {
      out.write_string(" @nullable")
    }
    if f.check.unique {
      out.write_string(" @unique")
    }
    if f.check.distinct {
      out.write_string(" @distinct")
    }
    // Checks
    let check_parts = []
    match f.check.shortest {
      Some(v) => check_parts.push("shortest=" + v.to_string())
      None => ()
    }
    match f.check.longest {
      Some(v) => check_parts.push("longest=" + v.to_string())
      None => ()
    }
    match f.check.least {
      Some(v) => check_parts.push("least=" + v.to_string())
      None => ()
    }
    match f.check.most {
      Some(v) => check_parts.push("most=" + v.to_string())
      None => ()
    }
    if check_parts.length() > 0 {
      out.write_string(" [")
      for i = 0; i < check_parts.length(); i = i + 1 {
        if i > 0 {
          out.write_string(", ")
        }
        out.write_string(check_parts[i])
      }
      out.write_string("]")
    }
    out.write_string("\n")
  }
  out.write_string("}")
  out.to_string()
}

///|
/// Type to DSL string
fn type_to_dsl(t : @moonmodel.Type) -> String {
  match t {
    Bool => "Bool"
    Int => "Int"
    Big => "Big"
    Real => "Real"
    Text => "Text"
    Bytes => "Bytes"
    Stamp => "Stamp"
    Any => "Any"
    List(inner) => "List(" + type_to_dsl(inner) + ")"
    Dict(inner) => "Dict(" + type_to_dsl(inner) + ")"
    Ref(name) => "Ref(" + name + ")"
    Nest(_) => "Text" // simplified
    Raw(_) => "Text"
  }
}

///|
/// Round-trip: model -> DSL -> parse -> model -> compare
pub fn roundtrip_model(m : @moonmodel.Model) -> RoundTrip {
  // Generate DSL
  let dsl = model_to_dsl(m)
  // Parse back
  let (models, lex_errors, parse_errors) = dsl_parse(dsl)
  if lex_errors.length() > 0 {
    return Fail("lex errors in generated DSL")
  }
  if parse_errors.length() > 0 {
    return Fail("parse errors in generated DSL")
  }
  if models.length() != 1 {
    return Fail("expected 1 model, got " + models.length().to_string())
  }
  let (reconstructed, _) = dsl_to_models(models)
  // Compare field names
  if reconstructed.name != m.name {
    return Fail("name mismatch: " + m.name + " vs " + reconstructed.name)
  }
  if reconstructed.fields.length() != m.fields.length() {
    return Fail("field count mismatch")
  }
  for i = 0; i < m.fields.length(); i = i + 1 {
    let orig = m.fields[i]
    let rec = reconstructed.fields[i]
    if orig.name != rec.name {
      return Fail("field name mismatch at " + i.to_string())
    }
    if orig.required != rec.required {
      return Fail("required mismatch on " + orig.name)
    }
    if orig.nullable != rec.nullable {
      return Fail("nullable mismatch on " + orig.name)
    }
    if orig.check.unique != rec.check.unique {
      return Fail("unique mismatch on " + orig.name)
    }
    if orig.check.distinct != rec.check.distinct {
      return Fail("distinct mismatch on " + orig.name)
    }
  }
  Pass
}

///|
/// Round-trip: DSL string -> model -> DSL -> parse -> compare
pub fn roundtrip_dsl(dsl : String) -> RoundTrip {
  let (models, lex_errors, parse_errors) = dsl_parse(dsl)
  if lex_errors.length() > 0 {
    return Fail("lex errors in input DSL")
  }
  if parse_errors.length() > 0 {
    return Fail("parse errors in input DSL")
  }
  if models.length() == 0 {
    return Fail("no models in input DSL")
  }
  // Regenerate and reparse
  roundtrip_model(ast_model_to_moon(models[0]))
}

///|
/// Run multiple round-trip tests
pub fn run_roundtrips(models : Array[@moonmodel.Model]) -> String {
  let arr : Array[Json] = []
  let mut pass_count = 0
  for m in models {
    let result = roundtrip_model(m)
    let entry : Map[String, Json] = Map([])
    entry["model"] = Json::string(m.name)
    match result {
      Pass => {
        entry["result"] = Json::string("pass")
        pass_count = pass_count + 1
      }
      Fail(msg) => {
        entry["result"] = Json::string("fail")
        entry["error"] = Json::string(msg)
      }
    }
    arr.push(Json::object(entry))
  }
  let out : Map[String, Json] = Map([])
  out["results"] = Json::array(arr)
  out["passed"] = Json::number(pass_count.to_double())
  out["total"] = Json::number(models.length().to_double())
  Json::object(out).stringify()
}

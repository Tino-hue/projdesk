// ABI layer: frontend JSON <-> moonmodel.Model

///|
/// Parse Type from JSON
fn parse_type(j : Json) -> @moonmodel.Type {
  match j {
    String(s) =>
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
    Object(map) =>
      if map.get("list") is Some(inner) {
        List(parse_type(inner))
      } else if map.get("dict") is Some(inner) {
        Dict(parse_type(inner))
      } else if map.get("ref") is Some(String(name)) {
        Ref(name)
      } else if map.get("nest") is Some(nest_j) {
        Nest(parse_model(nest_j))
      } else if map.get("raw") is Some(raw) {
        Raw(raw)
      } else {
        Any
      }
    _ => Any
  }
}

///|
/// Parse Check from JSON
fn parse_check(j : Json?) -> @moonmodel.Check {
  match j {
    None => @moonmodel.check
    Some(Object(map)) => {
      let least = match map.get("least") {
        Some(Number(n, ..)) => Some(n)
        _ => None
      }
      let most = match map.get("most") {
        Some(Number(n, ..)) => Some(n)
        _ => None
      }
      let over = match map.get("over") {
        Some(Number(n, ..)) => Some(n)
        _ => None
      }
      let under = match map.get("under") {
        Some(Number(n, ..)) => Some(n)
        _ => None
      }
      let step = match map.get("step") {
        Some(Number(n, ..)) => Some(n)
        _ => None
      }
      let shortest = match map.get("shortest") {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
      let longest = match map.get("longest") {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
      let pattern = match map.get("pattern") {
        Some(String(s)) => Some(s)
        _ => None
      }
      let format = match map.get("format") {
        Some(String(s)) => Some(s)
        _ => None
      }
      let options = match map.get("options") {
        Some(Array(items)) => items
        _ => []
      }
      let distinct = match map.get("distinct") {
        Some(True) => true
        _ => false
      }
      let unique = match map.get("unique") {
        Some(True) => true
        _ => false
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
    Some(_) => @moonmodel.check
  }
}

///|
/// Parse Field from JSON
fn parse_field(j : Json) -> @moonmodel.Field {
  let map = match j {
    Object(m) => m
    _ => Map([])
  }
  let name = match map.get("name") {
    Some(String(s)) => s
    _ => ""
  }
  let kind = match map.get("kind") {
    Some(k) => parse_type(k)
    _ => Any
  }
  let required = match map.get("required") {
    Some(True) => true
    Some(False) => false
    _ => true
  }
  let nullable = match map.get("nullable") {
    Some(True) => true
    _ => false
  }
  let doc = match map.get("doc") {
    Some(String(s)) => s
    _ => ""
  }
  let default = match map.get("default") {
    Some(Null) | None => None
    Some(v) => Some(v)
  }
  let check = parse_check(map.get("check"))
  @moonmodel.Field::new(
    name,
    kind,
    required~,
    nullable~,
    doc~,
    default?,
    check~,
  )
}

///|
/// Parse Model from JSON
fn parse_model(j : Json) -> @moonmodel.Model {
  let map = match j {
    Object(m) => m
    _ => Map([])
  }
  let name = match map.get("name") {
    Some(String(s)) => s
    _ => ""
  }
  let doc = match map.get("doc") {
    Some(String(s)) => s
    _ => ""
  }
  let fields = match map.get("fields") {
    Some(Array(items)) => items.map(parse_field)
    _ => []
  }
  @moonmodel.Model::new(name, fields, doc~)
}

///|
/// Parsed input with dialect options
pub(all) struct Input {
  model : @moonmodel.Model
  known : Array[@moonmodel.Model]
  openapi_dialect : String
  sql_dialect : String
}

///|
/// Parse input JSON with optional dialect fields
pub fn parse_input(text : String) -> Input {
  let j = @jsonparse.parse_json(text)
  let map = match j {
    Object(m) => m
    _ => Map([])
  }
  let model = parse_model(j)
  let known = match map.get("known") {
    Some(Array(items)) => items.map(parse_model)
    _ => []
  }
  let openapi_dialect = match map.get("openapiDialect") {
    Some(String(s)) => s
    _ => "OpenApi30"
  }
  let sql_dialect = match map.get("sqlDialect") {
    Some(String(s)) => s
    _ => "Postgres"
  }
  { model, known, openapi_dialect, sql_dialect }
}

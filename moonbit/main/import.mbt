// Reverse import: parse JSON Schema into moonmodel.Model

///|
/// Parse a JSON Schema type string to moonmodel.Type
fn js_type_to_moon(s : String) -> @moonmodel.Type {
  match s {
    "boolean" => Bool
    "integer" => Int
    "number" => Real
    "string" => Text
    "array" => List(Any)
    "object" => Dict(Any)
    _ => Any
  }
}

///|
/// Extract last path segment from a $ref string
fn ref_to_name(ref_str : String) -> String {
  let mut name = ref_str
  let mut i = ref_str.length() - 1
  while i >= 0 {
    if ref_str[i] == '/' {
      name = ref_str[i+1:].to_string()
      break
    }
    i = i - 1
  }
  name
}

///|
/// Parse a JSON Schema property object to moonmodel.Type
fn parse_js_property(j : Json) -> @moonmodel.Type {
  match j {
    Object(map) => {
      if map.get("$ref") is Some(String(ref_str)) {
        return Ref(ref_to_name(ref_str))
      }
      // Get base type
      let mut base_type = "any"
      match map.get("type") {
        Some(String(s)) => base_type = s
        Some(Array(items)) => {
          for item in items {
            if item != Json::string("null") {
              match item {
                String(s) => {
                  base_type = s
                  break
                }
                _ => ()
              }
            }
          }
        }
        _ => ()
      }
      match base_type {
        "array" =>
          match map.get("items") {
            Some(items) => List(parse_js_property(items))
            None => List(Any)
          }
        "object" =>
          match map.get("additionalProperties") {
            Some(props) => Dict(parse_js_property(props))
            None => Dict(Any)
          }
        _ => js_type_to_moon(base_type)
      }
    }
    _ => Any
  }
}

///|
/// Parse a JSON Schema property's constraints to moonmodel.Check
fn parse_js_check(j : Json) -> @moonmodel.Check {
  match j {
    Object(map) => {
      let shortest = match map.get("minLength") {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
      let longest = match map.get("maxLength") {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
      let least = match map.get("minimum") {
        Some(Number(n, ..)) => Some(n)
        _ => None
      }
      let most = match map.get("maximum") {
        Some(Number(n, ..)) => Some(n)
        _ => None
      }
      let over = match map.get("exclusiveMinimum") {
        Some(Number(n, ..)) => Some(n)
        _ => None
      }
      let under = match map.get("exclusiveMaximum") {
        Some(Number(n, ..)) => Some(n)
        _ => None
      }
      let step = match map.get("multipleOf") {
        Some(Number(n, ..)) => Some(n)
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
      let options = match map.get("enum") {
        Some(Array(items)) => items
        _ => []
      }
      let distinct = match map.get("uniqueItems") {
        Some(True) => true
        _ => false
      }
      {
        least, most, over, under, step,
        shortest, longest,
        pattern, format,
        options, distinct,
        unique: false,
      }
    }
    _ => @moonmodel.check
  }
}

///|
/// Parse a JSON Schema object into a moonmodel.Model
pub fn import_from_json_schema(j : Json) -> @moonmodel.Model {
  let map = match j {
    Object(m) => m
    _ => Map([])
  }
  let name = match map.get("title") {
    Some(String(s)) => s
    _ => "Imported"
  }
  let doc = match map.get("description") {
    Some(String(s)) => s
    _ => ""
  }
  let required_list = match map.get("required") {
    Some(Array(items)) => {
      let out = []
      for item in items {
        match item {
          String(s) => out.push(s)
          _ => ()
        }
      }
      out
    }
    _ => []
  }
  let fields = match map.get("properties") {
    Some(Object(props)) => {
      let out : Array[@moonmodel.Field] = []
      for (prop_name, prop_val) in props.iter() {
        let is_required = required_list.contains(prop_name)
        let is_nullable = match prop_val {
          Object(pm) =>
            match pm.get("type") {
              Some(Array(types)) => types.any(fn(t) { t == Json::string("null") })
              _ => false
            }
          _ => false
        }
        let kind = parse_js_property(prop_val)
        let check = parse_js_check(prop_val)
        let prop_doc = match prop_val {
          Object(pm) =>
            match pm.get("description") {
              Some(String(d)) => d
              _ => ""
            }
          _ => ""
        }
        let default = match prop_val {
          Object(pm) => pm.get("default")
          _ => None
        }
        out.push(@moonmodel.Field::new(prop_name, kind, required=is_required, nullable=is_nullable, doc=prop_doc, default?, check~))
      }
      out
    }
    _ => []
  }
  @moonmodel.Model::new(name, fields, doc~)
}

///|
/// Import from JSON Schema string, return model JSON
#export_name("import_from_json_schema_str")
pub fn import_from_json_schema_str(text : String) -> String {
  let j = @jsonparse.parse_json(text)
  let model = import_from_json_schema(j)
  model_to_json(model).stringify()
}


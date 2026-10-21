// ABI 层：前端 JSON ↔ moonmodel.Model 的双向转换
// 前端只传数据，不做任何投影算法

///|
/// 从 JSON 解析类型（支持简单类型字符串和复合类型对象）
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
/// 从 JSON 解析 Check
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
      // 直接构造 Check 结构体
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
/// 从 JSON 解析 Field
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
/// 从 JSON 解析 Model
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
/// 解析输入的中间结果
pub(all) struct Input {
  model : @moonmodel.Model
  known : Array[@moonmodel.Model]
} derive(Eq, @debug.Debug)

///|
pub extend Input with Eq::{equal, not_equal}

///|
pub extend Input with Debug::{to_repr}

///|
/// 解析输入 JSON
/// 格式：{ "name": "...", "doc": "...", "fields": [...], "known": [{...}, ...] }
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
  { model, known }
}

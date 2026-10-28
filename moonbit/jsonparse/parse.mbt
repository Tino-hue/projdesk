// 精简 JSON 解析封装：绕过 moonmodel/json 与 core/json 的 @json 名字冲突

///|
/// 解析 JSON 字符串，失败时返回 Null
pub fn parse_json(text : String) -> Json {
  @json.parse(text) catch {
    _ => Json::null()
  }
}

///|
/// 将 Json 序列化为字符串
pub fn stringify_json(j : Json, indent? : Int = 0) -> String {
  if indent > 0 {
    j.stringify(indent~)
  } else {
    j.stringify()
  }
}

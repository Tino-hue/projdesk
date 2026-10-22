// 鏋佽杽 JSON 瑙ｆ瀽灏佽锛氱粫寮€ moonmodel/json 涓?core/json 鐨?@json 鍚嶅瓧鍐茬獊

///|
/// 瑙ｆ瀽 JSON 瀛楃涓诧紝澶辫触杩斿洖 Null
pub fn parse_json(text : String) -> Json {
  @json.parse(text) catch {
    _ => Json::null()
  }
}

///|
/// 灏?Json 搴忓垪鍖栦负瀛楃涓?
pub fn stringify_json(j : Json, indent? : Int = 0) -> String {
  if indent > 0 {
    j.stringify(indent~)
  } else {
    j.stringify()
  }
}

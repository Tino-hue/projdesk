// DSL semantic analysis: reference resolution and cycle detection
//
// The parser builds a tree; the checker answers the questions a tree alone
// cannot: does every Ref point at a model that exists, and do the references
// form a cycle?

///|
/// A problem found by semantic analysis
pub(all) enum SemanticIssue {
  /// Ref points at a model that is not defined anywhere
  UndefinedRef(String, String)
  /// Ref cycle: A -> B -> A
  RefCycle(Array[String])
  /// A field references itself
  SelfReference(String)
} derive(Eq, Debug)

///|
pub extend SemanticIssue with Eq::{equal, not_equal}

///|
pub extend SemanticIssue with Debug::{to_repr}

///|
pub fn SemanticIssue::to_text(self : SemanticIssue) -> String {
  match self {
    UndefinedRef(field, target) =>
      "field '" + field + "' references undefined model '" + target + "'"
    RefCycle(cycle) => "reference cycle: " + cycle.join(" -> ")
    SelfReference(field) => "field '" + field + "' references its own model"
  }
}

///|
pub fn SemanticIssue::severity(self : SemanticIssue) -> String {
  match self {
    UndefinedRef(_, _) => "error"
    RefCycle(_) => "error"
    SelfReference(_) => "error"
  }
}

///|
/// Collect every Ref target used by a model, with the field it came from
fn collect_refs(model : AstModel, out : Array[(String, String)]) -> Unit {
  for f in model.fields {
    match f.kind {
      RefTo(target) => out.push((f.name, target))
      Nested(inner) =>
        for g in inner.fields {
          match g.kind {
            RefTo(t) => out.push((f.name + "." + g.name, t))
            _ => ()
          }
        }
      _ => ()
    }
  }
}

///|
/// Analyze a set of models for semantic problems
pub fn check_semantics(models : Array[AstModel]) -> Array[SemanticIssue] {
  let issues : Array[SemanticIssue] = []
  // All defined model names
  let defined : Array[String] = models.map(fn(m) { m.name })
  // References per model
  let refs_per_model : Array[Array[(String, String)]] = []
  for m in models {
    let refs : Array[(String, String)] = []
    collect_refs(m, refs)
    refs_per_model.push(refs)
  }
  // 1. Undefined references
  for i = 0; i < models.length(); i = i + 1 {
    for (field, target) in refs_per_model[i] {
      if !defined.contains(target) {
        issues.push(UndefinedRef(field, target))
      }
    }
  }
  // 2. Self reference
  for i = 0; i < models.length(); i = i + 1 {
    for (field, target) in refs_per_model[i] {
      if target == models[i].name {
        issues.push(SelfReference(field))
      }
    }
  }
  // 3. Reference cycles
  // Build adjacency: model index -> referenced model indices
  let mut cycle_found = false
  for i = 0; i < models.length() && !cycle_found; i = i + 1 {
    let start = models[i].name
    let mut path : Array[String] = [start]
    let mut stack : Array[String] = []
    for (_, target) in refs_per_model[i] {
      stack.push(target)
    }
    let mut steps = 0
    let mut found_cycle = false
    while stack.length() > 0 && !found_cycle && steps < 100 {
      steps = steps + 1
      let next = stack[0]
      let rest = stack[1:].to_owned()
      if next == start {
        found_cycle = true
        issues.push(RefCycle(path))
      } else if path.contains(next) {
        found_cycle = true
        let cycle = path + [next]
        issues.push(RefCycle(cycle))
      } else {
        let grown = path + [next]
        // follow this model's references
        let more : Array[String] = []
        let mut found = false
        for j = 0; j < models.length(); j = j + 1 {
          if models[j].name == next {
            for (_, target) in refs_per_model[j] {
              more.push(target)
            }
            found = true
            break
          }
        }
        if found {
          stack = rest + more
          path = grown
        } else {
          stack = rest
        }
      }
    }
    if found_cycle {
      cycle_found = true
    }
  }
  issues
}

///|
/// Semantic check as JSON
pub fn check_semantics_json(models : Array[AstModel]) -> String {
  let issues = check_semantics(models)
  let arr : Array[Json] = []
  for i in issues {
    let m : Map[String, Json] = Map([])
    m["text"] = Json::string(i.to_text())
    m["severity"] = Json::string(i.severity())
    arr.push(Json::object(m))
  }
  let out : Map[String, Json] = Map([])
  out["issues"] = Json::array(arr)
  out["issue_count"] = Json::number(issues.length().to_double())
  Json::object(out).stringify()
}

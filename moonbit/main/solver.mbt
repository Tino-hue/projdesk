// Constraint Solver: conflict, redundancy, and satisfiability analysis
// Pure MoonBit algorithmic engine

///|
/// Diagnosis result for constraint analysis
pub(all) enum Diagnosis {
  /// Constraints contradict each other (e.g. least=10, most=5)
  Conflict(String, String)
  /// One constraint makes another redundant (e.g. least=0 when over=0 exists)
  Redundant(String, String)
  /// Constraint is suspicious but not necessarily wrong
  Warning(String, String)
  /// Field has no constraints at all
  NoConstraints(String)
} derive(Eq, Debug)

///|
pub extend Diagnosis with Eq::{equal, not_equal}

///|
pub extend Diagnosis with Debug::{to_repr}


///|

///|
pub fn Diagnosis::to_text(self : Diagnosis) -> String {
  match self {
    Conflict(f, msg) => "[CONFLICT] \{f}: \{msg}"
    Redundant(f, msg) => "[REDUNDANT] \{f}: \{msg}"
    Warning(f, msg) => "[WARNING] \{f}: \{msg}"
    NoConstraints(f) => "[OK] \{f}: no constraints"
  }
}

///|
/// Severity level for UI display
pub fn Diagnosis::severity(self : Diagnosis) -> String {
  match self {
    Conflict(_, _) => "error"
    Redundant(_, _) => "warning"
    Warning(_, _) => "info"
    NoConstraints(_) => "ok"
  }
}

///|
/// Analyze constraints of a single field
pub fn analyze_field(
  name : String,
  check : @moonmodel.Check,
) -> Array[Diagnosis] {
  let diags = []
  let c = check

  // --- Range conflicts ---
  match (c.least, c.most) {
    (Some(lo), Some(hi)) =>
      if lo > hi {
        diags.push(Conflict(name, "least(\{lo}) > most(\{hi}): empty range"))
      } else if lo == hi {
        diags.push(Warning(name, "least == most == \{lo}: fixed value"))
      }
    _ => ()
  }

  match (c.over, c.under) {
    (Some(lo), Some(hi)) =>
      if lo >= hi {
        diags.push(
          Conflict(name, "over(\{lo}) >= under(\{hi}): empty open interval"),
        )
      }
    _ => ()
  }

  // Cross-boundary conflicts
  match (c.least, c.under) {
    (Some(lo), Some(hi)) =>
      if lo >= hi {
        diags.push(Conflict(name, "least(\{lo}) >= under(\{hi}): impossible"))
      }
    _ => ()
  }

  match (c.over, c.most) {
    (Some(lo), Some(hi)) =>
      if lo >= hi {
        diags.push(Conflict(name, "over(\{lo}) >= most(\{hi}): impossible"))
      }
    _ => ()
  }

  // --- Length conflicts ---
  match (c.shortest, c.longest) {
    (Some(lo), Some(hi)) =>
      if lo > hi {
        diags.push(
          Conflict(name, "shortest(\{lo}) > longest(\{hi}): empty length range"),
        )
      } else if lo == hi {
        diags.push(Warning(name, "shortest == longest == \{lo}: fixed length"))
      }
    _ => ()
  }

  // --- Redundancy: over/under subsume least/most ---
  match (c.least, c.over) {
    (Some(lo), Some(over)) =>
      if lo <= over {
        diags.push(Redundant(name, "least(\{lo}) subsumed by over(\{over})"))
      }
    _ => ()
  }

  match (c.most, c.under) {
    (Some(hi), Some(under)) =>
      if hi >= under {
        diags.push(Redundant(name, "most(\{hi}) subsumed by under(\{under})"))
      }
    _ => ()
  }

  // --- Redundancy: longest=0 implies shortest=0 ---
  match (c.shortest, c.longest) {
    (Some(lo), Some(hi)) =>
      if hi == 0 && lo > 0 {
        diags.push(
          Conflict(name, "shortest(\{lo}) with longest(0): impossible"),
        )
      }
    _ => ()
  }

  // --- Pattern + format tension ---
  match (c.pattern, c.format) {
    (Some(_), Some(fmt)) =>
      diags.push(
        Warning(
          name,
          "pattern + format('\{fmt}') may conflict: verify compatibility",
        ),
      )
    _ => ()
  }

  // --- Options + other constraints ---
  if c.options.length() > 0 {
    match c.pattern {
      Some(_) =>
        diags.push(
          Warning(name, "options + pattern: pattern may reject some options"),
        )
      None => ()
    }
    match c.longest {
      Some(max_len) =>
        for opt in c.options {
          match opt {
            String(s) =>
              if s.length() > max_len {
                diags.push(
                  Conflict(name, "option '\{s}' exceeds longest(\{max_len})"),
                )
              }
            _ => ()
          }
        }
      None => ()
    }
  }

  // --- Distinct + unique confusion ---
  if c.distinct && c.unique {
    diags.push(
      Warning(
        name, "both distinct and unique: different semantics (list items vs records)",
      ),
    )
  }

  // --- Empty check ---
  if c.is_empty() {
    diags.push(NoConstraints(name))
  }

  diags
}

///|
/// Analyze all fields of a model
pub fn analyze_model(model : @moonmodel.Model) -> Array[Diagnosis] {
  let diags = []
  for field in model.fields {
    let field_diags = analyze_field(field.name, field.check)
    for d in field_diags {
      diags.push(d)
    }
  }
  diags
}

///|
/// Get only conflicts (errors)
pub fn conflicts_only(diags : Array[Diagnosis]) -> Array[Diagnosis] {
  diags.filter(fn(d) {
    match d {
      Conflict(_, _) => true
      _ => false
    }
  })
}

///|
/// Get only redundancies
pub fn redundancies_only(diags : Array[Diagnosis]) -> Array[Diagnosis] {
  diags.filter(fn(d) {
    match d {
      Redundant(_, _) => true
      _ => false
    }
  })
}

///|
/// Check if model has any unsatisfiable constraints
pub fn has_conflicts(diags : Array[Diagnosis]) -> Bool {
  conflicts_only(diags).length() > 0
}

///|
/// Full analysis pipeline: model -> diagnosis JSON
pub fn solve_constraints(model : @moonmodel.Model) -> String {
  let diags = analyze_model(model)
  let arr : Array[Json] = []
  for d in diags {
    let m : Map[String, Json] = Map([])
    m["text"] = Json::string(d.to_text())
    m["severity"] = Json::string(d.severity())
    arr.push(Json::object(m))
  }
  let out : Map[String, Json] = Map([])
  out["diagnoses"] = Json::array(arr)
  out["conflict_count"] = Json::number(
    conflicts_only(diags).length().to_double(),
  )
  out["redundant_count"] = Json::number(
    redundancies_only(diags).length().to_double(),
  )
  Json::object(out).stringify()
}

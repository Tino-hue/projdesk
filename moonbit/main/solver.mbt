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
/// A constraint that another constraint of the same field already implies
///
/// The solver works this out when it reports a redundant constraint; this
/// exposes the same judgement by name, so that a diff can tell a constraint
/// change that changes nothing from one that does.
pub(all) struct Subsumed {
  /// the constraint, in the notation the diff uses
  part : String
  /// why it is implied
  reason : String
} derive(Eq, Debug)

///|
pub extend Subsumed with Eq::{equal, not_equal}

///|
pub extend Subsumed with Debug::{to_repr}

///|
/// Which of a field's constraints another constraint already implies
///
/// `least` is implied by `over` when it is not tighter, and `most` is implied
/// by `under` in the same way. Adding or removing such a constraint does not
/// change what the field accepts.
pub fn subsumed_constraints(check : @moonmodel.Check) -> Array[Subsumed] {
  let out = []
  match (check.least, check.over) {
    (Some(lo), Some(over)) =>
      if lo <= over {
        out.push(Subsumed::{
          part: "least=\{lo}",
          reason: "least(\{lo}) subsumed by over(\{over})",
        })
      }
    _ => ()
  }
  match (check.most, check.under) {
    (Some(hi), Some(under)) =>
      if hi >= under {
        out.push(Subsumed::{
          part: "most=\{hi}",
          reason: "most(\{hi}) subsumed by under(\{under})",
        })
      }
    _ => ()
  }
  out
}

///|
/// The conflicts a field's own constraints produce
///
/// Used to tell a change that leaves a field with no satisfying value from a
/// change that merely narrows it.
pub fn field_conflicts(check : @moonmodel.Check) -> Array[String] {
  let out = []
  for d in analyze_field("", check) {
    match d {
      Conflict(_, msg) => out.push(msg)
      _ => ()
    }
  }
  out
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
  for s in subsumed_constraints(c) {
    diags.push(Redundant(name, s.reason))
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
/// One diagnosis as it goes on the wire
priv struct WireDiagnosis {
  text : String
  severity : String
} derive(ToJson)

///|
/// The solver's report as it goes on the wire
priv struct WireSolveResult {
  diagnoses : Array[WireDiagnosis]
  conflict_count : Double
  redundant_count : Double
} derive(ToJson)

///|
/// Full analysis pipeline: model -> diagnosis JSON
pub fn solve_constraints(model : @moonmodel.Model) -> String {
  let diags = analyze_model(model)
  let arr : Array[WireDiagnosis] = []
  for d in diags {
    arr.push(WireDiagnosis::{ text: d.to_text(), severity: d.severity(), })
  }
  ToJson::to_json(WireSolveResult::{
    diagnoses: arr,
    conflict_count: conflicts_only(diags).length().to_double(),
    redundant_count: redundancies_only(diags).length().to_double(),
  }).stringify()
}

// Constraint resolution: settle numeric bounds that refer to other fields.
//
// The parser keeps every bound's expression and evaluates whatever it can. A
// reference to a field that appears later in the model cannot be evaluated
// yet, so it stays unresolved until this pass runs over the finished model.
//
// The pass is a fixed point: an unresolved bound is retried whenever a
// referenced value becomes known, until nothing changes. Whatever is still
// unresolved afterwards is either a reference to a field or a constraint that
// does not exist, or a cycle of references with no anchor.

///|
/// The constraint name a check carries
pub fn check_name(c : AstCheck) -> String {
  match c {
    Least(_) => "least"
    Most(_) => "most"
    Over(_) => "over"
    Under(_) => "under"
    Step(_) => "step"
    Shortest(_) => "shortest"
    Longest(_) => "longest"
    Pattern(_) => "pattern"
    Format(_) => "format"
    Options(_) => "options"
    Distinct => "distinct"
    Unique => "unique"
  }
}

///|
/// The numeric bound a check carries, if it carries one
pub fn check_bound(c : AstCheck) -> AstBound? {
  match c {
    Least(b) => Some(b)
    Most(b) => Some(b)
    Over(b) => Some(b)
    Under(b) => Some(b)
    Step(b) => Some(b)
    Shortest(b) => Some(b)
    Longest(b) => Some(b)
    _ => None
  }
}

///|
/// The same check with its bound resolved
pub fn with_bound_value(c : AstCheck, value : Double) -> AstCheck {
  match c {
    Least(b) => Least({ value: Some(value), expr: b.expr, })
    Most(b) => Most({ value: Some(value), expr: b.expr, })
    Over(b) => Over({ value: Some(value), expr: b.expr, })
    Under(b) => Under({ value: Some(value), expr: b.expr, })
    Step(b) => Step({ value: Some(value), expr: b.expr, })
    Shortest(b) => Shortest({ value: Some(value), expr: b.expr, })
    Longest(b) => Longest({ value: Some(value), expr: b.expr, })
    other => other
  }
}

///|
/// Record a resolved value in the environment
fn record_value(
  env : Map[String, Map[String, Double]],
  field : String,
  constraint : String,
  value : Double,
) -> Unit {
  let inner : Map[String, Double] = match env.get(field) {
    Some(m) => m
    None => Map([])
  }
  inner.set(constraint, value)
  env.set(field, inner)
}

///|
/// Whether a model declares a field with this name
fn has_field(model : AstModel, name : String) -> Bool {
  model.fields.any(fn(f) { f.name == name })
}

///|
/// Whether a field carries a constraint with this name
fn has_constraint(
  model : AstModel,
  field : String,
  constraint : String,
) -> Bool {
  for f in model.fields {
    if f.name == field {
      for c in f.checks {
        if check_name(c) == constraint {
          return true
        }
      }
    }
  }
  false
}

///|
/// Resolve the numeric bounds of one model, in place.
/// Returns a message for every bound that cannot be settled.
pub fn resolve_model_bounds(model : AstModel) -> Array[String] {
  let env : Map[String, Map[String, Double]] = Map([])
  // Seed with the bounds the parser already settled, so a field that refers
  // to one of them can be resolved in the first round.
  for f in model.fields {
    for c in f.checks {
      match check_bound(c) {
        Some(b) =>
          match b.value {
            Some(v) => record_value(env, f.name, check_name(c), v)
            None => ()
          }
        None => ()
      }
    }
  }
  let mut changed = true
  while changed {
    changed = false
    for i = 0; i < model.fields.length(); i = i + 1 {
      let f = model.fields[i]
      for j = 0; j < f.checks.length(); j = j + 1 {
        let c = f.checks[j]
        match check_bound(c) {
          Some(b) =>
            match b.value {
              Some(_) => ()
              None =>
                match eval_expr_in(b.expr, { vars: Map([]), fields: env, }) {
                  Ok(n) => {
                    model.fields[i].checks[j] = with_bound_value(c, n)
                    record_value(env, f.name, check_name(c), n)
                    changed = true
                  }
                  Err(_) => ()
                }
            }
          None => ()
        }
      }
    }
  }
  // Whatever is still unresolved cannot be settled.
  let problems : Array[String] = []
  for i = 0; i < model.fields.length(); i = i + 1 {
    let f = model.fields[i]
    for j = 0; j < f.checks.length(); j = j + 1 {
      match check_bound(f.checks[j]) {
        Some(b) =>
          match b.value {
            Some(_) => ()
            None =>
              match b.expr.dependency() {
                Some((field, constraint)) => {
                  let mine = f.name + "." + check_name(f.checks[j])
                  if !has_field(model, field) {
                    problems.push(
                      "constraint " +
                      mine +
                      " refers to unknown field '" +
                      field +
                      "'",
                    )
                  } else if !has_constraint(model, field, constraint) {
                    problems.push(
                      "constraint " +
                      mine +
                      " refers to unknown constraint '" +
                      field +
                      "." +
                      constraint +
                      "'",
                    )
                  } else {
                    // The field and the constraint exist, so the reference
                    // can only fail to settle because the references form a
                    // cycle. The propagation engine reports that.
                    ()
                  }
                }
                None => ()
              }
          }
        None => ()
      }
    }
  }
  problems
}

///|
/// One numeric bound of a field, with the field it refers to
fn bound_of(f : AstField, constraint : String) -> Bound? {
  for c in f.checks {
    if check_name(c) != constraint {
      continue
    }
    match check_bound(c) {
      Some(b) => {
        let from_field = match b.expr.dependency() {
          Some((field, _)) => field
          None => ""
        }
        return Some({ value: b.value, from_field, })
      }
      None => ()
    }
  }
  None
}

///|
/// The numeric bounds of a model's fields, with the references they carry
pub fn model_field_bounds(model : AstModel) -> Array[FieldBounds] {
  let bounds : Array[FieldBounds] = []
  for f in model.fields {
    bounds.push({
      name: f.name,
      least: bound_of(f, "least"),
      most: bound_of(f, "most"),
      over: bound_of(f, "over"),
      under: bound_of(f, "under"),
    })
  }
  bounds
}

///|
/// The bounds of a model that could not be settled
pub fn unresolved_bounds(model : AstModel) -> Array[String] {
  let out : Array[String] = []
  for f in model.fields {
    for c in f.checks {
      match check_bound(c) {
        Some(b) =>
          match b.value {
            Some(_) => ()
            None => out.push(f.name + "." + check_name(c))
          }
        None => ()
      }
    }
  }
  out
}

///|
/// Resolve the numeric bounds of every model
pub fn resolve_all_bounds(models : Array[AstModel]) -> Array[String] {
  let problems : Array[String] = []
  for m in models {
    for p in resolve_model_bounds(m) {
      problems.push(p)
    }
  }
  problems
}

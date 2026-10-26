// Semantic Equivalence: deep model comparison with type subtyping

///|
/// Equivalence result
pub(all) enum EquivResult {
  Equivalent
  SubtypeOf(String)
  SupertypeOf(String)
  Incompatible(String)
} derive(Eq, Debug)

///|
pub fn EquivResult::to_text(self : EquivResult) -> String {
  match self {
    Equivalent => "equivalent"
    SubtypeOf(t) => "subtype of " + t
    SupertypeOf(t) => "supertype of " + t
    Incompatible(r) => "incompatible: " + r
  }
}

///|
/// Type widening check
fn type_widens(from : @moonmodel.Type, to : @moonmodel.Type) -> Bool {
  if from == to {
    return true
  }
  match (from, to) {
    (Int, Big) => true
    (Int, Real) => true
    (Big, Real) => true
    (Bool, Text) => true
    (List(a2), List(b2)) => type_widens(a2, b2)
    (Dict(a2), Dict(b2)) => type_widens(a2, b2)
    (Ref(a2), Ref(b2)) => a2 == b2
    (Any, _) => true
    _ => false
  }
}

///|
/// Constraint containment: does outer contain inner?
fn check_contains(outer : @moonmodel.Check, inner : @moonmodel.Check) -> Bool {
  match (outer.longest, inner.longest) {
    (Some(a), Some(b)) => if a < b { return false }
    (Some(_), None) => return false
    _ => ()
  }
  match (outer.shortest, inner.shortest) {
    (Some(a), Some(b)) => if a > b { return false }
    (Some(_), None) => return false
    _ => ()
  }
  match (outer.least, inner.least) {
    (Some(a), Some(b)) => if a > b { return false }
    (Some(_), None) => return false
    _ => ()
  }
  match (outer.most, inner.most) {
    (Some(a), Some(b)) => if a < b { return false }
    (Some(_), None) => return false
    _ => ()
  }
  if outer.options.length() > 0 {
    if inner.options.length() == 0 {
      return false
    }
    for opt in inner.options {
      if !outer.options.contains(opt) {
        return false
      }
    }
  }
  if outer.unique && !inner.unique {
    return false
  }
  if outer.distinct && !inner.distinct {
    return false
  }
  true
}

///|
/// Compare two fields
fn field_equiv(
  name : String,
  a : @moonmodel.Field,
  b : @moonmodel.Field,
) -> EquivResult {
  let a_to_b = type_widens(a.kind, b.kind)
  let b_to_a = type_widens(b.kind, a.kind)
  if !a_to_b && !b_to_a {
    return Incompatible(name + ": type mismatch")
  }
  let type_stricter = a_to_b && !b_to_a
  let type_looser = !a_to_b && b_to_a

  // Required/nullable
  let mut req_stricter = false
  let mut req_looser = false
  if a.required && !b.required {
    req_stricter = true
  } else if !a.required && b.required {
    req_looser = true
  }
  if !a.nullable && b.nullable {
    req_stricter = true
  } else if a.nullable && !b.nullable {
    req_looser = true
  }

  // Constraints
  let a_in_b = check_contains(b.check, a.check)
  let b_in_a = check_contains(a.check, b.check)

  let mut con_stricter = false
  let mut con_looser = false
  if a_in_b && !b_in_a {
    con_stricter = true
  } else if !a_in_b && b_in_a {
    con_looser = true
  } else if !a_in_b && !b_in_a {
    return Incompatible(name + ": constraints not comparable")
  }

  let is_stricter = type_stricter || req_stricter || con_stricter
  let is_looser = type_looser || req_looser || con_looser

  if is_stricter && is_looser {
    return Incompatible(name + ": mixed subtyping directions")
  }
  if is_stricter {
    return SubtypeOf(name)
  }
  if is_looser {
    return SupertypeOf(name)
  }
  Equivalent
}

///|
/// Compare two models
pub fn model_equiv(
  a : @moonmodel.Model,
  b : @moonmodel.Model,
) -> EquivResult {
  if a.name != b.name {
    return Incompatible("name mismatch: " + a.name + " vs " + b.name)
  }
  let a_names = a.fields.map(fn(f) { f.name })
  let b_names = b.fields.map(fn(f) { f.name })
  for n in a_names {
    if !b_names.contains(n) {
      return Incompatible("field " + n + " missing in second model")
    }
  }
  for n in b_names {
    if !a_names.contains(n) {
      return Incompatible("field " + n + " missing in first model")
    }
  }
  let mut has_subtype = false
  let mut has_supertype = false
  for f in a.fields {
    match b.field(f.name) {
      Some(bf) => {
        match field_equiv(f.name, f, bf) {
          Equivalent => ()
          SubtypeOf(_) => has_subtype = true
          SupertypeOf(_) => has_supertype = true
          Incompatible(r) => return Incompatible(r)
        }
      }
      None => return Incompatible("field not found")
    }
  }
  if has_subtype && has_supertype {
    return Incompatible("mixed subtyping directions")
  }
  if has_subtype {
    return SubtypeOf(b.name)
  }
  if has_supertype {
    return SupertypeOf(b.name)
  }
  Equivalent
}

///|
pub fn check_equivalence(
  a : @moonmodel.Model,
  b : @moonmodel.Model,
) -> String {
  let result = model_equiv(a, b)
  let out : Map[String, Json] = Map([])
  out["result"] = Json::string(result.to_text())
  out["equivalent"] = Json::boolean(match result {
    Equivalent => true
    _ => false
  })
  Json::object(out).stringify()
}

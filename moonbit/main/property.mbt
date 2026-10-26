// Deterministic PRNG + random model generator for property-based testing
// Uses a xorshift64* algorithm implemented from scratch in MoonBit

///|
/// Deterministic pseudo-random generator (xorshift64*)
pub(all) struct Rng {
  state : Ref[Int64]
}

///|
///|
/// Create a new RNG with a given seed
pub fn new_rng(seed : Int64) -> Rng {
  // Avoid zero state (xorshift degenerates)
  let s = if seed == 0L { 0x9E3779B97F4A7C15L } else { seed }
  { state: { val: s } }
}

///|
/// Generate next pseudo-random Int64
pub fn Rng::next_int64(self : Rng) -> Int64 {
  let mut x = self.state.val
  x = x ^ (x >> 12)
  x = x ^ (x << 25)
  x = x ^ (x >> 27)
  self.state.val = x
  x * 0x2545F4914F6CDD1DL
}

///|
/// Generate next pseudo-random Int in [0, bound)
pub fn Rng::next_int(self : Rng, bound : Int) -> Int {
  if bound <= 0 {
    return 0
  }
  let r = self.next_int64()
  (r.abs() % bound.to_int64()).to_int()
}

///|
/// Generate next pseudo-random Double in [0.0, 1.0)
pub fn Rng::next_double(self : Rng) -> Double {
  let r = self.next_int64()
  let positive = if r < 0L { -r } else { r }
  (positive % 1000000L).to_double() / 1000000.0
}

///|
/// Pick one element from an array
pub fn Rng::pick(self : Rng, arr : Array[Int]) -> Int {
  if arr.length() == 0 {
    return 0
  }
  arr[self.next_int(arr.length())]
}

///|
/// Whether a random boolean
pub fn Rng::next_bool(self : Rng) -> Bool {
  self.next_int(2) == 1
}

///|
/// Random simple type
fn random_type(rng : Rng) -> @moonmodel.Type {
  let kinds : Array[@moonmodel.Type] = [
    Bool, Int, Big, Real, Text, Bytes, Stamp, Any,
  ]
  kinds[rng.pick([0, 1, 2, 3, 4, 5, 6, 7])]
}

///|
/// Random check with random constraints
fn random_check(rng : Rng) -> @moonmodel.Check {
  let least = if rng.next_bool() { Some(rng.next_int(50).to_double()) } else { None }
  let most = if rng.next_bool() { Some((least.unwrap_or(0.0) + rng.next_int(100).to_double())) } else { None }
  let shortest = if rng.next_bool() { Some(rng.next_int(10)) } else { None }
  let longest = if rng.next_bool() {
    Some(shortest.unwrap_or(0) + rng.next_int(100))
  } else {
    None
  }
  let options = if rng.next_bool() {
    let opts : Array[Json] = []
    let n = rng.next_int(3) + 1
    for i = 0; i < n; i = i + 1 {
      opts.push(Json::string("opt" + i.to_string()))
    }
    opts
  } else {
    []
  }
  {
    least,
    most,
    over: None,
    under: None,
    step: None,
    shortest,
    longest,
    pattern: None,
    format: None,
    options,
    distinct: rng.next_bool(),
    unique: rng.next_bool(),
  }
}

///|
/// Generate a random model
pub fn random_model(rng : Rng, name : String) -> @moonmodel.Model {
  let field_count = rng.next_int(6) + 1
  let fields : Array[@moonmodel.Field] = []
  for i = 0; i < field_count; i = i + 1 {
    let kind = random_type(rng)
    let check = random_check(rng)
    let required = rng.next_bool()
    let nullable = rng.next_bool()
    let doc = if rng.next_bool() { "field " + i.to_string() } else { "" }
    fields.push(
      @moonmodel.Field::new(
        "field_" + i.to_string(),
        kind,
        required=required,
        nullable=nullable,
        doc=doc,
        check=check,
      ),
    )
  }
  @moonmodel.Model::new(name, fields, doc="random model")
}

///|
/// Generate N random models
pub fn random_models(rng : Rng, count : Int) -> Array[@moonmodel.Model] {
  let out : Array[@moonmodel.Model] = []
  for i = 0; i < count; i = i + 1 {
    out.push(random_model(rng, "Random" + i.to_string()))
  }
  out
}

///|
/// Generate a random constraint-only model (for solver stress testing)
pub fn random_constraint_model(rng : Rng) -> @moonmodel.Model {
  let field_count = rng.next_int(4) + 1
  let fields : Array[@moonmodel.Field] = []
  for i = 0; i < field_count; i = i + 1 {
    fields.push(
      @moonmodel.Field::new(
        "f" + i.to_string(),
        Real,
        check=random_check(rng),
      ),
    )
  }
  @moonmodel.Model::new("Stress", fields)
}

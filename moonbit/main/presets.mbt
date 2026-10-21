// Preset models: User / Order / Address with Ref references

///|
/// Address model
fn preset_address() -> @moonmodel.Model {
  @moonmodel.Model::new(
    "Address",
    [
      @moonmodel.Field::new("line", Text, doc="street address"),
      @moonmodel.Field::new("city", Text, doc="city"),
      @moonmodel.Field::new(
        "country",
        Text,
        doc="ISO 3166-1 alpha-2 country code",
        check=@moonmodel.Check::new(shortest=2, longest=2),
      ),
      @moonmodel.Field::new("zip", Text, required=false, doc="postal code"),
    ],
    doc="shipping address",
  )
}

///|
/// User model: covers unique, bounds, format, pattern, options, List, Dict, Ref
fn preset_user() -> @moonmodel.Model {
  @moonmodel.Model::new(
    "User",
    [
      @moonmodel.Field::new(
        "id",
        Big,
        doc="user ID, system assigned",
        check=@moonmodel.Check::new(unique=true),
      ),
      @moonmodel.Field::new(
        "name",
        Text,
        doc="display name",
        check=@moonmodel.Check::new(shortest=1, longest=64),
      ),
      @moonmodel.Field::new(
        "email",
        Text,
        doc="email address",
        check=@moonmodel.Check::new(format="email", pattern="^[^@]+@[^@]+$"),
      ),
      @moonmodel.Field::new(
        "age",
        Int,
        required=false,
        doc="age",
        check=@moonmodel.Check::new(least=0.0, under=150.0),
      ),
      @moonmodel.Field::new(
        "active",
        Bool,
        default=Json::boolean(true),
        doc="is active",
      ),
      @moonmodel.Field::new("joined", Stamp, doc="registration time"),
      @moonmodel.Field::new(
        "avatar",
        Bytes,
        required=false,
        nullable=true,
        doc="avatar image",
      ),
      @moonmodel.Field::new(
        "tier",
        Text,
        default=Json::string("free"),
        doc="user tier",
        check=@moonmodel.Check::new(options=[
          Json::string("free"),
          Json::string("paid"),
          Json::string("staff"),
        ]),
      ),
      @moonmodel.Field::new(
        "tags",
        List(Text),
        required=false,
        doc="tag list",
        check=@moonmodel.Check::new(distinct=true, longest=10),
      ),
      @moonmodel.Field::new("labels", Dict(Text), required=false, doc="custom labels"),
      @moonmodel.Field::new("home", Ref("Address"), required=false, doc="home address"),
    ],
    doc="user account",
  )
}

///|
/// Order model: references User and Address
fn preset_order() -> @moonmodel.Model {
  @moonmodel.Model::new(
    "Order",
    [
      @moonmodel.Field::new(
        "id",
        Big,
        doc="order ID",
        check=@moonmodel.Check::new(unique=true),
      ),
      @moonmodel.Field::new("buyer", Ref("User"), doc="buyer"),
      @moonmodel.Field::new("ship_to", Ref("Address"), doc="shipping address"),
      @moonmodel.Field::new(
        "total",
        Real,
        doc="order total",
        check=@moonmodel.Check::new(over=0.0, step=0.01),
      ),
      @moonmodel.Field::new(
        "status",
        Text,
        default=Json::string("pending"),
        doc="order status",
        check=@moonmodel.Check::new(options=[
          Json::string("pending"),
          Json::string("paid"),
          Json::string("shipped"),
          Json::string("cancelled"),
        ]),
      ),
      @moonmodel.Field::new("created", Stamp, doc="creation time"),
    ],
    doc="order",
  )
}

///|
/// Get all preset models
pub fn presets() -> Array[@moonmodel.Model] {
  let out : Array[@moonmodel.Model] = []
  out.push(preset_user())
  out.push(preset_order())
  out.push(preset_address())
  out
}

///|
/// Get preset by name
pub fn preset_by_name(name : String) -> @moonmodel.Model? {
  for m in presets() {
    if m.name == name {
      return Some(m)
    }
  }
  None
}

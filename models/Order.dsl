// Order model — a worked example of the ProjDesk modeling language.
//
// Demonstrates: unique constraints, length bounds, format checks,
// optional and nullable fields, computed expression bounds,
// and a reference to another model.

model Order {
  // primary key
  id: Big @unique
  // human readable reference
  reference: Text [shortest=4, longest=12]
  // customer who placed the order
  customer: Ref(Customer)
  // total in cents
  total: Int [least=0]
  // order status
  status: Text [options=[pending, paid, shipped, cancelled]]
  // when it was created
  createdAt: Stamp
  // shipping address, may be filled later
  shippedTo: Ref(Address) @optional @nullable
}

model Customer {
  // primary key
  id: Big @unique
  // display name
  name: Text [shortest=1, longest=64]
  // contact email
  email: Text [format=email]
  // known addresses
  addresses: List(Ref(Address)) @optional
}

model Address {
  // street line
  line: Text
  // city name
  city: Text
  // ISO 3166-1 alpha-2 country code
  country: Text [shortest=2, longest=2]
}
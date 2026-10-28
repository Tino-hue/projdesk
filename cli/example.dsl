// user account model
model User {
  // unique identifier
  id: Big @unique
  name: Text [shortest=1, longest=64]
  email: Text [format=email]
  age: Int @optional [least=0, under=150]
  tags: List(Text) @optional @distinct
  addr: Nest {
    city: Text
    zip: Int
  }
}

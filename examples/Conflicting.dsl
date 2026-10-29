// A model whose constraints contradict each other.
//
// The projection writes the bounds through and says nothing about them. The
// solver reports both problems. Run `projdesk contrast models/Conflicting.dsl`
// to see the two sides next to each other.

model Reading {
  // primary key
  id: Big @unique
  // the lowest value a reading may have
  floor: Int [least=0]
  // the highest value: impossible, because it is below the floor
  ceiling: Int [least=0, most=-1]
  // a closed set that does not fit the length bound
  code: Text [longest=3, options=[toolong]]
}

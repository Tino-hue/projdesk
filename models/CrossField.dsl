// Cross-field constraint references — a worked example.
//
// A constraint may take its value from another field's bound. The reference
// is resolved after the whole model has been parsed, so it may point at a
// field that is declared later, and a cycle of references is reported rather
// than silently ignored.
//
// Here the ceiling is ten times the floor, and the reading has to lie
// between the two - which is three references: one plain, one with
// arithmetic, and one through another field's bound.

model Reading {
  // primary key
  id: Big @unique
  // the lowest value this sensor may report
  floor: Int [least=5]
  // the highest value is ten times the floor
  ceiling: Int [least=5, most=floor.least * 10]
  // the reading has to lie between the floor and the ceiling
  value: Int [least=floor.least, most=ceiling.most]
  // where the reading was taken
  site: Ref(Site)
}

model Site {
  // primary key
  id: Big @unique
  // site name
  name: Text [shortest=1, longest=64]
}

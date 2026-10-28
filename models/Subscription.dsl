// Subscription billing model — a worked example of the ProjDesk modeling language.
//
// Demonstrates: nested models, references to other models, expression bounds
// (10 * 2 is resolved at compile time), closed option sets, and optional
// nullable fields.

model Subscription {
  // primary key
  id: Big @unique
  // display name
  name: Text [shortest=3, longest=80]
  // billing period in months
  period: Int [least=1, most=24]
  // price in cents
  priceCents: Int [least=0]
  // allowed lifecycle states
  status: Text [options=[trialing, active, past_due, canceled]]
  // seat count, capped at twenty
  seats: Int [least=1, most=10 * 2]
  // the plan this subscription belongs to
  plan: Ref(Plan)
  // billing contact
  contact: Nest {
    email: Text [format=email]
    timezone: Text [shortest=1, longest=64]
  }
  // when the subscription started
  startedAt: Stamp
  // free-text notes
  notes: Text @optional @nullable
}

model Plan {
  // primary key
  id: Big @unique
  // machine readable plan code
  code: Text [shortest=2, longest=16]
  // plan display name
  label: Text [shortest=1, longest=64]
}

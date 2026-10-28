// IoT telemetry model — a worked example of the ProjDesk modeling language.
//
// Demonstrates: collection types (List / Dict), numeric step constraints,
// format checks, a reference to another model, and optional nullable fields.

model DeviceReading {
  // primary key
  id: Big @unique
  // device serial number
  serial: Text [shortest=4, longest=32]
  // measured temperature in celsius
  temperature: Real [over=-50, under=100, step=0.1]
  // battery level in percent
  battery: Int [least=0, most=100]
  // firmware version
  firmware: Text [format=semver]
  // extra sensor channels keyed by name
  channels: Dict(Real) @optional
  // event tags
  tags: List(Text) @optional @distinct
  // where the device is installed
  site: Ref(Site)
  // when the reading was taken
  recordedAt: Stamp
  // optional operator note
  note: Text @optional @nullable
}

model Site {
  // primary key
  id: Big @unique
  // human readable site name
  name: Text [shortest=1, longest=64]
  // ISO 3166-1 alpha-2 country code
  country: Text [shortest=2, longest=2]
}

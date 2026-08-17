import Testing

/// Parent of every suite that builds a ModelContainer.
///
/// The frozen V2 schema and the live V3 one give their entities the same
/// names - that is what lets a store map from one version to the next -
/// so Core Data resolves "Player" or "PointPlayer" through state shared
/// across containers. Build a V2 container while another test drives a V3
/// one and it dies with "the entity PointPlayer is not key value
/// coding-compliant for the key point".
///
/// `.serialized` only orders tests within a single suite, so marking each
/// file's suite individually was not enough: two serialized suites still
/// run alongside each other. Nesting them all under this one puts every
/// container-building test in the same serialization scope, because the
/// trait applies to descendants.
///
/// The app builds exactly one container, so none of this constrains the
/// app itself.
@Suite(.serialized)
struct StoreTests {}

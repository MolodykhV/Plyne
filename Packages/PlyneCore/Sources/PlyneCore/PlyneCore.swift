/// Plyne's pure-domain layer.
///
/// `PlyneCore` holds value types, validation logic, and timer rules. It is
/// intentionally free of Apple-framework dependencies so it can build and
/// test on Linux in CI.
public enum PlyneCore {
    /// Monotonically increasing version of the public domain schema.
    /// Bumped whenever a breaking change to a persisted type ships; the
    /// storage layer refuses to load data tagged with a higher version
    /// than it understands.
    public static let schemaVersion: Int = 1
}

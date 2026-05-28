import Foundation
import PlyneCore

/// SwiftData schema, repositories, and persistence wiring.
///
/// `PlyneStorage` is macOS-only. The mapping from `PlyneCore` value types
/// to `@Model` records and the repository protocols land in step 1.4.
public enum PlyneStorage {
    /// Highest ``PlyneCore/PlyneCore/schemaVersion`` this store can read.
    /// On a higher version, the store refuses to open the database rather
    /// than risk silently dropping unknown fields.
    public static let supportedSchemaVersion: Int = PlyneCore.schemaVersion
}

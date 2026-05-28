import PlyneCore

/// Heatmap aggregation, trends, and insight-card rules.
///
/// `PlyneAnalytics` is intentionally Apple-framework-free so it builds and
/// tests on Linux in CI. Real aggregation lands in step 1.10 (heatmap) and
/// step 1.11 (insight cards).
public enum PlyneAnalytics {
    /// Highest ``PlyneCore/PlyneCore/schemaVersion`` this module understands.
    /// Bump alongside the core schema when adding new fields the analytics
    /// pipeline depends on.
    public static let compatibleSchemaVersion: Int = PlyneCore.schemaVersion
}

import Foundation

/// A candidate intention shown in the pre-session prompt.
///
/// Ranking lives in step 1.6 (PlyneStorage will provide the recency and
/// frequency signals). The domain type only carries what the UI renders
/// and what storage round-trips.
public struct IntentionSuggestion: Hashable, Sendable, Codable {
    /// The intention text exactly as the user phrased it.
    public let text: String

    /// Where the suggestion came from.
    public let source: Source

    /// Source of an ``IntentionSuggestion``.
    public enum Source: String, Hashable, Sendable, Codable, CaseIterable {
        /// Extracted from a previous session's intention field.
        case history

        /// Curated default that ships with Plyne.
        case template
    }

    /// Memberwise initializer.
    public init(text: String, source: Source) {
        self.text = text
        self.source = source
    }
}

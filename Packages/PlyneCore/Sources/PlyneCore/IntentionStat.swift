import Foundation

/// The recency and frequency signals for one previously-used intention.
///
/// This is the raw material the pre-session prompt ranks its suggestions
/// from. Storage supplies a recent window of these; ``IntentionRanker``
/// turns them into ordered ``IntentionSuggestion`` values. Kept in the pure
/// domain layer so the ranking is testable without persistence.
public struct IntentionStat: Hashable, Sendable {
    /// The intention text, exactly as the user phrased it.
    public let text: String

    /// How many times this intention has been used.
    public let useCount: Int

    /// When it was last used.
    public let lastUsedAt: Date

    /// Memberwise initializer.
    public init(text: String, useCount: Int, lastUsedAt: Date) {
        self.text = text
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
    }
}

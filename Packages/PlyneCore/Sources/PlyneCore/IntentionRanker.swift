import Foundation

/// Ranks previously-used intentions into prompt suggestions.
///
/// Pure and deterministic: the same inputs always yield the same order, so
/// it is fully unit-testable. The score blends **recency** (how recently the
/// intention was last used) and **frequency** (how often), per the concept's
/// "автодополнение из недавних формулировок". When the user has begun typing,
/// suggestions are filtered to matches and prefix matches are surfaced ahead
/// of mid-word ones; an entry identical to the query is dropped (selecting it
/// would do nothing).
public enum IntentionRanker {
    /// Recency half-life, in days: a match used this many days ago scores
    /// half the recency of one used just now. A week keeps "this week's"
    /// intentions prominent.
    private static let recencyHalfLifeDays: Double = 7

    /// Relative weight of recency vs frequency in the blended score. Recency
    /// leads — the concept emphasises *recent* formulations — while frequency
    /// re-orders within the candidate window so an often-used phrase isn't
    /// buried by a one-off typed minutes earlier. (The candidate window the
    /// caller supplies is recency-bounded, so frequency ranks what's in it; it
    /// does not resurrect a staple that has dropped out of that window.)
    private static let recencyWeight: Double = 0.6
    private static let frequencyWeight: Double = 0.4

    /// Produces up to `limit` suggestions for the given draft `query`.
    ///
    /// - Parameters:
    ///   - stats: the candidate window from storage (any order).
    ///   - query: the current draft text; empty means "show recents".
    ///   - now: the instant recency is measured against (injected for tests).
    ///   - limit: maximum suggestions to return.
    public static func rank(
        _ stats: [IntentionStat],
        query: String = "",
        now: Date,
        limit: Int
    ) -> [IntentionSuggestion] {
        guard limit > 0 else { return [] }
        let needle = Self.fold(query)

        let ranked = stats
            .compactMap { stat -> Scored? in
                let haystack = Self.fold(stat.text)
                // Drop an entry identical to what's already typed.
                if !needle.isEmpty, haystack == needle { return nil }
                let match: MatchKind
                if needle.isEmpty {
                    match = .recent
                } else if haystack.hasPrefix(needle) {
                    match = .prefix
                } else if haystack.contains(needle) {
                    match = .substring
                } else {
                    return nil
                }
                return Scored(stat: stat, match: match, score: Self.score(stat, now: now))
            }
            .sorted(by: Self.isOrderedBefore)
            .prefix(limit)

        return ranked.map { IntentionSuggestion(text: $0.stat.text, source: .history) }
    }

    // MARK: - Scoring

    private struct Scored {
        let stat: IntentionStat
        let match: MatchKind
        let score: Double
    }

    /// Match quality, ordered so prefix matches outrank mid-word ones.
    private enum MatchKind: Int {
        case recent = 0     // no query — all candidates are equal on match
        case prefix = 2
        case substring = 1
    }

    /// Blended recency + frequency score in roughly [0, 1].
    private static func score(_ stat: IntentionStat, now: Date) -> Double {
        let ageDays = max(0, now.timeIntervalSince(stat.lastUsedAt)) / 86_400
        let recency = pow(0.5, ageDays / recencyHalfLifeDays)        // 1 now → 0.5 at one half-life
        let frequency = 1 - 1 / Double(max(1, stat.useCount) + 1)    // 1 use → 0.5, grows toward 1
        return recencyWeight * recency + frequencyWeight * frequency
    }

    /// Deterministic ordering: better match kind first, then higher score,
    /// then more recent, then text — so ties never depend on input order.
    private static func isOrderedBefore(_ lhs: Scored, _ rhs: Scored) -> Bool {
        if lhs.match.rawValue != rhs.match.rawValue {
            return lhs.match.rawValue > rhs.match.rawValue
        }
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }
        if lhs.stat.lastUsedAt != rhs.stat.lastUsedAt {
            return lhs.stat.lastUsedAt > rhs.stat.lastUsedAt
        }
        return lhs.stat.text < rhs.stat.text
    }

    /// Case- and diacritic-insensitive, whitespace-trimmed form for matching.
    private static func fold(_ string: String) -> String {
        string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

import Foundation
import SwiftData
import PlyneCore

/// SwiftData persistence record tracking an intention's recency and use
/// count. `toStat()` feeds these signals to `IntentionRanker` (in PlyneCore),
/// which ranks the pre-session prompt's suggestions.
@Model
final class IntentionEntry {
    @Attribute(.unique) var text: String
    var useCount: Int
    var lastUsedAt: Date

    init(text: String, useCount: Int, lastUsedAt: Date) {
        self.text = text
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
    }
}

extension IntentionEntry {
    func toStat() -> IntentionStat {
        IntentionStat(text: text, useCount: useCount, lastUsedAt: lastUsedAt)
    }
}

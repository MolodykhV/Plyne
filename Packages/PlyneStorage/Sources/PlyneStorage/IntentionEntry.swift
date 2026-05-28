import Foundation
import SwiftData
import PlyneCore

/// SwiftData persistence record tracking an intention's recency and use
/// count, the raw material the pre-session prompt's suggestions are ranked
/// from (ranking itself lands in step 1.6).
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
    func toSuggestion() -> IntentionSuggestion {
        IntentionSuggestion(text: text, source: .history)
    }
}

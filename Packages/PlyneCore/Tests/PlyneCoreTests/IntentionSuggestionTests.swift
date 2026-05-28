import Foundation
import Testing
@testable import PlyneCore

@Suite("IntentionSuggestion")
struct IntentionSuggestionTests {
    @Test
    func codableRoundTrip() throws {
        let original = IntentionSuggestion(
            text: "Draft the migration plan",
            source: .history
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IntentionSuggestion.self, from: data)
        #expect(decoded == original)
    }

    @Test
    func sourceCasesAreStable() {
        // Locks the raw values; storage and exports depend on them not
        // shifting silently.
        #expect(IntentionSuggestion.Source.history.rawValue == "history")
        #expect(IntentionSuggestion.Source.template.rawValue == "template")
        #expect(IntentionSuggestion.Source.allCases.count == 2)
    }

    @Test
    func equalSuggestionsHashIdentically() {
        let lhs = IntentionSuggestion(text: "Refactor auth", source: .history)
        let rhs = IntentionSuggestion(text: "Refactor auth", source: .history)
        #expect(lhs == rhs)
        #expect(lhs.hashValue == rhs.hashValue)
    }
}

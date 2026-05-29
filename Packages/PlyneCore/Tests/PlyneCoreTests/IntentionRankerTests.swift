import Foundation
import Testing
@testable import PlyneCore

@Suite("IntentionRanker")
struct IntentionRankerTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func stat(_ text: String, uses: Int = 1, daysAgo: Double = 0) -> IntentionStat {
        IntentionStat(text: text, useCount: uses, lastUsedAt: now.addingTimeInterval(-daysAgo * 86_400))
    }

    @Test
    func emptyQueryRanksRecentBeforeStale() {
        let stats = [stat("old", uses: 1, daysAgo: 30), stat("fresh", uses: 1, daysAgo: 0)]
        let result = IntentionRanker.rank(stats, now: now, limit: 10)
        #expect(result.map(\.text) == ["fresh", "old"])
        #expect(result.allSatisfy { $0.source == .history })
    }

    @Test
    func frequencyBreaksRecencyTieTowardMoreUsed() {
        // Same recency; the more-used one ranks first.
        let stats = [stat("rare", uses: 1, daysAgo: 1), stat("frequent", uses: 20, daysAgo: 1)]
        let result = IntentionRanker.rank(stats, now: now, limit: 10)
        #expect(result.first?.text == "frequent")
    }

    @Test
    func respectsLimit() {
        let stats = (0..<10).map { stat("intention \($0)", daysAgo: Double($0)) }
        let result = IntentionRanker.rank(stats, now: now, limit: 3)
        #expect(result.count == 3)
        #expect(result.first?.text == "intention 0")
    }

    @Test
    func limitZeroOrNegativeReturnsEmpty() {
        let stats = [stat("a")]
        #expect(IntentionRanker.rank(stats, now: now, limit: 0).isEmpty)
        #expect(IntentionRanker.rank(stats, now: now, limit: -1).isEmpty)
    }

    @Test
    func queryFiltersToMatchesOnly() {
        let stats = [stat("Refactor auth"), stat("Write docs"), stat("Review PR")]
        let result = IntentionRanker.rank(stats, query: "re", now: now, limit: 10)
        // "Refactor" (prefix) and "Review" (prefix) match; "Write docs" doesn't.
        #expect(Set(result.map(\.text)) == ["Refactor auth", "Review PR"])
    }

    @Test
    func prefixMatchesOutrankSubstringMatches() {
        // "ref" is a prefix of "Refactor" and a substring of "Prepare ref notes".
        // Make the substring entry far more recent/frequent so only the
        // prefix-priority rule can put the prefix match first.
        let stats = [
            stat("Prepare ref notes", uses: 50, daysAgo: 0),
            stat("Refactor auth", uses: 1, daysAgo: 20)
        ]
        let result = IntentionRanker.rank(stats, query: "ref", now: now, limit: 10)
        #expect(result.map(\.text) == ["Refactor auth", "Prepare ref notes"])
    }

    @Test
    func matchingIsCaseAndDiacriticInsensitive() {
        let stats = [stat("Résumé editing"), stat("RESUME planning")]
        let result = IntentionRanker.rank(stats, query: "resume", now: now, limit: 10)
        #expect(Set(result.map(\.text)) == ["Résumé editing", "RESUME planning"])
    }

    @Test
    func excludesEntryIdenticalToQuery() {
        let stats = [stat("Write docs"), stat("Write docs and tests")]
        let result = IntentionRanker.rank(stats, query: "  write docs  ", now: now, limit: 10)
        // The exact (folded, trimmed) match is dropped; the longer one stays.
        #expect(result.map(\.text) == ["Write docs and tests"])
    }

    @Test
    func emptyStatsReturnEmpty() {
        #expect(IntentionRanker.rank([], now: now, limit: 5).isEmpty)
        #expect(IntentionRanker.rank([], query: "x", now: now, limit: 5).isEmpty)
    }

    @Test
    func orderingIsDeterministicRegardlessOfInputOrder() {
        let alpha = stat("alpha", uses: 3, daysAgo: 2)
        let beta = stat("beta", uses: 3, daysAgo: 2)   // identical signals → text tiebreak
        let forward = IntentionRanker.rank([alpha, beta], now: now, limit: 10).map(\.text)
        let reversed = IntentionRanker.rank([beta, alpha], now: now, limit: 10).map(\.text)
        #expect(forward == reversed)
        #expect(forward == ["alpha", "beta"])
    }
}

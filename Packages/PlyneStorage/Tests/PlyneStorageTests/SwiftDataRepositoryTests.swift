import Foundation
import Testing
import PlyneCore
@testable import PlyneStorage

@Suite("SwiftDataRepository")
struct SwiftDataRepositoryTests {
    private let day = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeRepository() throws -> SwiftDataRepository {
        try SwiftDataRepository.make(inMemory: true)
    }

    private func wholeDayInterval() -> DateInterval {
        DateInterval(start: day.addingTimeInterval(-86_400), end: day.addingTimeInterval(86_400))
    }

    @Test
    func savesAndFetchesASession() async throws {
        let repo = try makeRepository()
        let session = Session(
            startedAt: day,
            endedAt: day.addingTimeInterval(1500),
            mode: .pomodoro(workMinutes: 25, breakMinutes: 5),
            intention: "Write the repository",
            categoryHint: "code",
            endReason: .completed
        )
        try await repo.save(session)

        let fetched = try await repo.sessions(in: wholeDayInterval())
        #expect(fetched == [session])
    }

    @Test("Each SessionMode survives a persistence round-trip", arguments: [
        SessionMode.pomodoro(workMinutes: 25, breakMinutes: 5),
        SessionMode.flowmodoro,
        SessionMode.overflow(parent: UUID())
    ])
    func modeRoundTrips(_ mode: SessionMode) async throws {
        let repo = try makeRepository()
        let session = Session(startedAt: day, mode: mode)
        try await repo.save(session)
        let fetched = try await repo.sessions(in: wholeDayInterval())
        #expect(fetched.first?.mode == mode)
    }

    @Test
    func saveUpsertsByID() async throws {
        let repo = try makeRepository()
        let id = UUID()
        let active = Session(id: id, startedAt: day, mode: .flowmodoro)
        try await repo.save(active)

        let ended = Session(
            id: id,
            startedAt: day,
            endedAt: day.addingTimeInterval(600),
            mode: .flowmodoro,
            endReason: .completed
        )
        try await repo.save(ended)

        let fetched = try await repo.sessions(in: wholeDayInterval())
        #expect(fetched.count == 1)
        #expect(fetched.first?.endedAt == day.addingTimeInterval(600))
        #expect(fetched.first?.endReason == .completed)
    }

    @Test
    func sessionsAreFilteredByIntervalAndSorted() async throws {
        let repo = try makeRepository()
        let earlier = Session(startedAt: day, mode: .flowmodoro)
        let later = Session(startedAt: day.addingTimeInterval(3600), mode: .flowmodoro)
        let outside = Session(startedAt: day.addingTimeInterval(10 * 86_400), mode: .flowmodoro)
        try await repo.save(later)
        try await repo.save(earlier)
        try await repo.save(outside)

        let fetched = try await repo.sessions(in: wholeDayInterval())
        #expect(fetched.map(\.id) == [earlier.id, later.id])
    }

    @Test
    func deleteRemovesSession() async throws {
        let repo = try makeRepository()
        let session = Session(startedAt: day, mode: .flowmodoro)
        try await repo.save(session)
        try await repo.deleteSession(id: session.id)
        let fetched = try await repo.sessions(in: wholeDayInterval())
        #expect(fetched.isEmpty)
    }

    @Test
    func savesAndFetchesReflectionBySessionID() async throws {
        let repo = try makeRepository()
        let sessionID = UUID()
        let reflection = Reflection(sessionID: sessionID, emoji: ["🟢"], note: "Smooth", createdAt: day)
        try await repo.save(reflection)

        let fetched = try await repo.reflection(forSessionID: sessionID)
        #expect(fetched == reflection)
        #expect(try await repo.reflection(forSessionID: UUID()) == nil)
    }

    @Test
    func reflectionIsOnePerSession() async throws {
        let repo = try makeRepository()
        let sessionID = UUID()
        try await repo.save(Reflection(sessionID: sessionID, emoji: ["🟡"], note: "first", createdAt: day))
        // Re-reflecting on the same session (different reflection id) replaces.
        try await repo.save(Reflection(sessionID: sessionID, emoji: ["🟢"], note: "second", createdAt: day.addingTimeInterval(60)))

        let fetched = try await repo.reflection(forSessionID: sessionID)
        #expect(fetched?.emoji == ["🟢"])
        #expect(fetched?.note == "second")
    }

    @Test
    func intentionStatsAreDeduplicatedWithUseCountAndRecency() async throws {
        let repo = try makeRepository()
        try await repo.recordIntention("Refactor auth", at: day)
        try await repo.recordIntention("Write docs", at: day.addingTimeInterval(60))
        // Re-using the first intention later bumps its count and recency.
        try await repo.recordIntention("Refactor auth", at: day.addingTimeInterval(120))

        let stats = try await repo.recentIntentionStats(limit: 10)
        #expect(stats.map(\.text) == ["Refactor auth", "Write docs"])
        let refactor = try #require(stats.first)
        #expect(refactor.useCount == 2)
        #expect(refactor.lastUsedAt == day.addingTimeInterval(120))
    }

    @Test
    func recordIntentionIgnoresBlankAndTrimsWhitespace() async throws {
        let repo = try makeRepository()
        try await repo.recordIntention("   ", at: day)
        try await repo.recordIntention("  Plan the week  ", at: day)

        let stats = try await repo.recentIntentionStats(limit: 10)
        #expect(stats.map(\.text) == ["Plan the week"])
    }

    @Test
    func recentIntentionStatsRespectLimit() async throws {
        let repo = try makeRepository()
        for index in 0..<5 {
            try await repo.recordIntention("intention \(index)", at: day.addingTimeInterval(TimeInterval(index)))
        }
        let stats = try await repo.recentIntentionStats(limit: 3)
        #expect(stats.count == 3)
        // Most recent first.
        #expect(stats.first?.text == "intention 4")
    }

    @Test
    func readPathSkipsRowsThatFailValidation() async throws {
        // Plant a valid and an invalid row (the latter reversed: ended before
        // it started) through the repository's own context, bypassing save()'s
        // validation, then confirm the read path drops the invalid one.
        let repo = try makeRepository()
        let valid = Session(
            startedAt: day,
            endedAt: day.addingTimeInterval(600),
            mode: .flowmodoro,
            endReason: .completed
        )
        // Build the invalid value via the unvalidated memberwise initializer
        // (save() would reject it); the timer/UI can never produce this.
        let invalid = Session(
            startedAt: day,
            endedAt: day.addingTimeInterval(-600),
            mode: .flowmodoro,
            endReason: .completed
        )
        try await repo.insertUncheckedForTesting(valid)
        try await repo.insertUncheckedForTesting(invalid)

        let fetched = try await repo.sessions(in: wholeDayInterval())
        #expect(fetched.count == 1)
        #expect(fetched.first?.endedAt == day.addingTimeInterval(600))
    }
}

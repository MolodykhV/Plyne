import Foundation
import SwiftData
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
    func recentIntentionsAreDeduplicatedAndOrderedByRecency() async throws {
        let repo = try makeRepository()
        try await repo.recordIntention("Refactor auth", at: day)
        try await repo.recordIntention("Write docs", at: day.addingTimeInterval(60))
        // Re-using the first intention later makes it the most recent.
        try await repo.recordIntention("Refactor auth", at: day.addingTimeInterval(120))

        let suggestions = try await repo.recentIntentions(limit: 10)
        #expect(suggestions.map(\.text) == ["Refactor auth", "Write docs"])
        #expect(suggestions.allSatisfy { $0.source == .history })
    }

    @Test
    func recordIntentionIgnoresBlankAndTrimsWhitespace() async throws {
        let repo = try makeRepository()
        try await repo.recordIntention("   ", at: day)
        try await repo.recordIntention("  Plan the week  ", at: day)

        let suggestions = try await repo.recentIntentions(limit: 10)
        #expect(suggestions.map(\.text) == ["Plan the week"])
    }

    @Test
    func recentIntentionsRespectsLimit() async throws {
        let repo = try makeRepository()
        for index in 0..<5 {
            try await repo.recordIntention("intention \(index)", at: day.addingTimeInterval(TimeInterval(index)))
        }
        let suggestions = try await repo.recentIntentions(limit: 3)
        #expect(suggestions.count == 3)
        // Most recent first.
        #expect(suggestions.first?.text == "intention 4")
    }

    @Test
    func readPathSkipsRowsThatFailValidation() async throws {
        // Inject an invalid row (ended before it started) directly, bypassing
        // save()'s validation, then confirm the read path drops it.
        let container = try SwiftDataRepository.makeContainer(inMemory: true)
        let repo = SwiftDataRepository(modelContainer: container)

        let context = ModelContext(container)
        let valid = SessionRecord(
            Session(startedAt: day, endedAt: day.addingTimeInterval(600), mode: .flowmodoro, endReason: .completed)
        )
        let invalid = SessionRecord(
            id: UUID(),
            startedAt: day,
            endedAt: day.addingTimeInterval(-600), // reversed interval
            modeData: SessionModeCoding.encode(.flowmodoro),
            intention: nil,
            categoryHint: nil,
            endReason: .completed
        )
        context.insert(valid)
        context.insert(invalid)
        try context.save()

        let fetched = try await repo.sessions(in: wholeDayInterval())
        #expect(fetched.count == 1)
        #expect(fetched.first?.endedAt == day.addingTimeInterval(600))
    }
}

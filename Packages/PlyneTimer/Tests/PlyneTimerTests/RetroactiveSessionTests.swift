import Foundation
import Testing
import PlyneCore
@testable import PlyneTimer

@Suite("Retroactive session builder")
struct RetroactiveSessionTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func buildsValidatedRetroactiveSession() throws {
        let session = try FocusTimer.retroactiveSession(
            startedAt: start,
            endedAt: start.addingTimeInterval(45 * 60),
            mode: .flowmodoro,
            intention: "Catch-up notes"
        )
        #expect(session.endReason == .retroactive)
        let duration = try #require(session.duration)
        #expect(duration == 45 * 60)
        #expect(session.intention == "Catch-up notes")
    }

    @Test
    func rejectsReversedInterval() {
        #expect(throws: DomainError.sessionEndedBeforeStarted) {
            _ = try FocusTimer.retroactiveSession(
                startedAt: start,
                endedAt: start.addingTimeInterval(-60),
                mode: .flowmodoro
            )
        }
    }

    @Test
    func rejectsInvalidPomodoroDurations() {
        #expect(throws: DomainError.invalidPomodoroDurations(workMinutes: 0, breakMinutes: 5)) {
            _ = try FocusTimer.retroactiveSession(
                startedAt: start,
                endedAt: start.addingTimeInterval(60),
                mode: .pomodoro(workMinutes: 0, breakMinutes: 5)
            )
        }
    }
}

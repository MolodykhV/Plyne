import Foundation
import Testing
@testable import PlyneCore

@Suite("Session")
struct SessionTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func isActiveWhenEndedAtIsNil() throws {
        let session = Session(startedAt: start, mode: .flowmodoro)
        #expect(session.isActive)
        #expect(session.duration == nil)
        #expect(session.endReason == nil)
        try session.validate()
    }

    @Test
    func durationMatchesEndedAtMinusStartedAt() {
        let session = Session(
            startedAt: start,
            endedAt: start.addingTimeInterval(1500),
            mode: .flowmodoro,
            endReason: .completed
        )
        #expect(!session.isActive)
        #expect(session.duration == 1500)
    }

    @Test
    func validateRejectsEndedBeforeStarted() {
        let session = Session(
            startedAt: start,
            endedAt: start.addingTimeInterval(-1),
            mode: .flowmodoro,
            endReason: .completed
        )
        #expect(throws: DomainError.sessionEndedBeforeStarted) {
            try session.validate()
        }
    }

    @Test
    func validateAcceptsEqualStartedAndEnded() throws {
        // Zero-duration sessions are unusual but possible (e.g. an immediately
        // cancelled retroactive entry). Domain accepts them; the UI may warn.
        let session = Session(
            startedAt: start,
            endedAt: start,
            mode: .flowmodoro,
            endReason: .userEnded
        )
        try session.validate()
    }

    @Test
    func validatePropagatesModeErrors() {
        // Active session (endReason nil) so the coupling check passes and
        // validation reaches the mode check.
        let session = Session(
            startedAt: start,
            mode: .pomodoro(workMinutes: 0, breakMinutes: 5)
        )
        #expect(throws: DomainError.invalidPomodoroDurations(workMinutes: 0, breakMinutes: 5)) {
            try session.validate()
        }
    }

    @Test
    func validateRejectsActiveSessionWithEndReason() {
        let session = Session(
            startedAt: start,
            mode: .flowmodoro,
            endReason: .completed
        )
        #expect(throws: DomainError.activeSessionHasEndReason) {
            try session.validate()
        }
    }

    @Test
    func validateRejectsEndedSessionWithoutEndReason() {
        let session = Session(
            startedAt: start,
            endedAt: start.addingTimeInterval(1500),
            mode: .flowmodoro
        )
        #expect(throws: DomainError.endedSessionMissingEndReason) {
            try session.validate()
        }
    }

    @Test
    func validateAcceptsEndedSessionWithReason() throws {
        let session = Session(
            startedAt: start,
            endedAt: start.addingTimeInterval(1500),
            mode: .flowmodoro,
            endReason: .userEnded
        )
        try session.validate()
    }

    @Test
    func codableRoundTrip() throws {
        let original = Session(
            startedAt: start,
            endedAt: start.addingTimeInterval(1500),
            mode: .pomodoro(workMinutes: 25, breakMinutes: 5),
            intention: "Finish API design",
            categoryHint: "code",
            endReason: .completed
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Session.self, from: data)
        #expect(decoded == original)
    }

    @Test
    func equalSessionsHashIdentically() {
        let id = UUID()
        let lhs = Session(id: id, startedAt: start, mode: .flowmodoro)
        let rhs = Session(id: id, startedAt: start, mode: .flowmodoro)
        #expect(lhs == rhs)
        #expect(lhs.hashValue == rhs.hashValue)
    }
}

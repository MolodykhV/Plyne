import Foundation
import Testing
@testable import PlyneCore

@Suite("SessionOverlap")
struct SessionOverlapTests {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func session(startMinutes: Double, durationMinutes: Double) -> Session {
        let start = base.addingTimeInterval(startMinutes * 60)
        return Session(
            startedAt: start,
            endedAt: start.addingTimeInterval(durationMinutes * 60),
            mode: .flowmodoro,
            endReason: .completed
        )
    }

    private func candidate(startMinutes: Double, durationMinutes: Double) -> (start: Date, end: Date) {
        let start = base.addingTimeInterval(startMinutes * 60)
        return (start, start.addingTimeInterval(durationMinutes * 60))
    }

    @Test
    func noSessionsMeansNoOverlap() {
        let candidate = candidate(startMinutes: 0, durationMinutes: 30)
        #expect(SessionOverlap.overlapping(start: candidate.start, end: candidate.end, in: []).isEmpty)
    }

    @Test
    func disjointBeforeAndAfterDoNotOverlap() {
        let existing = [session(startMinutes: 0, durationMinutes: 30)]
        let before = candidate(startMinutes: -60, durationMinutes: 30)
        let after = candidate(startMinutes: 60, durationMinutes: 30)
        #expect(SessionOverlap.overlapping(start: before.start, end: before.end, in: existing).isEmpty)
        #expect(SessionOverlap.overlapping(start: after.start, end: after.end, in: existing).isEmpty)
    }

    @Test
    func touchingEndpointsAreAdjacentNotOverlapping() {
        let existing = [session(startMinutes: 0, durationMinutes: 30)]
        // Candidate ends exactly when existing starts.
        let justBefore = candidate(startMinutes: -30, durationMinutes: 30)
        // Candidate starts exactly when existing ends.
        let justAfter = candidate(startMinutes: 30, durationMinutes: 30)
        #expect(SessionOverlap.overlapping(start: justBefore.start, end: justBefore.end, in: existing).isEmpty)
        #expect(SessionOverlap.overlapping(start: justAfter.start, end: justAfter.end, in: existing).isEmpty)
    }

    @Test
    func partialOverlapIsDetected() {
        let existing = [session(startMinutes: 0, durationMinutes: 30)]
        // Starts inside the existing session, ends after it.
        let overlapping = candidate(startMinutes: 15, durationMinutes: 30)
        #expect(SessionOverlap.overlapping(start: overlapping.start, end: overlapping.end, in: existing).count == 1)
    }

    @Test
    func candidateContainingExistingIsDetected() {
        let existing = [session(startMinutes: 10, durationMinutes: 10)]
        let candidate = candidate(startMinutes: 0, durationMinutes: 60)
        #expect(SessionOverlap.overlapping(start: candidate.start, end: candidate.end, in: existing).count == 1)
    }

    @Test
    func existingContainingCandidateIsDetected() {
        let existing = [session(startMinutes: 0, durationMinutes: 60)]
        let candidate = candidate(startMinutes: 20, durationMinutes: 10)
        #expect(SessionOverlap.overlapping(start: candidate.start, end: candidate.end, in: existing).count == 1)
    }

    @Test
    func reversedOrEmptyCandidateNeverOverlaps() {
        let existing = [session(startMinutes: 0, durationMinutes: 60)]
        let start = base.addingTimeInterval(10 * 60)
        // end == start (empty) and end < start (reversed).
        #expect(SessionOverlap.overlapping(start: start, end: start, in: existing).isEmpty)
        #expect(SessionOverlap.overlapping(start: start, end: start.addingTimeInterval(-60), in: existing).isEmpty)
    }

    @Test
    func runningSessionOverlapsOnlyWhenItsStartIsInsideCandidate() {
        let runningStart = base.addingTimeInterval(15 * 60)
        let running = Session(startedAt: runningStart, mode: .flowmodoro)  // no endedAt
        let containing = candidate(startMinutes: 0, durationMinutes: 30)   // contains the start
        let disjoint = candidate(startMinutes: 30, durationMinutes: 30)    // after the start
        #expect(SessionOverlap.overlapping(start: containing.start, end: containing.end, in: [running]).count == 1)
        #expect(SessionOverlap.overlapping(start: disjoint.start, end: disjoint.end, in: [running]).isEmpty)
    }

    @Test
    func returnsAllOverlappingSessions() {
        let existing = [
            session(startMinutes: 0, durationMinutes: 20),
            session(startMinutes: 25, durationMinutes: 20),
            session(startMinutes: 120, durationMinutes: 20)
        ]
        let candidate = candidate(startMinutes: 10, durationMinutes: 40)  // hits first two, not the third
        #expect(SessionOverlap.overlapping(start: candidate.start, end: candidate.end, in: existing).count == 2)
    }
}

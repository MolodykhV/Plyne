import Foundation
import Testing
@testable import PlyneCore

@Suite("CalendarBlock")
struct CalendarBlockTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func durationMatchesEndedAtMinusStartedAt() {
        let block = CalendarBlock(
            startedAt: start,
            endedAt: start.addingTimeInterval(1800),
            title: "1:1",
            kind: .meeting
        )
        #expect(block.duration == 1800)
    }

    @Test
    func validateRejectsEndedBeforeStarted() {
        let block = CalendarBlock(
            startedAt: start,
            endedAt: start.addingTimeInterval(-1),
            title: "Bad event",
            kind: .other
        )
        #expect(throws: DomainError.calendarBlockEndedBeforeStarted) {
            try block.validate()
        }
    }

    @Test
    func validateRejectsZeroLengthBlock() {
        let block = CalendarBlock(
            startedAt: start,
            endedAt: start,
            title: "Zero-length",
            kind: .other
        )
        #expect(throws: DomainError.calendarBlockEndedBeforeStarted) {
            try block.validate()
        }
    }

    @Test
    func validateAcceptsForwardInterval() throws {
        let block = CalendarBlock(
            startedAt: start,
            endedAt: start.addingTimeInterval(60),
            title: "OK",
            kind: .focus
        )
        try block.validate()
    }

    @Test
    func codableRoundTrip() throws {
        let original = CalendarBlock(
            startedAt: start,
            endedAt: start.addingTimeInterval(1800),
            title: "Roadmap review",
            kind: .meeting
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CalendarBlock.self, from: data)
        #expect(decoded == original)
    }

    @Test
    func kindRawValuesAreStable() {
        // Locked because storage and CSV/JSON export depend on these strings.
        #expect(CalendarBlock.Kind.meeting.rawValue == "meeting")
        #expect(CalendarBlock.Kind.lunch.rawValue == "lunch")
        #expect(CalendarBlock.Kind.focus.rawValue == "focus")
        #expect(CalendarBlock.Kind.other.rawValue == "other")
        #expect(CalendarBlock.Kind.allCases.count == 4)
    }
}

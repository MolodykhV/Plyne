import Foundation
import Testing
@testable import PlyneCore

@Suite("CalendarBlockMapper")
struct CalendarBlockMapperTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func event(
        id: String = "evt-1",
        title: String = "Event",
        durationMinutes: Double = 30,
        isAllDay: Bool = false,
        hasAttendees: Bool = false,
        isBusy: Bool = true,
        isCancelled: Bool = false
    ) -> RawCalendarEvent {
        RawCalendarEvent(
            id: id,
            title: title,
            start: start,
            end: start.addingTimeInterval(durationMinutes * 60),
            isAllDay: isAllDay,
            hasAttendees: hasAttendees,
            isBusy: isBusy,
            isCancelled: isCancelled
        )
    }

    @Test
    func busyWithAttendeesIsMeeting() {
        let block = CalendarBlockMapper.block(from: event(hasAttendees: true, isBusy: true))
        #expect(block?.kind == .meeting)
    }

    @Test
    func busySoloIsFocus() {
        let block = CalendarBlockMapper.block(from: event(hasAttendees: false, isBusy: true))
        #expect(block?.kind == .focus)
    }

    @Test
    func freeTimeIsOther() {
        // Free, regardless of attendees, is ambient — never blocks the timer.
        #expect(CalendarBlockMapper.block(from: event(hasAttendees: true, isBusy: false))?.kind == .other)
        #expect(CalendarBlockMapper.block(from: event(hasAttendees: false, isBusy: false))?.kind == .other)
    }

    @Test
    func cancelledIsDropped() {
        #expect(CalendarBlockMapper.block(from: event(isCancelled: true)) == nil)
    }

    @Test
    func allDayIsDropped() {
        #expect(CalendarBlockMapper.block(from: event(isAllDay: true, hasAttendees: true)) == nil)
    }

    @Test
    func zeroLengthOrReversedIsDropped() {
        #expect(CalendarBlockMapper.block(from: event(durationMinutes: 0)) == nil)
        #expect(CalendarBlockMapper.block(from: event(durationMinutes: -10)) == nil)
    }

    @Test
    func mappedBlockCarriesTimesAndTitle() throws {
        let block = try #require(CalendarBlockMapper.block(from: event(title: "1:1", durationMinutes: 45, hasAttendees: true)))
        #expect(block.title == "1:1")
        #expect(block.startedAt == start)
        #expect(block.endedAt == start.addingTimeInterval(45 * 60))
        try block.validate()
    }

    @Test
    func idIsStableAcrossMappingsOfTheSameEvent() {
        // A re-fetch (same source id) must yield the same block id so the UI
        // doesn't churn.
        let first = CalendarBlockMapper.block(from: event(id: "stable-id", hasAttendees: true))
        let second = CalendarBlockMapper.block(from: event(id: "stable-id", hasAttendees: true))
        #expect(first?.id == second?.id)
        let different = CalendarBlockMapper.block(from: event(id: "other-id", hasAttendees: true))
        #expect(first?.id != different?.id)
    }

    @Test
    func blocksFiltersAndPreservesOrder() {
        let events = [
            event(id: "a", hasAttendees: true, isBusy: true),   // meeting
            event(id: "b", isAllDay: true),                     // dropped
            event(id: "c", isBusy: true)                        // focus
        ]
        let blocks = CalendarBlockMapper.blocks(from: events)
        #expect(blocks.map(\.kind) == [.meeting, .focus])
    }
}

@Suite("DeterministicUUID")
struct DeterministicUUIDTests {
    @Test
    func sameStringYieldsSameUUID() {
        #expect(DeterministicUUID.from("event-123") == DeterministicUUID.from("event-123"))
    }

    @Test
    func differentStringsYieldDifferentUUIDs() {
        #expect(DeterministicUUID.from("a") != DeterministicUUID.from("b"))
        #expect(DeterministicUUID.from("") != DeterministicUUID.from("x"))
    }

    @Test
    func producesAWellFormedV4ShapedUUID() {
        let uuid = DeterministicUUID.from("anything").uuid
        #expect((uuid.6 & 0xF0) == 0x40)   // version nibble
        #expect((uuid.8 & 0xC0) == 0x80)   // variant bits
    }
}

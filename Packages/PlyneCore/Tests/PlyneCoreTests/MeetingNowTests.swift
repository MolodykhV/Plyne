import Foundation
import Testing
@testable import PlyneCore

@Suite("MeetingNow")
struct MeetingNowTests {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func block(kind: CalendarBlock.Kind, startMin: Double, durMin: Double, title: String = "m") -> CalendarBlock {
        let start = base.addingTimeInterval(startMin * 60)
        return CalendarBlock(startedAt: start, endedAt: start.addingTimeInterval(durMin * 60), title: title, kind: kind)
    }

    @Test
    func detectsActiveMeeting() {
        let blocks = [block(kind: .meeting, startMin: 0, durMin: 30)]
        #expect(MeetingNow.active(in: blocks, at: base.addingTimeInterval(10 * 60)) != nil)
    }

    @Test
    func intervalIsHalfOpen() {
        let blocks = [block(kind: .meeting, startMin: 0, durMin: 30)]
        // At exactly start → active; at exactly end → not (belongs to the next).
        #expect(MeetingNow.active(in: blocks, at: base) != nil)
        #expect(MeetingNow.active(in: blocks, at: base.addingTimeInterval(30 * 60)) == nil)
    }

    @Test
    func onlyMeetingKindBlocks() {
        let now = base.addingTimeInterval(10 * 60)
        #expect(MeetingNow.active(in: [block(kind: .focus, startMin: 0, durMin: 30)], at: now) == nil)
        #expect(MeetingNow.active(in: [block(kind: .other, startMin: 0, durMin: 30)], at: now) == nil)
        #expect(MeetingNow.active(in: [block(kind: .lunch, startMin: 0, durMin: 30)], at: now) == nil)
    }

    @Test
    func overlappingMeetingsPickLatestStarting() {
        let blocks = [
            block(kind: .meeting, startMin: 0, durMin: 60, title: "broad"),
            block(kind: .meeting, startMin: 20, durMin: 20, title: "specific")
        ]
        let active = MeetingNow.active(in: blocks, at: base.addingTimeInterval(25 * 60))
        #expect(active?.title == "specific")
    }

    @Test
    func noMeetingWhenIdle() {
        let blocks = [block(kind: .meeting, startMin: 0, durMin: 30)]
        #expect(MeetingNow.active(in: blocks, at: base.addingTimeInterval(120 * 60)) == nil)
        #expect(MeetingNow.active(in: [], at: base) == nil)
    }
}

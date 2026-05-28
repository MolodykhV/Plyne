import Foundation
import Testing
@testable import PlyneCore

@Suite("SessionEndReason")
struct SessionEndReasonTests {
    @Test
    func rawValuesAreStable() {
        #expect(SessionEndReason.completed.rawValue == "completed")
        #expect(SessionEndReason.userEnded.rawValue == "userEnded")
        #expect(SessionEndReason.interrupted.rawValue == "interrupted")
        #expect(SessionEndReason.retroactive.rawValue == "retroactive")
        #expect(SessionEndReason.allCases.count == 4)
    }
}

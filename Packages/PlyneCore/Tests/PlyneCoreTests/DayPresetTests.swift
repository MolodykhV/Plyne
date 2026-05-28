import Foundation
import Testing
@testable import PlyneCore

@Suite("DayPreset")
struct DayPresetTests {
    @Test
    func rawValuesAreStable() {
        // Storage and exports lean on these strings.
        #expect(DayPreset.deepWork.rawValue == "deepWork")
        #expect(DayPreset.meetingHeavy.rawValue == "meetingHeavy")
        #expect(DayPreset.light.rawValue == "light")
        #expect(DayPreset.allCases.count == 3)
    }

    @Test
    func codableRoundTripThroughRawValue() throws {
        for preset in DayPreset.allCases {
            let data = try JSONEncoder().encode(preset)
            let decoded = try JSONDecoder().decode(DayPreset.self, from: data)
            #expect(decoded == preset)
        }
    }
}

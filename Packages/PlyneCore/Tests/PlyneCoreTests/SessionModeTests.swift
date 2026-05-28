import Foundation
import Testing
@testable import PlyneCore

@Suite("SessionMode")
struct SessionModeTests {
    @Test
    func pomodoroValidatesPositiveWork() {
        #expect(throws: DomainError.invalidPomodoroDurations(workMinutes: 0, breakMinutes: 5)) {
            try SessionMode.pomodoro(workMinutes: 0, breakMinutes: 5).validate()
        }
    }

    @Test
    func pomodoroAllowsZeroBreak() throws {
        try SessionMode.pomodoro(workMinutes: 25, breakMinutes: 0).validate()
    }

    @Test
    func pomodoroRejectsNegativeBreak() {
        #expect(throws: DomainError.invalidPomodoroDurations(workMinutes: 25, breakMinutes: -1)) {
            try SessionMode.pomodoro(workMinutes: 25, breakMinutes: -1).validate()
        }
    }

    @Test
    func flowmodoroAlwaysValidates() throws {
        try SessionMode.flowmodoro.validate()
    }

    @Test
    func overflowAlwaysValidates() throws {
        let parent = UUID()
        try SessionMode.overflow(parent: parent).validate()
    }

    @Test("Codable round-trip preserves associated values", arguments: [
        SessionMode.pomodoro(workMinutes: 25, breakMinutes: 5),
        SessionMode.pomodoro(workMinutes: 50, breakMinutes: 10),
        SessionMode.flowmodoro,
        SessionMode.overflow(parent: UUID())
    ])
    func codable(_ mode: SessionMode) throws {
        let data = try JSONEncoder().encode(mode)
        let decoded = try JSONDecoder().decode(SessionMode.self, from: data)
        #expect(decoded == mode)
    }

    // The wire shape is a persistence/export contract. These fixtures fail
    // loudly if the encoded representation ever drifts.

    @Test
    func decodesStableWireFormat() throws {
        let pomodoro = try decode(#"{"type":"pomodoro","workMinutes":25,"breakMinutes":5}"#)
        #expect(pomodoro == .pomodoro(workMinutes: 25, breakMinutes: 5))

        let flow = try decode(#"{"type":"flowmodoro"}"#)
        #expect(flow == .flowmodoro)

        let parent = UUID()
        let overflow = try decode(#"{"type":"overflow","parent":"\#(parent.uuidString)"}"#)
        #expect(overflow == .overflow(parent: parent))
    }

    @Test
    func encodesFlatTypeDiscriminator() throws {
        let object = try encodeToObject(.pomodoro(workMinutes: 25, breakMinutes: 5))
        #expect(object["type"] as? String == "pomodoro")
        #expect(object["workMinutes"] as? Int == 25)
        #expect(object["breakMinutes"] as? Int == 5)

        let flow = try encodeToObject(.flowmodoro)
        #expect(flow["type"] as? String == "flowmodoro")
        #expect(flow.keys.count == 1)
    }

    private func decode(_ json: String) throws -> SessionMode {
        try JSONDecoder().decode(SessionMode.self, from: Data(json.utf8))
    }

    private func encodeToObject(_ mode: SessionMode) throws -> [String: Any] {
        let data = try JSONEncoder().encode(mode)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

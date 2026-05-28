import Foundation
import Testing
@testable import PlyneCore

@Suite("Reflection")
struct ReflectionTests {
    private let sessionID = UUID()
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func validateAcceptsOneEmoji() throws {
        let reflection = Reflection(
            sessionID: sessionID,
            emoji: ["🟢"],
            createdAt: now
        )
        try reflection.validate()
    }

    @Test
    func validateAcceptsTwoEmoji() throws {
        let reflection = Reflection(
            sessionID: sessionID,
            emoji: ["🟢", "🟡"],
            note: "Got pulled into Slack mid-way",
            createdAt: now
        )
        try reflection.validate()
    }

    @Test
    func validateRejectsZeroEmoji() {
        let reflection = Reflection(
            sessionID: sessionID,
            emoji: [],
            createdAt: now
        )
        #expect(throws: DomainError.invalidReflectionEmojiCount(0)) {
            try reflection.validate()
        }
    }

    @Test
    func validateRejectsThreeOrMoreEmoji() {
        let reflection = Reflection(
            sessionID: sessionID,
            emoji: ["🟢", "🟡", "🔵"],
            createdAt: now
        )
        #expect(throws: DomainError.invalidReflectionEmojiCount(3)) {
            try reflection.validate()
        }
    }

    @Test
    func codableRoundTrip() throws {
        let original = Reflection(
            sessionID: sessionID,
            emoji: ["🟢"],
            note: "Smooth session.",
            createdAt: now
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Reflection.self, from: data)
        #expect(decoded == original)
    }
}

import Foundation

/// Optional post-session feedback: 1–2 emoji and an optional note.
///
/// The concept doc forbids emoji almost everywhere in Plyne; this is the
/// one deliberate exception, used as a low-friction post-session check-in.
/// Anything richer (scores, sliders, "rate your focus") would re-introduce
/// the judgmental framing the product is built to avoid.
public struct Reflection: Identifiable, Hashable, Sendable, Codable {
    /// Stable identifier.
    public let id: UUID

    /// Session this reflection belongs to.
    public let sessionID: UUID

    /// 1 or 2 emoji chosen by the user. Each entry should be a single
    /// grapheme cluster; the type does not enforce this beyond count.
    public let emoji: [String]

    /// Optional free-text note.
    public let note: String?

    /// When the reflection was recorded.
    public let createdAt: Date

    /// Memberwise initializer.
    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        emoji: [String],
        note: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.sessionID = sessionID
        self.emoji = emoji
        self.note = note
        self.createdAt = createdAt
    }

    /// Throws if the emoji count is outside the allowed 1...2 range.
    public func validate() throws {
        guard (1...2).contains(emoji.count) else {
            throw DomainError.invalidReflectionEmojiCount(emoji.count)
        }
    }
}

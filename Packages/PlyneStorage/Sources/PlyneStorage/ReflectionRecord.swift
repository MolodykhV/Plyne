import Foundation
import SwiftData
import PlyneCore

/// SwiftData persistence record for a post-session reflection.
@Model
final class ReflectionRecord {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var emoji: [String]
    var note: String?
    var createdAt: Date

    init(id: UUID, sessionID: UUID, emoji: [String], note: String?, createdAt: Date) {
        self.id = id
        self.sessionID = sessionID
        self.emoji = emoji
        self.note = note
        self.createdAt = createdAt
    }
}

extension ReflectionRecord {
    convenience init(_ reflection: Reflection) {
        self.init(
            id: reflection.id,
            sessionID: reflection.sessionID,
            emoji: reflection.emoji,
            note: reflection.note,
            createdAt: reflection.createdAt
        )
    }

    func apply(_ reflection: Reflection) {
        sessionID = reflection.sessionID
        emoji = reflection.emoji
        note = reflection.note
        createdAt = reflection.createdAt
    }

    func toDomain() -> Reflection {
        Reflection(
            id: id,
            sessionID: sessionID,
            emoji: emoji,
            note: note,
            createdAt: createdAt
        )
    }
}

import Foundation
import SwiftData
import PlyneCore

/// SwiftData persistence record for a focus session.
///
/// Mirrors ``PlyneCore/Session`` one-to-one. `mode` is stored as encoded
/// `Data` rather than a typed property: SwiftData treats an enum with
/// associated values as a composite attribute and cannot persist
/// ``PlyneCore/SessionMode`` directly, so we lean on its stable flat-tagged
/// `Codable` form (locked by tests in `PlyneCore`). `endReason` is a
/// String-backed enum, which SwiftData stores natively. The repository maps
/// to and from the value type so persistence objects never escape the store.
@Model
final class SessionRecord {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var modeData: Data
    var intention: String?
    var categoryHint: String?
    var endReason: SessionEndReason?

    init(
        id: UUID,
        startedAt: Date,
        endedAt: Date?,
        modeData: Data,
        intention: String?,
        categoryHint: String?,
        endReason: SessionEndReason?
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.modeData = modeData
        self.intention = intention
        self.categoryHint = categoryHint
        self.endReason = endReason
    }
}

extension SessionRecord {
    convenience init(_ session: Session) {
        self.init(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            modeData: SessionModeCoding.encode(session.mode),
            intention: session.intention,
            categoryHint: session.categoryHint,
            endReason: session.endReason
        )
    }

    func apply(_ session: Session) {
        startedAt = session.startedAt
        endedAt = session.endedAt
        modeData = SessionModeCoding.encode(session.mode)
        intention = session.intention
        categoryHint = session.categoryHint
        endReason = session.endReason
    }

    /// Rebuilds the domain value, or `nil` if the stored mode can't be
    /// decoded (corruption or a future-version write the read path will skip).
    func toDomain() -> Session? {
        guard let mode = SessionModeCoding.decode(modeData) else { return nil }
        return Session(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            mode: mode,
            intention: intention,
            categoryHint: categoryHint,
            endReason: endReason
        )
    }
}

/// Encodes ``PlyneCore/SessionMode`` to and from the `Data` blob persisted
/// in ``SessionRecord``.
enum SessionModeCoding {
    static func encode(_ mode: SessionMode) -> Data {
        // The flat-tagged Codable form never fails to encode for our cases;
        // an empty blob on the impossible failure decodes back to nil and is
        // skipped on read.
        (try? JSONEncoder().encode(mode)) ?? Data()
    }

    static func decode(_ data: Data) -> SessionMode? {
        try? JSONDecoder().decode(SessionMode.self, from: data)
    }
}

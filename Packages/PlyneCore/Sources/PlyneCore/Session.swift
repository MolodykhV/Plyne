import Foundation

/// A single focus session captured by Plyne.
///
/// `Session` is a pure value type; it carries no behaviour beyond simple
/// computed properties and an explicit ``validate()`` check. Persistence
/// lives in `PlyneStorage`, timer state in `PlyneTimer`.
public struct Session: Identifiable, Hashable, Sendable, Codable {
    /// Stable identifier; survives edits and persists across launches.
    public let id: UUID

    /// Wall-clock instant the user (or the retroactive flow) started the
    /// session.
    public let startedAt: Date

    /// Wall-clock instant the session ended, or `nil` while it is still
    /// running.
    public let endedAt: Date?

    /// Which timing model produced this session.
    public let mode: SessionMode

    /// User-stated intention shown in the pre-session prompt, if any.
    /// Per the concept doc this is optional — skipping the prompt is a
    /// supported path.
    public let intention: String?

    /// Optional bucket label such as `"code"`, `"writing"`, `"meetings"`.
    /// Source (manual vs inferred) is not tracked here.
    public let categoryHint: String?

    /// Why the session ended, or `nil` while it is still running. Set in
    /// lockstep with ``endedAt`` — ``validate()`` enforces that an active
    /// session carries no reason and an ended session always carries one.
    public let endReason: SessionEndReason?

    /// Memberwise initializer.
    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        mode: SessionMode,
        intention: String? = nil,
        categoryHint: String? = nil,
        endReason: SessionEndReason? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.mode = mode
        self.intention = intention
        self.categoryHint = categoryHint
        self.endReason = endReason
    }

    /// `true` while the session is open (no `endedAt` recorded).
    public var isActive: Bool { endedAt == nil }

    /// Total elapsed time, or `nil` while the session is still running.
    public var duration: TimeInterval? {
        endedAt.map { $0.timeIntervalSince(startedAt) }
    }

    /// Throws if the value violates a domain invariant.
    ///
    /// Constructors do not auto-validate so that the storage and decoding
    /// paths can build a value first and decide policy on a per-caller
    /// basis. Live timer code and retroactive entry both call this before
    /// committing.
    public func validate() throws {
        if let endedAt, endedAt < startedAt {
            throw DomainError.sessionEndedBeforeStarted
        }
        switch (isActive, endReason) {
        case (true, .some):
            throw DomainError.activeSessionHasEndReason
        case (false, .none):
            throw DomainError.endedSessionMissingEndReason
        default:
            break
        }
        try mode.validate()
    }
}

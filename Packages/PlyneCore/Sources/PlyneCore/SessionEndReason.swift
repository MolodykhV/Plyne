import Foundation

/// Why a session ended. The reason is informational only — Plyne does not
/// rank sessions by completion, and the concept doc forbids reframing
/// `userEnded` or `interrupted` as failure modes in any user-facing copy.
public enum SessionEndReason: String, Hashable, Sendable, Codable, CaseIterable {
    /// The timer reached the planned end of the work phase.
    case completed

    /// The user ended the session manually before the timer expired.
    case userEnded

    /// An external event (system sleep, app crash, AFK detection) terminated
    /// the session.
    case interrupted

    /// The session was added after the fact via the retroactive entry flow.
    case retroactive
}

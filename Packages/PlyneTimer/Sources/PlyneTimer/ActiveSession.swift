import Foundation
import PlyneCore

/// The mutable-over-time facts of a session while the timer is driving it.
///
/// Distinct from ``PlyneCore/Session``: an `ActiveSession` has no `endedAt`
/// or `endReason` yet — those are decided at the moment the timer produces
/// a finished `Session`.
public struct ActiveSession: Equatable, Sendable {
    /// Identity carried through to the eventual ``PlyneCore/Session``.
    public let id: UUID

    /// Mode chosen before the session started.
    public let mode: SessionMode

    /// Intention captured in the pre-session prompt, if any.
    public let intention: String?

    /// Instant the work phase started.
    public let startedAt: Date

    /// Memberwise initializer.
    public init(id: UUID = UUID(), mode: SessionMode, intention: String?, startedAt: Date) {
        self.id = id
        self.mode = mode
        self.intention = intention
        self.startedAt = startedAt
    }

    /// `true` when the mode is Pomodoro.
    public var isPomodoro: Bool {
        if case .pomodoro = mode { return true }
        return false
    }

    /// The instant the Pomodoro work phase is scheduled to ring, or `nil`
    /// for open-ended (Flowmodoro/overflow) modes.
    public var pomodoroWorkEnd: Date? {
        guard case let .pomodoro(workMinutes, _) = mode else { return nil }
        return startedAt.addingTimeInterval(TimeInterval(workMinutes) * 60)
    }
}

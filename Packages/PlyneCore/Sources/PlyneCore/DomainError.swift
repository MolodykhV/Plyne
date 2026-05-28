import Foundation

/// Validation errors raised by ``PlyneCore`` value types.
///
/// Domain types intentionally allow construction of arbitrary values for
/// flexibility (factories, decoding, tests). Invariants are checked by
/// ``Session/validate()``, ``CalendarBlock/validate()``, and friends, which
/// throw one of these cases on violation.
public enum DomainError: Error, Hashable, Sendable {
    /// A ``Session`` ended before it started.
    case sessionEndedBeforeStarted

    /// A still-running ``Session`` (no `endedAt`) was given an `endReason`.
    case activeSessionHasEndReason

    /// A finished ``Session`` (`endedAt` set) is missing its `endReason`.
    case endedSessionMissingEndReason

    /// A ``CalendarBlock`` ended at or before it started.
    case calendarBlockEndedBeforeStarted

    /// ``Reflection/emoji`` did not contain 1–2 entries, as required by the
    /// concept doc's post-session reflection rule.
    case invalidReflectionEmojiCount(Int)

    /// Pomodoro durations are outside the allowed range
    /// (work must be > 0, break must be ≥ 0).
    case invalidPomodoroDurations(workMinutes: Int, breakMinutes: Int)
}

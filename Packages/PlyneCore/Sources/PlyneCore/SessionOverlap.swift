import Foundation

/// Detects whether a candidate session interval overlaps already-recorded
/// sessions.
///
/// Used by the retroactive-entry flow to **warn**, never block — per the
/// concept's respect for autonomy ("предупреждение, не ошибка"). Pure and
/// deterministic, so it is fully unit-testable without persistence.
public enum SessionOverlap {
    /// The sessions whose time range overlaps `[start, end)`.
    ///
    /// Overlap is strict: a session that merely *touches* the candidate (one
    /// ends exactly when the other starts) is adjacent, not overlapping, and
    /// is excluded. A still-running session (no `endedAt`) is treated as the
    /// instant `[startedAt, startedAt]` and overlaps only if its start falls
    /// strictly inside the candidate.
    ///
    /// - Returns: the overlapping sessions, in the order given. Empty if the
    ///   candidate interval is empty or reversed (`end <= start`).
    public static func overlapping(
        start: Date,
        end: Date,
        in sessions: [Session]
    ) -> [Session] {
        guard end > start else { return [] }
        return sessions.filter { session in
            let sessionEnd = session.endedAt ?? session.startedAt
            return start < sessionEnd && session.startedAt < end
        }
    }
}

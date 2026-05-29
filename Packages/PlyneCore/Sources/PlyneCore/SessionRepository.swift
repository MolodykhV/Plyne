import Foundation

/// The persistence contract Plyne's UI and services depend on.
///
/// Declared here, in the pure-domain layer, so callers depend on the
/// abstraction rather than on SwiftData. The macOS-only `PlyneStorage`
/// module provides the concrete implementation. All methods traffic only
/// in `Sendable` value types — no persistence objects cross this boundary.
public protocol SessionRepository: Sendable {
    /// Inserts the session, or updates the existing one with the same `id`.
    /// Implementations validate before writing and throw on an invalid value.
    func save(_ session: Session) async throws

    /// Sessions that started within `interval`, oldest first. Implementations
    /// skip any stored row that fails validation rather than failing the
    /// whole query.
    func sessions(in interval: DateInterval) async throws -> [Session]

    /// Deletes the session with `id`, if present. A no-op when absent.
    func deleteSession(id: UUID) async throws

    /// Inserts or updates the reflection for its session.
    func save(_ reflection: Reflection) async throws

    /// The reflection attached to `sessionID`, if any.
    func reflection(forSessionID sessionID: UUID) async throws -> Reflection?

    /// Records that `text` was used as an intention at `date`, bumping its
    /// recency and use count. Blank text is ignored.
    func recordIntention(_ text: String, at date: Date) async throws

    /// A recent window of intention stats (most-recently-used first, capped at
    /// `limit`) for ``IntentionRanker`` to score. Storage stays a raw data
    /// source — ranking is pure and lives in the caller, which owns the clock.
    func recentIntentionStats(limit: Int) async throws -> [IntentionStat]
}

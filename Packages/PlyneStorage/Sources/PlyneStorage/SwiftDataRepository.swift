import Foundation
import SwiftData
import PlyneCore

/// SwiftData-backed ``PlyneCore/SessionRepository``.
///
/// `@ModelActor` gives the repository its own actor-isolated `ModelContext`,
/// so it is safe to use off the main actor and satisfies Swift 6 strict
/// concurrency. `@Model` records never leave the actor — every method maps
/// to or from the `Sendable` domain value types.
@ModelActor
public actor SwiftDataRepository: SessionRepository {

    // MARK: - Construction

    /// Builds a repository backed by the on-disk store (or an in-memory
    /// store for tests).
    public static func make(inMemory: Bool = false) throws -> SwiftDataRepository {
        SwiftDataRepository(modelContainer: try makeContainer(inMemory: inMemory))
    }

    /// Builds the model container for the current schema. On disk it lives at
    /// `Application Support/Plyne/Plyne.store`. Internal: callers construct a
    /// repository through ``make(inMemory:)``; tests reach this via
    /// `@testable import`.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: PlyneCurrentSchema.self)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            configuration = ModelConfiguration(schema: schema, url: try defaultStoreURL())
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func defaultStoreURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("Plyne", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Plyne.store")
    }

    // MARK: - Sessions

    public func save(_ session: Session) async throws {
        try session.validate()
        // Referential integrity for `.overflow(parent:)` (that the parent
        // session exists) is intentionally not enforced here yet — deferred
        // per the 1.4 plan note; the live timer never produces overflow modes.
        let id = session.id
        let descriptor = FetchDescriptor<SessionRecord>(predicate: #Predicate { $0.id == id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(session)
        } else {
            modelContext.insert(SessionRecord(session))
        }
        try modelContext.save()
    }

    public func sessions(in interval: DateInterval) async throws -> [Session] {
        let start = interval.start
        let end = interval.end
        let descriptor = FetchDescriptor<SessionRecord>(
            predicate: #Predicate { $0.startedAt >= start && $0.startedAt < end },
            sortBy: [SortDescriptor(\.startedAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor).compactMap(Self.validatedDomain)
    }

    public func deleteSession(id: UUID) async throws {
        let descriptor = FetchDescriptor<SessionRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(record)
        try modelContext.save()
    }

    // MARK: - Reflections

    public func save(_ reflection: Reflection) async throws {
        try reflection.validate()
        // A session has at most one reflection, so upsert on sessionID (not
        // the reflection's own id) — re-reflecting on a session replaces the
        // previous note rather than piling up rows.
        let sessionID = reflection.sessionID
        let descriptor = FetchDescriptor<ReflectionRecord>(predicate: #Predicate { $0.sessionID == sessionID })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(reflection)
        } else {
            modelContext.insert(ReflectionRecord(reflection))
        }
        try modelContext.save()
    }

    public func reflection(forSessionID sessionID: UUID) async throws -> Reflection? {
        let descriptor = FetchDescriptor<ReflectionRecord>(predicate: #Predicate { $0.sessionID == sessionID })
        guard let record = try modelContext.fetch(descriptor).first else { return nil }
        let reflection = record.toDomain()
        // Drop a corrupt row rather than surfacing an invalid value.
        guard (try? reflection.validate()) != nil else { return nil }
        return reflection
    }

    // MARK: - Intentions

    public func recordIntention(_ text: String, at date: Date) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let descriptor = FetchDescriptor<IntentionEntry>(predicate: #Predicate { $0.text == trimmed })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.useCount += 1
            existing.lastUsedAt = max(existing.lastUsedAt, date)
        } else {
            modelContext.insert(IntentionEntry(text: trimmed, useCount: 1, lastUsedAt: date))
        }
        try modelContext.save()
    }

    public func recentIntentionStats(limit: Int) async throws -> [IntentionStat] {
        guard limit > 0 else { return [] }
        var descriptor = FetchDescriptor<IntentionEntry>(
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor).map { $0.toStat() }
    }

    // MARK: - Helpers

    /// Maps a record to its domain value, returning `nil` if the row can't be
    /// decoded or violates a domain invariant (corruption or a future-version
    /// write).
    private static func validatedDomain(_ record: SessionRecord) -> Session? {
        guard let session = record.toDomain() else { return nil }
        guard (try? session.validate()) != nil else { return nil }
        return session
    }
}

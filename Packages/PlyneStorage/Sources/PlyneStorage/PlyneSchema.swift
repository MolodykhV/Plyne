import Foundation
import SwiftData

/// Version 1 of Plyne's persistence schema.
///
/// Wrapping the models in a `VersionedSchema` from the very first release
/// means a future change ships as a `SchemaMigrationPlan` step (V1 → V2)
/// instead of an ad-hoc fix. `CalendarEventCache` is intentionally absent
/// until calendar integration (step 1.9); adding a brand-new model later is
/// an additive, automatic migration.
enum PlyneSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [SessionRecord.self, ReflectionRecord.self, IntentionEntry.self]
    }
}

/// The schema the app currently runs on. Bump this alias (and add a
/// migration stage) when a new versioned schema is introduced.
typealias PlyneCurrentSchema = PlyneSchemaV1

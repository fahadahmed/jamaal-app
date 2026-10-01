import Foundation
import SwiftData

/// Version 1 of the schema: the 14 models of docs/schema/overview.md.
public enum JamaalSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
    public static var models: [any PersistentModel.Type] {
        [
            TaskItem.self,
            TaskCategory.self,
            DeferralRecord.self,
            WorkSession.self,
            Habit.self,
            HabitTimeWindow.self,
            HabitEntry.self,
            HabitGroup.self,
            Anchor.self,
            AnchorRule.self,
            DayPlan.self,
            NightPlanningSession.self,
            NudgeLog.self,
            UserSettings.self,
        ]
    }
}

/// Migrations from day one, even while V1 is the only version (CloudKit's production schema is append-only).
public enum JamaalMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [JamaalSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

/// Builds the app's `ModelContainer`.
public enum JamaalSchema {
    /// The current schema.
    public static var current: Schema { Schema(versionedSchema: JamaalSchemaV1.self) }

    /// A container for the current schema.
    ///
    /// - Parameter inMemory: `true` for tests and previews.
    /// - Parameter configuration: a custom configuration, for example with `cloudKitDatabase`
    ///   set by the app once the iCloud container exists. When given, `inMemory` is ignored.
    @MainActor
    public static func makeContainer(
        inMemory: Bool = false,
        configuration: ModelConfiguration? = nil
    ) throws -> ModelContainer {
        let config = configuration ?? ModelConfiguration(
            schema: current,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: current,
            migrationPlan: JamaalMigrationPlan.self,
            configurations: [config]
        )
    }
}

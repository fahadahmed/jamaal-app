import Foundation
import SwiftData

/// Export my data (ST-08): a JSON file of every record of every model, always available (subscribed or not, online or
/// not). Each model is written out by hand rather than by reflection, so the file never depends on SwiftData's private
/// layout; a test checks the writers against the schema, so a field added later without one fails the build's tests.
///
/// Dates are ISO 8601 text, ids are UUID text, an absent value is `null`, and a link to another record is that record's
/// id under `<name>ID` (a to-many link is written on the other side as its to-one, so nothing is lost or repeated).
public enum DataExport {
    public static let formatVersion = 1

    /// The whole export as pretty, key-sorted JSON.
    @MainActor
    public static func json(in context: ModelContext, now: Date) throws -> Data {
        let tables = try records(in: context)
        var counts: [String: Int] = [:]
        for (name, rows) in tables { counts[name] = rows.count }
        let document: [String: Any] = [
            "app": "Jamaal",
            "format": formatVersion,
            "exportedAt": iso(now),
            "counts": counts,
            "records": tables,
        ]
        return try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys])
    }

    /// Every entity name in the schema with its rows, each row a flat dictionary, rows in a stable order.
    @MainActor
    public static func records(in context: ModelContext) throws -> [String: [[String: Any]]] {
        var tables: [String: [[String: Any]]] = [:]
        tables["Anchor"] = try rows(Anchor.self, context) { [
            ("title", $0.title), ("occurrenceDate", $0.occurrenceDate), ("slotKey", $0.slotKey), ("windowStart", $0.windowStart),
            ("windowEnd", $0.windowEnd), ("effortMinutes", $0.effortMinutes), ("attendanceStatus", $0.attendanceStatus),
            ("resolvedAt", $0.resolvedAt), ("remindBeforeStartMinutes", $0.remindBeforeStartMinutes),
            ("remindBeforeEndMinutes", $0.remindBeforeEndMinutes), ("generatedAt", $0.generatedAt), ("ruleID", $0.rule?.id)] }
        tables["AnchorRule"] = try rows(AnchorRule.self, context) { [
            ("title", $0.title), ("sourceKey", $0.sourceKey), ("configData", $0.configData), ("effortMinutes", $0.effortMinutes),
            ("placement", $0.placement), ("isEnabled", $0.isEnabled), ("isArchived", $0.isArchived), ("createdAt", $0.createdAt)] }
        tables["DayPlan"] = try rows(DayPlan.self, context) { [
            ("date", $0.date), ("capacity", $0.capacity), ("plannedTaskMinutes", $0.plannedTaskMinutes), ("freeMinutes", $0.freeMinutes),
            ("committedMinutes", $0.committedMinutes), ("completedEffortMinutes", $0.completedEffortMinutes), ("loadScore", $0.loadScore),
            ("wasOverloaded", $0.wasOverloaded), ("completionRate", $0.completionRate), ("completionBasis", $0.completionBasis),
            ("planningCompletedAt", $0.planningCompletedAt)] }
        tables["DeferralRecord"] = try rows(DeferralRecord.self, context) { [
            ("deferredOn", $0.deferredOn), ("day", $0.day), ("deferredTo", $0.deferredTo), ("reason", $0.reason), ("taskID", $0.task?.id)] }
        tables["Habit"] = try rows(Habit.self, context) { [
            ("title", $0.title), ("notes", $0.notes), ("presetKey", $0.presetKey), ("kind", $0.kind), ("frequency", $0.frequency),
            ("scheduledDays", $0.scheduledDays), ("targetPerWeek", $0.targetPerWeek), ("pausesData", $0.pausesData),
            ("isArchived", $0.isArchived), ("createdAt", $0.createdAt), ("groupID", $0.group?.id)] }
        tables["HabitEntry"] = try rows(HabitEntry.self, context) { [
            ("date", $0.date), ("target", $0.target), ("amount", $0.amount), ("completedAt", $0.completedAt), ("windowID", $0.window?.id)] }
        tables["HabitGroup"] = try rows(HabitGroup.self, context) { [
            ("title", $0.title), ("sortOrder", $0.sortOrder), ("isArchived", $0.isArchived), ("createdAt", $0.createdAt)] }
        tables["HabitTimeWindow"] = try rows(HabitTimeWindow.self, context) { [
            ("label", $0.label), ("startMinute", $0.startMinute), ("endMinute", $0.endMinute), ("target", $0.target),
            ("effortMinutes", $0.effortMinutes), ("reminderMinute", $0.reminderMinute), ("habitID", $0.habit?.id)] }
        tables["NightPlanningSession"] = try rows(NightPlanningSession.self, context) { [
            ("forDate", $0.forDate), ("currentStep", $0.currentStep), ("isComplete", $0.isComplete), ("isShortened", $0.isShortened),
            ("skippedAt", $0.skippedAt), ("createdAt", $0.createdAt), ("completedAt", $0.completedAt)] }
        tables["NudgeLog"] = try rows(NudgeLog.self, context) { [
            ("kind", $0.kind), ("subjectKey", $0.subjectKey), ("sentAt", $0.sentAt), ("dismissedAt", $0.dismissedAt)] }
        tables["TaskCategory"] = try rows(TaskCategory.self, context) { [
            ("name", $0.name), ("presetKey", $0.presetKey), ("colorKey", $0.colorKey), ("sortOrder", $0.sortOrder),
            ("isArchived", $0.isArchived), ("createdAt", $0.createdAt)] }
        tables["TaskItem"] = try rows(TaskItem.self, context) { [
            ("title", $0.title), ("notes", $0.notes), ("dueDate", $0.dueDate), ("effortMinutes", $0.effortMinutes),
            ("importance", $0.importance), ("isCompleted", $0.isCompleted), ("completedAt", $0.completedAt), ("droppedAt", $0.droppedAt),
            ("deferralCount", $0.deferralCount), ("repeatKind", $0.repeatKind), ("repeatWeekdays", $0.repeatWeekdays),
            ("repeatDayOfMonth", $0.repeatDayOfMonth), ("seriesID", $0.seriesID), ("createdAt", $0.createdAt), ("categoryID", $0.category?.id)] }
        tables["UserSettings"] = try rows(UserSettings.self, context) { [
            ("mediumDayMinutes", $0.mediumDayMinutes), ("dayStartMinute", $0.dayStartMinute), ("dayEndMinute", $0.dayEndMinute),
            ("rolloverMinute", $0.rolloverMinute), ("weekdayLevels", $0.weekdayLevels), ("planningMinute", $0.planningMinute),
            ("morningMinute", $0.morningMinute), ("onboardingCompletedAt", $0.onboardingCompletedAt), ("firstLaunchAt", $0.firstLaunchAt),
            ("createdAt", $0.createdAt)] }
        tables["WorkSession"] = try rows(WorkSession.self, context) { [
            ("startedAt", $0.startedAt), ("day", $0.day), ("endedAt", $0.endedAt), ("pausedSeconds", $0.pausedSeconds),
            ("pausedAt", $0.pausedAt), ("estimateMinutes", $0.estimateMinutes), ("outcome", $0.outcome), ("actualSeconds", $0.actualSeconds),
            ("taskID", $0.task?.id), ("habitWindowID", $0.habitWindow?.id)] }
        return tables
    }

    // MARK: Writing

    @MainActor
    private static func rows<T: PersistentModel>(_ type: T.Type, _ context: ModelContext, _ fields: (T) -> [(String, Any?)]) throws -> [[String: Any]] {
        let models = try context.fetch(FetchDescriptor<T>())
        return models.map { model -> [String: Any] in
            var row: [String: Any] = ["id": identifier(of: model)]
            for (name, value) in fields(model) { row[name] = encoded(value) }
            return row
        }
        .sorted { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") }
    }

    /// Every model carries a stable `id: UUID`.
    private static func identifier<T: PersistentModel>(of model: T) -> String {
        switch model {
        case let m as Anchor: m.id.uuidString
        case let m as AnchorRule: m.id.uuidString
        case let m as DayPlan: m.id.uuidString
        case let m as DeferralRecord: m.id.uuidString
        case let m as Habit: m.id.uuidString
        case let m as HabitEntry: m.id.uuidString
        case let m as HabitGroup: m.id.uuidString
        case let m as HabitTimeWindow: m.id.uuidString
        case let m as NightPlanningSession: m.id.uuidString
        case let m as NudgeLog: m.id.uuidString
        case let m as TaskCategory: m.id.uuidString
        case let m as TaskItem: m.id.uuidString
        case let m as UserSettings: m.id.uuidString
        case let m as WorkSession: m.id.uuidString
        default: ""
        }
    }

    private static func encoded(_ value: Any?) -> Any {
        guard let value else { return NSNull() }
        switch value {
        case let date as Date: return iso(date)
        case let id as UUID: return id.uuidString
        case let optional as Optional<Any> where optional == nil: return NSNull()
        default: return value
        }
    }

    private static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

/// Delete my data (ST-08): every record of every model. The app asks twice before calling this, then starts again at first
/// launch. With sync on, deleting the records is what removes the copy from the account too.
public enum DataReset {

    @MainActor
    public static func deleteEverything(in context: ModelContext) throws {
        // Children before parents, each fetched and deleted so relationship rules are honoured.
        try wipe(WorkSession.self, context)
        try wipe(HabitEntry.self, context)
        try wipe(DeferralRecord.self, context)
        try wipe(Anchor.self, context)
        try wipe(HabitTimeWindow.self, context)
        try wipe(Habit.self, context)
        try wipe(HabitGroup.self, context)
        try wipe(AnchorRule.self, context)
        try wipe(TaskItem.self, context)
        try wipe(TaskCategory.self, context)
        try wipe(DayPlan.self, context)
        try wipe(NightPlanningSession.self, context)
        try wipe(NudgeLog.self, context)
        try wipe(UserSettings.self, context)
        try context.save()
    }

    @MainActor
    private static func wipe<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<T>()) { context.delete(model) }
    }
}

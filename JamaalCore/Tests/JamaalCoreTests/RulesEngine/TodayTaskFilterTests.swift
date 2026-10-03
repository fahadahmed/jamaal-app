import Foundation
import Testing
@testable import JamaalCore

/// The category filter (docs/journeys/today-list.md): it narrows the **Tasks** only, never reorders them,
/// and a task with no category is shown only when no filter is on.
@MainActor
struct TodayTaskFilterTests {

    private func category(_ name: String) -> TaskCategory { TaskCategory(name: name) }
    private func task(_ title: String, _ category: TaskCategory?) -> TaskItem {
        let t = TaskItem(title: title)
        t.category = category
        return t
    }

    @Test func noFilterKeepsEverythingInOrder() {
        let work = category("Work")
        let tasks = [task("a", work), task("b", nil), task("c", category("Family"))]
        #expect(TodayTaskFilter.apply(tasks, to: nil).map(\.title) == ["a", "b", "c"])
    }

    @Test func aFilterKeepsOnlyThatCategoryAndTheEnginesOrder() {
        let work = category("Work"), family = category("Family")
        let tasks = [task("a", work), task("b", family), task("c", work), task("d", nil)]
        #expect(TodayTaskFilter.apply(tasks, to: work).map(\.title) == ["a", "c"])
        #expect(TodayTaskFilter.apply(tasks, to: family).map(\.title) == ["b"])
    }

    @Test func aTaskWithoutACategoryIsHiddenByAnyFilter() {
        let work = category("Work")
        #expect(TodayTaskFilter.apply([task("x", nil)], to: work).isEmpty)
    }

    @Test func aFilterNobodyUsesIsEmptyNotAnError() {
        #expect(TodayTaskFilter.apply([task("a", category("Work"))], to: category("Family")).isEmpty)
    }

    @Test func categoriesAreComparedByIdentityNotByName() {
        let one = category("Work"), twin = category("Work")
        #expect(TodayTaskFilter.apply([task("a", one)], to: twin).isEmpty)
    }

    @Test func theOptionsAreTheActiveCategoriesInTheirOwnOrder() {
        let a = category("Personal"); a.sortOrder = 0
        let b = category("Family"); b.sortOrder = 1
        let c = category("Old"); c.sortOrder = 2; c.isArchived = true
        #expect(TodayTaskFilter.options([c, b, a]).map(\.name) == ["Personal", "Family"])
    }
}

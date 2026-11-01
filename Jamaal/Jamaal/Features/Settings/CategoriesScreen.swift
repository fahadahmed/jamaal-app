//
//  CategoriesScreen.swift
//  Jamaal
//

import SwiftData
import SwiftUI
import ThreadsTokens
import JamaalCore
import UniformTypeIdentifiers

/// Categories (ST-04): a short list of personal labels. Tap one to rename it, pick one of five colours, move it or
/// archive it; archived labels are kept below with Restore.
struct CategoriesScreen: View {
    @Environment(\.threads) private var threads
    @Environment(\.requireAccess) private var requireAccess
    @Environment(\.modelContext) private var context
    @Query private var all: [TaskCategory]
    @State private var openID: UUID?
    @State private var draftName = ""
    @State private var adding = false
    @State private var newName = ""
    @State private var newColor: CategoryColor = .plum
    @State private var message: String?
    @State private var archivedOpen = false
    @SwiftUI.FocusState private var focused: Bool

    private var active: [TaskCategory] { all.filter { !$0.isArchived }.sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) } }
    private var archived: [TaskCategory] { all.filter(\.isArchived).sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) } }

    var body: some View {
        #if os(macOS)
        macForm
        #else
        phoneBody
        #endif
    }

    private var phoneBody: some View {
        SettingsPage(title: "Categories", subtitle: SettingsCopy.categoriesSubtitle(active: active.count), trailing: {
            AnyView(Button(action: startAdding) {
                Image(systemName: "plus").font(.title3).foregroundStyle(threads.ink)
                    .frame(width: 48, height: 48).glassEffect(.regular.interactive(), in: Circle()).contentShape(Circle())
            }
            .buttonStyle(.plain).accessibilityLabel("Add a category").accessibilityIdentifier("addCategory"))
        }) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(active, id: \.id) { category in
                    if openID == category.id { editCard(category) } else { row(category) }
                    Divider().overlay(threads.line)
                }
                if adding { addCard }
            }
            if let message, openID == nil && !adding {
                Text(message).threadsType(.body).foregroundStyle(threads.terra).accessibilityIdentifier("settingsMessage")
            }
            if !archived.isEmpty { archivedSection }
        }
    }

    // MARK: Rows

    private func row(_ category: TaskCategory) -> some View {
        HStack(spacing: ThreadsSpace.row) {
            Circle().fill(JamaalPalette.categoryColor(forKey: category.colorKey)).frame(width: 12, height: 12)
            Text(category.name).threadsType(.lede).foregroundStyle(threads.ink)
            Spacer()
            Image(systemName: "line.3.horizontal").foregroundStyle(threads.ink3).accessibilityHidden(true)
        }
        .frame(minHeight: 60).contentShape(Rectangle())
        .onTapGesture { open(category) }
        .draggable(category.id.uuidString)
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first.flatMap(UUID.init(uuidString:)), let moved = active.first(where: { $0.id == id }),
                  let to = active.firstIndex(where: { $0.id == category.id }) else { return false }
            guard requireAccess(.editCategory) else { return false }
            try? CategoryEditing.move(moved, to: to, in: context)
            return true
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("category-\(category.name)")
    }

    private func editCard(_ category: TaskCategory) -> some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.row) {
            HStack {
                Circle().fill(JamaalPalette.categoryColor(forKey: category.colorKey)).frame(width: 12, height: 12)
                TextField("Name", text: $draftName).threadsType(.lede).foregroundStyle(threads.ink).focused($focused)
                    .submitLabel(.done).onSubmit { finishEditing(category) }.accessibilityIdentifier("categoryName")
                Button("Done") { finishEditing(category) }.threadsType(.row).foregroundStyle(threads.ink).buttonStyle(.plain)
                    .frame(minHeight: ThreadsHit.minimum).accessibilityIdentifier("categoryDone")
            }
            colours(selected: category.color) { color in try? CategoryEditing.setColor(color, on: category) }
            HStack(spacing: ThreadsSpace.section) {
                Button("Archive") { CategoryEditing.archive(category); close() }
                    .accessibilityIdentifier("categoryArchive")
                Button("Move up") { move(category, by: -1) }.accessibilityIdentifier("categoryUp")
                Button("Move down") { move(category, by: 1) }.accessibilityIdentifier("categoryDown")
            }
            .threadsType(.row).foregroundStyle(threads.ink).buttonStyle(.plain)
            if let message { Text(message).threadsType(.body).foregroundStyle(threads.terra).accessibilityIdentifier("settingsMessage") }
        }
        .padding(ThreadsSpace.row)
        .background(RoundedRectangle(cornerRadius: ThreadsRadius.card).fill(threads.card))
        .padding(.vertical, ThreadsSpace.tight)
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.row) {
            HStack {
                Circle().fill(JamaalPalette.categoryColor(forKey: newColor.rawValue)).frame(width: 12, height: 12)
                TextField("Name", text: $newName).threadsType(.lede).foregroundStyle(threads.ink).focused($focused)
                    .submitLabel(.done).onSubmit(add).accessibilityIdentifier("newCategoryName")
                Button("Add", action: add).threadsType(.row).foregroundStyle(threads.ink).buttonStyle(.plain)
                    .frame(minHeight: ThreadsHit.minimum).accessibilityIdentifier("newCategoryAdd")
            }
            colours(selected: newColor) { newColor = $0 }
            Button("Cancel") { adding = false; message = nil }.threadsType(.row).foregroundStyle(threads.ink2).buttonStyle(.plain)
            if let message { Text(message).threadsType(.body).foregroundStyle(threads.terra).accessibilityIdentifier("settingsMessage") }
        }
        .padding(ThreadsSpace.row)
        .background(RoundedRectangle(cornerRadius: ThreadsRadius.card).fill(threads.card))
        .padding(.vertical, ThreadsSpace.tight)
    }

    private func colours(selected: CategoryColor, pick: @escaping (CategoryColor) -> Void) -> some View {
        HStack(spacing: ThreadsSpace.row) {
            ForEach(CategoryEditing.colors, id: \.self) { color in
                Button { pick(color) } label: {
                    Circle().fill(JamaalPalette.categoryColor(forKey: color.rawValue)).frame(width: 28, height: 28)
                        .frame(width: 52, height: 52)
                        .overlay(Circle().strokeBorder(selected == color ? threads.ink : threads.line2, lineWidth: selected == color ? 2 : 1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.rawValue.capitalized)
                .accessibilityAddTraits(selected == color ? .isSelected : [])
                .accessibilityIdentifier("colour-\(color.rawValue)")
            }
        }
    }

    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            Button { withAnimation(.snappy) { archivedOpen.toggle() } } label: {
                HStack {
                    Text("ARCHIVED · \(archived.count)").threadsType(.label).foregroundStyle(threads.ink2)
                    Spacer()
                    Image(systemName: archivedOpen ? "chevron.up" : "chevron.down").foregroundStyle(threads.ink3)
                }
                .frame(minHeight: ThreadsHit.minimum).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier("categoriesArchivedToggle")
            if archivedOpen {
                ForEach(archived, id: \.id) { category in
                    HStack(spacing: ThreadsSpace.row) {
                        Circle().fill(JamaalPalette.categoryColor(forKey: category.colorKey)).frame(width: 12, height: 12)
                        Text(category.name).threadsType(.lede).foregroundStyle(threads.ink2)
                        Spacer()
                        Button("Restore") { restore(category) }.threadsType(.row).foregroundStyle(threads.ink).buttonStyle(.plain)
                            .frame(minHeight: ThreadsHit.minimum).accessibilityLabel("Restore \(category.name)")
                    }
                }
            }
        }
    }

    // MARK: Changes

    private func open(_ category: TaskCategory) {
        guard requireAccess(.editCategory) else { return }
        message = nil; adding = false
        draftName = category.name
        openID = category.id
        focused = true
    }

    private func close() { openID = nil; message = nil; focused = false }

    private func finishEditing(_ category: TaskCategory) {
        do {
            try CategoryEditing.rename(category, to: draftName, in: context)
            close()
        } catch let error as SettingsError { message = SettingsCopy.message(for: error) }
        catch { message = "That couldn't be saved. Try again." }
    }

    private func startAdding() {
        guard requireAccess(.createCategory) else { return }
        openID = nil; message = nil
        guard (try? CategoryEditing.canAdd(in: context)) ?? false else { message = SettingsCopy.message(for: .tooManyCategories); return }
        newName = ""
        let used = Set(active.map(\.color))
        newColor = CategoryEditing.colors.first { !used.contains($0) } ?? .accent
        adding = true
        focused = true
    }

    private func add() {
        do {
            try CategoryEditing.add(name: newName, color: newColor, in: context, now: .now)
            adding = false; message = nil; focused = false
        } catch let error as SettingsError { message = SettingsCopy.message(for: error) }
        catch { message = "That couldn't be saved. Try again." }
    }

    private func move(_ category: TaskCategory, by step: Int) {
        guard let index = active.firstIndex(where: { $0.id == category.id }) else { return }
        try? CategoryEditing.move(category, to: index + step, in: context)
    }

    private func restore(_ category: TaskCategory) {
        guard requireAccess(.archiveOrRestore) else { return }
        do { try CategoryEditing.restore(category, in: context); message = nil }
        catch let error as SettingsError { message = SettingsCopy.message(for: error) }
        catch { message = "That couldn't be restored. Try again." }
    }
}

#if os(macOS)
// MARK: The Mac form (#367)

/// The same categories as the iPhone page, as a grouped Mac form: each name is a field you edit in place (Return saves it), a small menu
/// picks its colour, Archive is on the row, rows reorder by dragging or from the right-click menu, and Add and Archived sit under the list.
extension CategoriesScreen {
    @ViewBuilder fileprivate var macForm: some View {
        Form {
            Section {
                ForEach(active, id: \.id) { category in
                    MacCategoryRow(
                        category: category, canMoveUp: active.first?.id != category.id, canMoveDown: active.last?.id != category.id,
                        rename: { macRename(category, to: $0) }, colour: { macColour(category, $0) },
                        archive: { macArchive(category) }, move: { macMove(category, by: $0) })
                }
                .onMove { from, to in
                    guard let index = from.first, active.indices.contains(index) else { return }
                    macMove(active[index], by: (to > index ? to - 1 : to) - index)
                }
                if adding { macAddRow }
                Button("Add category…", action: startAdding).accessibilityIdentifier("addCategory")
            } header: {
                MacSectionHeader("Categories")
            } footer: {
                Text(SettingsCopy.categoriesSubtitle(active: active.count)).threadsType(.meta).foregroundStyle(threads.ink2)
            }
            if let message, !adding {
                Section { MacFormNote(message, isError: true).accessibilityIdentifier("settingsMessage") }
            }
            if !archived.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $archivedOpen) {
                        ForEach(archived, id: \.id) { category in
                            LabeledContent {
                                Button("Restore") { restore(category) }.accessibilityLabel("Restore \(category.name)")
                            } label: {
                                HStack(spacing: ThreadsSpace.tight) {
                                    Circle().fill(JamaalPalette.categoryColor(forKey: category.colorKey)).frame(width: 10, height: 10)
                                    Text(category.name).threadsType(.body).foregroundStyle(threads.ink2)
                                }
                            }
                        }
                    } label: { MacSectionHeader("Archived · \(archived.count)") }
                    .accessibilityIdentifier("categoriesArchivedToggle")
                }
            }
        }
        .macSettingsForm()
    }

    private var macAddRow: some View {
        VStack(alignment: .leading, spacing: ThreadsSpace.tight) {
            HStack(spacing: ThreadsSpace.row) {
                MacColourMenu(selected: newColor) { newColor = $0 }
                TextField("Name", text: $newName).textFieldStyle(.roundedBorder).labelsHidden().focused($focused)
                    .onSubmit(add).accessibilityIdentifier("newCategoryName")
                Button("Add", action: add).buttonStyle(.borderedProminent).accessibilityIdentifier("newCategoryAdd")
                Button("Cancel") { adding = false; message = nil }.accessibilityIdentifier("newCategoryCancel")
            }
            if let message { MacFormNote(message, isError: true).accessibilityIdentifier("settingsMessage") }
        }
    }

    private func macRename(_ category: TaskCategory, to name: String) -> Bool {
        guard requireAccess(.editCategory) else { return false }
        do { try CategoryEditing.rename(category, to: name, in: context); message = nil; return true }
        catch let error as SettingsError { message = SettingsCopy.message(for: error); return false }
        catch { message = "That couldn't be saved. Try again."; return false }
    }

    private func macColour(_ category: TaskCategory, _ color: CategoryColor) {
        guard requireAccess(.editCategory) else { return }
        try? CategoryEditing.setColor(color, on: category)
    }

    private func macArchive(_ category: TaskCategory) {
        guard requireAccess(.archiveOrRestore) else { return }
        CategoryEditing.archive(category)
    }

    private func macMove(_ category: TaskCategory, by step: Int) {
        guard step != 0, requireAccess(.editCategory), let index = active.firstIndex(where: { $0.id == category.id }) else { return }
        try? CategoryEditing.move(category, to: index + step, in: context)
    }
}

/// A row of the Mac list: the colour, the name as a field that saves on Return (a name that is refused goes back to what it was), and Archive.
private struct MacCategoryRow: View {
    @Environment(\.threads) private var threads
    let category: TaskCategory
    let canMoveUp: Bool
    let canMoveDown: Bool
    let rename: (String) -> Bool
    let colour: (CategoryColor) -> Void
    let archive: () -> Void
    let move: (Int) -> Void
    @State private var draft: String

    init(category: TaskCategory, canMoveUp: Bool, canMoveDown: Bool, rename: @escaping (String) -> Bool,
         colour: @escaping (CategoryColor) -> Void, archive: @escaping () -> Void, move: @escaping (Int) -> Void) {
        self.category = category; self.canMoveUp = canMoveUp; self.canMoveDown = canMoveDown
        self.rename = rename; self.colour = colour; self.archive = archive; self.move = move
        _draft = State(initialValue: category.name)
    }

    var body: some View {
        HStack(spacing: ThreadsSpace.row) {
            MacColourMenu(selected: category.color, pick: colour)
            TextField("Name", text: $draft).textFieldStyle(.plain).labelsHidden().threadsType(.body).foregroundStyle(threads.ink)
                .onSubmit { if !rename(draft) { draft = category.name } }
                .accessibilityIdentifier("categoryName")
            Spacer(minLength: 0)
            Button("Archive", action: archive).buttonStyle(.borderless).accessibilityIdentifier("categoryArchive")
        }
        .onChange(of: category.name) { _, name in draft = name }            // a rename that arrived from another device
        .contextMenu {
            Button("Move up") { move(-1) }.disabled(!canMoveUp)
            Button("Move down") { move(1) }.disabled(!canMoveDown)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("category-\(category.name)")
    }
}

/// A category's colour: a small dot that opens a menu of the five.
private struct MacColourMenu: View {
    let selected: CategoryColor
    let pick: (CategoryColor) -> Void

    var body: some View {
        Menu {
            ForEach(CategoryEditing.colors, id: \.self) { color in
                Button { pick(color) } label: {
                    Label(color.rawValue.capitalized, systemImage: selected == color ? "checkmark.circle.fill" : "circle.fill")
                        .foregroundStyle(JamaalPalette.categoryColor(forKey: color.rawValue))
                }
                .accessibilityIdentifier("colour-\(color.rawValue)")
            }
        } label: {
            Image(systemName: "circle.fill").font(.system(size: 14)).foregroundStyle(JamaalPalette.categoryColor(forKey: selected.rawValue))
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .tint(JamaalPalette.categoryColor(forKey: selected.rawValue))      // the form's accent would otherwise colour every dot the same
        .accessibilityLabel("Colour")
    }
}
#endif

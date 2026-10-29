import SwiftUI
import SwiftData

private func priorityColor(_ p: String) -> Color {
    switch p {
    case "high": AZ.red
    case "medium": Color(hex: 0xF59E0B)
    case "low": AZ.emerald
    default: Color(hex: 0x666666)
    }
}

private func nextPriority(_ p: String) -> String {
    switch p {
    case "none": "low"
    case "low": "medium"
    case "medium": "high"
    default: "none"
    }
}

struct TodosView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TodoTask.createdAt, order: .reverse) private var tasks: [TodoTask]
    @State private var newTitle = ""
    @State private var notesTask: TodoTask?
    @State private var remindTask: TodoTask?
    @State private var pendingDelete: TodoTask?
    @State private var showCompleted = true
    @FocusState private var focused: Bool

    private var active: [TodoTask] {
        let order = ["high": 0, "medium": 1, "low": 2, "none": 3]
        return tasks.filter { !$0.isDone }.sorted { (order[$0.priority] ?? 3, $1.createdAt) < (order[$1.priority] ?? 3, $0.createdAt) }
    }
    private var done: [TodoTask] { tasks.filter(\.isDone).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) } }

    var body: some View {
        ZStack {
            ImageBackdrop(url: AZImages.featureBackground, overlay: Color(hex: 0x050211, opacity: 0.65))
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack(alignment: .bottomLeading) {
                        RemoteImage(url: AZImages.todosCard).scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 150).clipped()
                        LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("To-Do List").font(.title.bold()).foregroundStyle(.white)
                            Text("\(active.count) open · \(done.count) done")
                                .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                                .contentTransition(.numericText())
                        }
                        .padding(18)
                    }
                    .clipShape(.rect(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.15)))

                    HStack(spacing: 10) {
                        TextField("Add a task...", text: $newTitle)
                            .focused($focused)
                            .submitLabel(.done)
                            .onSubmit(add)
                        Button(action: add) {
                            Image(systemName: "plus")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(AZ.fabGradient, in: .circle)
                        }
                        .buttonStyle(.squish(0.88))
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .cosmicField()

                    if tasks.isEmpty {
                        EmptyStateView(icon: "checklist", title: "Nothing on your list", message: "Add a task above to shape your day")
                    }

                    LazyVStack(spacing: 10) {
                        ForEach(active) { task in
                            TodoRow(task: task,
                                    onToggle: { toggle(task) },
                                    onPriority: { cyclePriority(task) },
                                    onNotes: { notesTask = task },
                                    onRemind: { remindTask = task },
                                    onDelete: { pendingDelete = task })
                                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                        }
                    }

                    if !done.isEmpty {
                        Button {
                            Haptics.select()
                            withAnimation(.snappy) { showCompleted.toggle() }
                        } label: {
                            HStack {
                                Text("Completed (\(done.count))").font(.headline).foregroundStyle(.white.opacity(0.8))
                                Spacer()
                                Image(systemName: "chevron.down").rotationEffect(.degrees(showCompleted ? 0 : -90)).foregroundStyle(AZ.lilac)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                        if showCompleted {
                            LazyVStack(spacing: 10) {
                                ForEach(done) { task in
                                    TodoRow(task: task, onToggle: { toggle(task) }, onPriority: {}, onNotes: { notesTask = task },
                                            onRemind: {}, onDelete: { pendingDelete = task })
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .cosmicNavigation("To-Do List")
        .sheet(item: $notesTask) { NotesSheet(task: $0) }
        .sheet(item: $remindTask) { ReminderSheet(task: $0) }
        .alert("Delete Task", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let t = pendingDelete {
                    Notifications.cancel(t.notificationId)
                    withAnimation { context.delete(t) }
                    Haptics.warning()
                }
            }
        } message: { Text("Are you sure you want to delete \"\(pendingDelete?.title ?? "")\"?") }
    }

    private func add() {
        let t = newTitle.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        withAnimation(.spring) { context.insert(TodoTask(title: t)) }
        newTitle = ""
        Haptics.tap()
        focused = true
    }

    private func toggle(_ task: TodoTask) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            task.isDone.toggle()
            task.completedAt = task.isDone ? Date() : nil
        }
        if task.isDone {
            Notifications.cancel(task.notificationId)
            task.notificationId = nil
            Haptics.success()
        } else {
            Haptics.tap()
        }
    }

    private func cyclePriority(_ task: TodoTask) {
        let next = nextPriority(task.priority)
        Haptics.select()
        withAnimation(.snappy) { task.priority = next }
        if next == "high" {
            if task.dueDate == nil {
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date().addingTimeInterval(86400))
                comps.hour = 9
                task.dueDate = Calendar.current.date(from: comps)
            }
            if let due = task.dueDate {
                Notifications.cancel(task.notificationId)
                Task {
                    task.notificationId = await Notifications.schedule(title: "Urgent task", body: task.title, at: due)
                    task.reminderDate = task.notificationId == nil ? nil : due
                }
            }
        } else if task.priority == "none" {
            Notifications.cancel(task.notificationId)
            task.notificationId = nil
            task.reminderDate = nil
        }
    }
}

private struct TodoRow: View {
    let task: TodoTask
    let onToggle: () -> Void
    let onPriority: () -> Void
    let onNotes: () -> Void
    let onRemind: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggle) {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(task.isDone ? AZ.emerald : priorityColor(task.priority))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.squish(0.8))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(task.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(task.isDone ? .white.opacity(0.45) : .white)
                            .strikethrough(task.isDone)
                        if task.priority == "high" && !task.isDone {
                            Text("URGENT")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(AZ.red, in: .capsule)
                        }
                    }
                    if !task.notes.isEmpty {
                        Text(task.notes).font(.caption).foregroundStyle(AZ.textSecondary).lineLimit(2)
                    }
                    if let r = task.reminderDate, !task.isDone {
                        let overdue = r < Date()
                        Label(r.formatted(.dateTime.month(.abbreviated).day().hour().minute()), systemImage: overdue ? "exclamationmark.circle" : "bell.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(overdue ? AZ.red : AZ.amber)
                    }
                }
                Spacer(minLength: 0)
            }
            if !task.isDone {
                HStack(spacing: 8) {
                    action(task.notes.isEmpty ? "Notes" : "Notes ✓", "note.text", AZ.lavender, onNotes)
                    Button(action: onPriority) {
                        HStack(spacing: 6) {
                            Circle().fill(priorityColor(task.priority)).frame(width: 8, height: 8)
                            Text(task.priority == "none" ? "Priority" : task.priority.capitalized)
                        }
                        .modifier(ActionPill(tint: priorityColor(task.priority)))
                    }
                    .buttonStyle(.squish(0.9))
                    action(task.reminderDate == nil ? "Remind" : "Reminder", "bell", AZ.amber, onRemind)
                    action("Delete", "trash", AZ.red, onDelete)
                }
            } else {
                HStack { Spacer(); action("Delete", "trash", AZ.red, onDelete) }
            }
        }
        .glassCard(radius: 18, tint: task.priority == "high" && !task.isDone ? AZ.red : .white, padding: 14)
    }

    private func action(_ title: String, _ icon: String, _ tint: Color, _ act: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap(); act()
        } label: {
            Label(title, systemImage: icon).modifier(ActionPill(tint: tint))
        }
        .buttonStyle(.squish(0.9))
    }
}

private struct ActionPill: ViewModifier {
    let tint: Color
    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(tint.opacity(0.12), in: .capsule)
    }
}

private struct NotesSheet: View {
    @Bindable var task: TodoTask
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            SheetCanvas {
                Text(task.title).font(.headline).foregroundStyle(AZ.lavender)
                TextField("Add your notes here...\n\nYou have plenty of space to write down details, ideas, or anything related to this task.", text: $text, axis: .vertical)
                    .lineLimit(10...30)
                    .cosmicField()
            }
            .navigationTitle("Add Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SheetToolbar(saveTitle: "Save Notes", canSave: true, onCancel: { dismiss() }) {
                    task.notes = text
                    dismiss()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(AZ.night)
        .onAppear { text = task.notes }
    }
}

private struct ReminderSheet: View {
    @Bindable var task: TodoTask
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date().addingTimeInterval(3600)
    @State private var denied = false

    var body: some View {
        NavigationStack {
            SheetCanvas {
                Text(task.title).font(.headline).foregroundStyle(AZ.lavender)
                DatePicker("Remind me", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .tint(AZ.amber)
                    .glassCard(radius: 18, padding: 8)
                if task.reminderDate != nil {
                    Button(role: .destructive) {
                        Notifications.cancel(task.notificationId)
                        task.notificationId = nil
                        task.reminderDate = nil
                        Haptics.warning()
                        dismiss()
                    } label: {
                        Label("Remove Reminder", systemImage: "bell.slash").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(AZ.red)
                }
            }
            .navigationTitle("Set Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SheetToolbar(saveTitle: "Set", canSave: date > Date(), onCancel: { dismiss() }) {
                    Task {
                        Notifications.cancel(task.notificationId)
                        if let id = await Notifications.schedule(title: "Task Reminder", body: task.title, at: date) {
                            task.notificationId = id
                            task.reminderDate = date
                            task.dueDate = date
                            dismiss()
                        } else {
                            denied = true
                        }
                    }
                }
            }
            .alert("Permission Required", isPresented: $denied) {
                Button("OK", role: .cancel) {}
            } message: { Text("Please enable notifications in Settings to use reminders.") }
        }
        .presentationBackground(AZ.night)
        .onAppear { if let r = task.reminderDate, r > Date() { date = r } }
    }
}

import SwiftUI
import SwiftData

extension Goal {
    var isCompleted: Bool { status == "completed" }

    /// Share of days this month (so far) the goal was logged.
    var monthProgress: Int {
        let cal = Calendar.current
        let now = Date()
        let dayOfMonth = cal.component(.day, from: now)
        let logged = Set(completions.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }.map { $0.date.startOfDay }).count
        return min(100, Int((Double(logged) / Double(max(dayOfMonth, 1)) * 100).rounded()))
    }

    var checklistProgress: Double {
        checklist.isEmpty ? 0 : Double(checklist.filter(\.isDone).count) / Double(checklist.count)
    }

    func isLogged(_ day: Date) -> Bool {
        completions.contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }
}

private func progressTint(_ p: Int) -> Color { p >= 75 ? AZ.emerald : p >= 50 ? Color(hex: 0xF59E0B) : AZ.indigo }

struct GoalsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @State private var filter = "in_progress"
    @State private var showAdd = false
    @State private var pendingDelete: Goal?

    private var filtered: [Goal] {
        goals.filter { filter == "completed" ? $0.isCompleted : !$0.isCompleted }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ImageBackdrop(url: AZImages.featureBackground, overlay: .black.opacity(0.5))
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Filter", selection: $filter.animation(.snappy)) {
                        Text("Active").tag("in_progress")
                        Text("Completed").tag("completed")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: filter) { _, _ in Haptics.select() }

                    if filtered.isEmpty {
                        EmptyStateView(icon: "target",
                                       title: filter == "completed" ? "No completed goals" : "No active goals",
                                       message: "Tap + to create a goal")
                            .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filtered) { goal in
                                NavigationLink { GoalDetailView(goal: goal) } label: { card(goal) }
                                    .buttonStyle(.squish(0.98))
                                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 90)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            FloatingAddButton { showAdd = true }.padding(24)
        }
        .cosmicNavigation("Set Goals")
        .sheet(isPresented: $showAdd) { GoalEditor(goal: nil) }
        .alert("Delete Goal", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let g = pendingDelete { withAnimation { context.delete(g) } }
            }
        } message: { Text("Are you sure you want to delete \"\(pendingDelete?.title ?? "")\"?") }
    }

    private func card(_ goal: Goal) -> some View {
        let p = goal.monthProgress
        return HStack(alignment: .top, spacing: 12) {
            Button {
                Haptics.success()
                withAnimation(.spring) {
                    goal.status = goal.isCompleted ? "in_progress" : "completed"
                    goal.updatedAt = Date()
                }
            } label: {
                Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(goal.isCompleted ? AZ.emerald : AZ.indigo)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.squish(0.8))

            VStack(alignment: .leading, spacing: 8) {
                Text(goal.title)
                    .font(.headline)
                    .foregroundStyle(goal.isCompleted ? .white.opacity(0.5) : .white)
                    .strikethrough(goal.isCompleted)
                    .multilineTextAlignment(.leading)
                if !goal.details.isEmpty {
                    Text(goal.details).font(.subheadline).foregroundStyle(AZ.textSecondary).lineLimit(2).multilineTextAlignment(.leading)
                }
                HStack(spacing: 14) {
                    Label("\(goal.completions.count) logged", systemImage: "target").foregroundStyle(AZ.indigo)
                    if let d = goal.targetDate {
                        Label(d.formatted(.dateTime.month(.abbreviated).day()), systemImage: "chart.line.uptrend.xyaxis").foregroundStyle(AZ.emerald)
                    }
                }
                .font(.caption)
                HStack(spacing: 10) {
                    ProgressBar(value: Double(p) / 100, tint: progressTint(p), height: 6)
                    Text("\(p)%").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                }
            }
            Spacer(minLength: 0)
            Button { pendingDelete = goal } label: {
                Image(systemName: "trash").foregroundStyle(AZ.red)
            }
            .buttonStyle(.squish(0.8))
        }
        .glassCard(radius: 18)
    }
}

// MARK: - Editor

struct GoalEditor: View {
    let goal: Goal?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var details = ""
    @State private var hasDate = false
    @State private var date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var status = "in_progress"
    @State private var loaded = false

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            SheetCanvas {
                FieldLabel(text: "Title")
                TextField("My goal...", text: $title).cosmicField()
                FieldLabel(text: "Description")
                TextField("Describe your goal...", text: $details, axis: .vertical).lineLimit(3...6).cosmicField()
                Toggle(isOn: $hasDate.animation()) {
                    Text("Due Date").foregroundStyle(.white)
                }
                .tint(AZ.purple)
                if hasDate {
                    DatePicker("Due", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(AZ.violetLight)
                        .glassCard(radius: 18, padding: 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                FieldLabel(text: "Status")
                Picker("Status", selection: $status) {
                    Text("Not Started").tag("not_started")
                    Text("In Progress").tag("in_progress")
                    Text("Completed").tag("completed")
                }
                .pickerStyle(.segmented)
                GradientButton(title: goal == nil ? "Create Goal" : "Save Goal", icon: "target") { save() }
                    .disabled(!canSave).opacity(canSave ? 1 : 0.5)
            }
            .navigationTitle(goal == nil ? "New Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { SheetToolbar(canSave: canSave, onCancel: { dismiss() }, onSave: save) }
        }
        .presentationBackground(AZ.night)
        .onAppear {
            guard !loaded, let goal else { return }
            loaded = true
            title = goal.title
            details = goal.details
            status = goal.status
            if let d = goal.targetDate { hasDate = true; date = d }
        }
    }

    private func save() {
        guard canSave else { return }
        if let goal {
            goal.title = title
            goal.details = details
            goal.targetDate = hasDate ? date : nil
            goal.status = status
            goal.updatedAt = Date()
        } else {
            context.insert(Goal(title: title, details: details, targetDate: hasDate ? date : nil, status: status))
        }
        Haptics.success()
        dismiss()
    }
}

// MARK: - Detail

struct GoalDetailView: View {
    @Bindable var goal: Goal
    @Environment(\.modelContext) private var context
    @State private var month = Date()
    @State private var newItem = ""
    @State private var editing = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            ImageBackdrop(url: AZImages.featureBackground, overlay: .black.opacity(0.6))
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(goal.title).font(.title.bold()).foregroundStyle(.white)
                        if !goal.details.isEmpty {
                            Text(goal.details).foregroundStyle(AZ.textSecondary)
                        }
                        if let d = goal.targetDate {
                            Text("Due: \(d.formatted(date: .abbreviated, time: .omitted))")
                                .font(.footnote.weight(.semibold)).foregroundStyle(AZ.lavender)
                        }
                    }

                    HStack(spacing: 12) {
                        metric("\(goal.monthProgress)%", "Progress", progressTint(goal.monthProgress))
                        metric("\(goal.completions.count)", "Days Logged", AZ.indigo)
                    }

                    Button { toggleToday() } label: {
                        let done = goal.isLogged(Date())
                        Label(done ? "Logged Today ✓" : "Mark Complete Today", systemImage: done ? "checkmark.seal.fill" : "plus.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(done ? AnyShapeStyle(AZ.emerald.gradient) : AnyShapeStyle(AZ.primaryGradient), in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.squish)

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Checklist Progress", icon: "list.bullet.clipboard")
                        ProgressBar(value: goal.checklistProgress, tint: AZ.emerald)
                        Text("\(goal.checklist.filter(\.isDone).count) of \(goal.checklist.count) complete")
                            .font(.caption).foregroundStyle(AZ.textSecondary)
                    }
                    .glassCard()

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "Activity Calendar", icon: "calendar")
                        MonthCalendarView(month: $month, selected: nil, accent: AZ.emerald, marked: goal.isLogged) { day in
                            toggle(day)
                        }
                    }
                    .glassCard()

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Checklist", icon: "checklist")
                        ForEach(goal.sortedChecklist) { item in
                            HStack(spacing: 12) {
                                Button {
                                    Haptics.tap()
                                    withAnimation(.spring) { item.isDone.toggle() }
                                } label: {
                                    Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                                        .font(.title3)
                                        .foregroundStyle(item.isDone ? AZ.emerald : AZ.indigo)
                                        .contentTransition(.symbolEffect(.replace))
                                }
                                Text(item.text)
                                    .foregroundStyle(item.isDone ? .white.opacity(0.45) : .white)
                                    .strikethrough(item.isDone)
                                Spacer()
                                Button {
                                    withAnimation { context.delete(item) }
                                } label: { Image(systemName: "xmark").font(.footnote).foregroundStyle(AZ.red.opacity(0.8)) }
                            }
                            .buttonStyle(.squish(0.85))
                            .padding(.vertical, 4)
                        }
                        HStack {
                            TextField("Add checklist item...", text: $newItem)
                                .focused($focused)
                                .submitLabel(.done)
                                .onSubmit(addItem)
                            Button(action: addItem) {
                                Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(AZ.violetLight)
                            }
                            .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .cosmicField()
                    }
                    .glassCard()
                }
                .padding(20)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .cosmicNavigation("Goal")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editing = true }
            }
        }
        .sheet(isPresented: $editing) { GoalEditor(goal: goal) }
    }

    private func metric(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(label).font(.caption).foregroundStyle(AZ.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .glassCard(radius: 16)
    }

    private func toggleToday() { toggle(Date()) }

    private func toggle(_ day: Date) {
        guard day.startOfDay <= Date() else { Haptics.warning(); return }
        withAnimation(.spring) {
            if let existing = goal.completions.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
                context.delete(existing)
                Haptics.tap()
            } else {
                let c = GoalCompletion(date: day.startOfDay)
                c.goal = goal
                context.insert(c)
                Haptics.success()
            }
        }
    }

    private func addItem() {
        let t = newItem.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        let item = GoalChecklistItem(text: t, order: (goal.checklist.map(\.order).max() ?? 0) + 1)
        item.goal = goal
        withAnimation { context.insert(item) }
        newItem = ""
        Haptics.tap()
        focused = true
    }
}

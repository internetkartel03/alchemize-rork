import SwiftUI
import Combine
import SwiftData

enum HabitSection: String, CaseIterable, Identifiable {
    case morning, health, evening, custom
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct HabitsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @State private var selectedDate = Date().startOfDay
    @State private var collapsed: Set<String> = []
    @State private var showAdd = false
    @State private var running: UUID?
    @State private var pendingDelete: Habit?
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var weekDates: [Date] {
        let cal = Calendar.current
        let today = Date().startOfDay
        let weekday = cal.component(.weekday, from: today) - 1
        let start = cal.date(byAdding: .day, value: -weekday, to: today) ?? today
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                ImageBackdrop(url: AZImages.cosmicStars, overlay: .clear)
                LinearGradient(colors: [Color(red: 10/255, green: 10/255, blue: 30/255).opacity(0.85), Color(red: 20/255, green: 15/255, blue: 50/255).opacity(0.9)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                StarField(count: 20)
            }

            VStack(spacing: 0) {
                dateStrip
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                ScrollView {
                    VStack(spacing: 18) {
                        if habits.isEmpty {
                            VStack(spacing: 10) {
                                Text("✨").font(.system(size: 56))
                                Text("No habits yet!").font(.title3.bold()).foregroundStyle(.white)
                                Text("Tap + to create your first habit").foregroundStyle(AZ.textSecondary)
                            }
                            .padding(.top, 80)
                        } else {
                            ForEach(HabitSection.allCases) { section in
                                sectionView(section)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                }
            }
            FloatingAddButton(gradient: LinearGradient(colors: [AZ.gold, Color(hex: 0xF59E0B)], startPoint: .topLeading, endPoint: .bottomTrailing)) {
                showAdd = true
            }
            .padding(24)
        }
        .cosmicNavigation("Habit Tracker")
        .sheet(isPresented: $showAdd) { HabitEditor() }
        .onReceive(tick) { _ in tickTimer() }
        .onChange(of: selectedDate) { _, _ in running = nil }
        .alert("Delete Habit", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { if let h = pendingDelete { withAnimation { context.delete(h) } } }
        } message: { Text("Delete \"\(pendingDelete?.name ?? "")\" and its history?") }
    }

    private var dateStrip: some View {
        HStack(spacing: 6) {
            ForEach(weekDates, id: \.self) { date in
                let selected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                let today = Calendar.current.isDateInToday(date)
                let count = habits.filter { $0.isComplete(on: date) }.count
                Button {
                    Haptics.select()
                    withAnimation(.snappy) { selectedDate = date }
                } label: {
                    VStack(spacing: 4) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption2.weight(.semibold))
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.headline)
                        Circle().fill(count > 0 && !selected ? AZ.gold : .clear).frame(width: 5, height: 5)
                    }
                    .foregroundStyle(selected ? .black : .white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selected ? AnyShapeStyle(AZ.gold) : AnyShapeStyle(.white.opacity(0.06)), in: .rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(today && !selected ? AZ.gold.opacity(0.7) : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.squish(0.9))
                .disabled(date > Date())
                .opacity(date > Date() ? 0.4 : 1)
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ section: HabitSection) -> some View {
        let list = habits.filter { $0.section == section.rawValue && $0.isScheduled(on: selectedDate) }
        if !list.isEmpty {
            VStack(spacing: 12) {
                Button {
                    Haptics.select()
                    withAnimation(.snappy) {
                        if collapsed.contains(section.rawValue) { collapsed.remove(section.rawValue) } else { collapsed.insert(section.rawValue) }
                    }
                } label: {
                    HStack {
                        Text(section.label).font(.title3.bold()).foregroundStyle(.white)
                        Text("\(list.filter { $0.isComplete(on: selectedDate) }.count)/\(list.count)")
                            .font(.caption.weight(.bold)).foregroundStyle(AZ.gold)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(AZ.gold.opacity(0.15), in: .capsule)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundStyle(AZ.lilac)
                            .rotationEffect(.degrees(collapsed.contains(section.rawValue) ? -90 : 0))
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                if !collapsed.contains(section.rawValue) {
                    ForEach(list) { habit in
                        HabitCard(habit: habit, date: selectedDate, isRunning: running == habit.id,
                                  onTimer: { toggleTimer(habit) },
                                  onSet: { setValue(habit, $0) })
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = habit }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    private func toggleTimer(_ habit: Habit) {
        Haptics.tap()
        running = running == habit.id ? nil : habit.id
    }

    private func tickTimer() {
        guard let id = running, let habit = habits.first(where: { $0.id == id }) else { return }
        let next = habit.progress(on: selectedDate) + 1
        setValue(habit, next, silent: true)
        if next >= habit.goalTarget { running = nil }
    }

    private func setValue(_ habit: Habit, _ value: Int, silent: Bool = false) {
        let wasComplete = habit.isComplete(on: selectedDate)
        let v = max(0, value)
        if let log = habit.log(on: selectedDate) {
            log.value = v
        } else {
            let log = HabitLog(day: selectedDate, value: v)
            log.habit = habit
            context.insert(log)
        }
        let nowComplete = habit.isComplete(on: selectedDate)
        if nowComplete && !wasComplete { Haptics.success() } else if !silent { Haptics.tap() }
    }
}

private struct HabitCard: View {
    let habit: Habit
    let date: Date
    let isRunning: Bool
    let onTimer: () -> Void
    let onSet: (Int) -> Void

    var body: some View {
        let progress = habit.progress(on: date)
        let done = habit.isComplete(on: date)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(habit.icon)
                    .font(.title2)
                    .frame(width: 48, height: 48)
                    .background(AZ.lilac.opacity(0.15), in: .rect(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text(habit.name).font(.headline).foregroundStyle(.white)
                    Text(subtitle).font(.caption).foregroundStyle(AZ.textSecondary)
                }
                Spacer()
                if habit.streak > 0 {
                    Label("\(habit.streak)", systemImage: "flame.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AZ.orange)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(AZ.orange.opacity(0.15), in: .capsule)
                }
            }

            switch habit.type {
            case "timer":
                HStack(spacing: 10) {
                    Image(systemName: "timer").foregroundStyle(AZ.gold).font(.title3)
                        .symbolEffect(.pulse, isActive: isRunning)
                    Text(format(progress))
                        .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("/ \(habit.goal) \(habit.goalUnit)").font(.subheadline).foregroundStyle(AZ.textSecondary)
                    Spacer()
                    Button(action: onTimer) {
                        Label(isRunning ? "Pause" : "Start", systemImage: isRunning ? "pause.fill" : "play.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(done ? .gray : AZ.gold)
                            .padding(.horizontal, 14).frame(height: 38)
                            .background(AZ.gold.opacity(0.12), in: .capsule)
                            .overlay(Capsule().strokeBorder(AZ.gold.opacity(0.4)))
                    }
                    .buttonStyle(.squish(0.92))
                    .disabled(done)
                }
                ProgressBar(value: Double(progress) / Double(max(habit.goalTarget, 1)), tint: AZ.gold, height: 6)
            case "counter":
                HStack {
                    counterButton("minus") { onSet(progress - 1) }.disabled(progress == 0)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "number").foregroundStyle(AZ.gold)
                        Text("\(progress) / \(habit.goal)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    counterButton("plus") { onSet(progress + 1) }
                }
                ProgressBar(value: Double(progress) / Double(max(habit.goal, 1)), tint: AZ.gold, height: 6)
            default:
                Button { onSet(done ? 0 : 1) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: done ? "checkmark.square.fill" : "square")
                            .contentTransition(.symbolEffect(.replace))
                        Text(done ? "Completed ✓" : "Mark Complete")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(done ? AnyShapeStyle(AZ.emerald.gradient) : AnyShapeStyle(AZ.lilac.opacity(0.14)), in: .rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(done ? .clear : AZ.lilac.opacity(0.35)))
                }
                .buttonStyle(.squish)
            }

            if done {
                Text("✨ Completed Today!")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AZ.gold)
                    .frame(maxWidth: .infinity)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .glassCard(radius: 20, tint: done ? AZ.gold : .white)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: done)
    }

    private var subtitle: String {
        switch habit.type {
        case "timer": "⏱ \(habit.goal) \(habit.goalUnit)"
        case "counter": "🔢 \(habit.goal) times"
        default: habit.frequency == "daily" ? "Daily task" : "Scheduled task"
        }
    }

    private func format(_ s: Int) -> String {
        s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }

    private func counterButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.1), in: .circle)
                .overlay(Circle().strokeBorder(AZ.gold.opacity(0.35)))
        }
        .buttonStyle(.squish(0.85))
    }
}

// MARK: - Add Habit

struct HabitEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var icon = "✨"
    @State private var type = "checkbox"
    @State private var goal = 1
    @State private var unit = "times"
    @State private var section = "custom"
    @State private var frequency = "daily"
    @State private var days: Set<Int> = [1, 2, 3, 4, 5]

    private let icons = ["✨", "🧘", "💪", "📚", "💧", "🌅", "🏃", "🍎", "😴", "✍️", "🎯", "🙏", "🎨", "🎵", "💊", "🧠", "🚶", "🌱"]
    private let templates: [(String, String, String, Int, String)] = [
        ("🧘", "Meditate", "timer", 15, "minutes"),
        ("💪", "Exercise", "timer", 30, "minutes"),
        ("📚", "Read", "timer", 20, "minutes"),
        ("💧", "Drink Water", "counter", 8, "times"),
        ("🌅", "Wake Up Early", "checkbox", 1, "times"),
    ]

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            SheetCanvas {
                Text("Quick Start Templates").font(.headline).foregroundStyle(.white)
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(templates, id: \.1) { t in
                            Button {
                                Haptics.select()
                                withAnimation(.snappy) {
                                    icon = t.0; name = t.1; type = t.2; goal = t.3; unit = t.4
                                    section = t.1 == "Wake Up Early" ? "morning" : (t.1 == "Drink Water" || t.1 == "Exercise" ? "health" : section)
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Text(t.0).font(.title)
                                    Text(t.1).font(.caption.weight(.semibold)).foregroundStyle(.white)
                                }
                                .frame(width: 96, height: 86)
                                .background(name == t.1 ? AZ.gold.opacity(0.2) : .white.opacity(0.06), in: .rect(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(name == t.1 ? AZ.gold : .white.opacity(0.1)))
                            }
                            .buttonStyle(.squish)
                        }
                    }
                }
                .scrollIndicators(.hidden)

                FieldLabel(text: "Habit Name")
                TextField("Exercise, Meditate, Read...", text: $name).cosmicField()

                FieldLabel(text: "Icon")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(icons, id: \.self) { e in
                        Button { Haptics.select(); icon = e } label: {
                            Text(e).font(.title2)
                                .frame(maxWidth: .infinity).frame(height: 46)
                                .background(icon == e ? AZ.gold.opacity(0.22) : .white.opacity(0.05), in: .rect(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(icon == e ? AZ.gold : .clear))
                        }
                        .buttonStyle(.squish(0.9))
                    }
                }

                FieldLabel(text: "Type")
                Picker("Type", selection: $type.animation()) {
                    Label("Checkbox", systemImage: "checkmark.square").tag("checkbox")
                    Label("Timer", systemImage: "timer").tag("timer")
                    Label("Counter", systemImage: "number").tag("counter")
                }
                .pickerStyle(.segmented)
                .onChange(of: type) { _, t in
                    if t == "timer" { unit = "minutes"; if goal < 5 { goal = 15 } }
                    if t == "counter" { unit = "times"; if goal < 2 { goal = 8 } }
                    if t == "checkbox" { unit = "times"; goal = 1 }
                }

                if type != "checkbox" {
                    FieldLabel(text: "Goal")
                    HStack {
                        Stepper(value: $goal, in: 1...600) {
                            Text("\(goal)").font(.title2.bold()).foregroundStyle(.white).contentTransition(.numericText())
                        }
                        if type == "timer" {
                            Picker("Unit", selection: $unit) {
                                Text("min").tag("minutes")
                                Text("hours").tag("hours")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 130)
                        } else {
                            Text("times").foregroundStyle(AZ.textSecondary)
                        }
                    }
                    .cosmicField()
                }

                FieldLabel(text: "Section")
                Picker("Section", selection: $section) {
                    ForEach(HabitSection.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)

                FieldLabel(text: "Frequency")
                Picker("Frequency", selection: $frequency.animation()) {
                    Text("Daily").tag("daily")
                    Text("Custom Days").tag("custom")
                }
                .pickerStyle(.segmented)
                if frequency == "custom" {
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { d in
                            let on = days.contains(d)
                            Button {
                                Haptics.select()
                                if on { days.remove(d) } else { days.insert(d) }
                            } label: {
                                Text(Calendar.current.veryShortWeekdaySymbols[d])
                                    .font(.subheadline.bold())
                                    .foregroundStyle(on ? .black : .white)
                                    .frame(maxWidth: .infinity).frame(height: 40)
                                    .background(on ? AnyShapeStyle(AZ.gold) : AnyShapeStyle(.white.opacity(0.08)), in: .circle)
                            }
                            .buttonStyle(.squish(0.88))
                        }
                    }
                }

                GradientButton(title: "Create Habit", icon: "plus",
                               gradient: LinearGradient(colors: [Color(hex: 0xF59E0B), Color(hex: 0xD97706)], startPoint: .leading, endPoint: .trailing)) { save() }
                    .disabled(!canSave).opacity(canSave ? 1 : 0.5)
                    .padding(.top, 6)
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { SheetToolbar(canSave: canSave, onCancel: { dismiss() }, onSave: save) }
        }
        .presentationBackground(AZ.night)
    }

    private func save() {
        guard canSave else { return }
        context.insert(Habit(name: name.trimmingCharacters(in: .whitespaces), icon: icon, goal: type == "checkbox" ? 1 : goal,
                             goalUnit: unit, type: type, frequency: frequency,
                             customDays: frequency == "custom" ? days.sorted() : [], section: section))
        Haptics.success()
        dismiss()
    }
}

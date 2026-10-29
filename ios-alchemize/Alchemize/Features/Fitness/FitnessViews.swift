import SwiftUI
import Combine
import SwiftData
import CoreMotion

// MARK: - Templates

struct WorkoutTemplate: Identifiable, Hashable {
    var id: String { title }
    let title: String
    let category: String
    let durationMinutes: Int
    let intensity: String
    let equipment: String
    let description: String

    /// Rough MET-based burn for a ~70 kg person.
    var estimatedCalories: Int { Self.burn(category: category, intensity: intensity, minutes: durationMinutes) }

    static func burn(category: String, intensity: String, minutes: Int) -> Int {
        let met: Double = switch category {
        case "hiit": 8; case "run": 9; case "strength": 5; case "core": 4.5
        case "yoga": 3; case "walk": 3.5; case "stretch", "mobility": 2.5; default: 4
        }
        let mult: Double = switch intensity { case "high": 1.2; case "low": 0.85; default: 1 }
        return Int((met * mult * 70 * Double(minutes) / 60).rounded())
    }

    static let all: [WorkoutTemplate] = [
        .init(title: "Morning Stretch", category: "stretch", durationMinutes: 10, intensity: "low", equipment: "none", description: "Gentle full-body stretching to start your day"),
        .init(title: "Power Yoga Flow", category: "yoga", durationMinutes: 30, intensity: "medium", equipment: "none", description: "Dynamic yoga sequence building strength and flexibility"),
        .init(title: "Quick Core Blast", category: "core", durationMinutes: 15, intensity: "high", equipment: "none", description: "Intense core workout with planks, crunches, and twists"),
        .init(title: "HIIT Cardio", category: "hiit", durationMinutes: 20, intensity: "high", equipment: "none", description: "High-intensity intervals to torch calories"),
        .init(title: "Strength Builder", category: "strength", durationMinutes: 45, intensity: "high", equipment: "dumbbells", description: "Full-body strength training with weights"),
        .init(title: "Mobility Flow", category: "mobility", durationMinutes: 20, intensity: "low", equipment: "none", description: "Improve joint mobility and movement quality"),
        .init(title: "Evening Walk", category: "walk", durationMinutes: 30, intensity: "low", equipment: "none", description: "Relaxing outdoor walk for recovery"),
        .init(title: "Quick Run", category: "run", durationMinutes: 25, intensity: "medium", equipment: "none", description: "Moderate-pace cardiovascular run"),
        .init(title: "Deep Stretch", category: "stretch", durationMinutes: 20, intensity: "low", equipment: "none", description: "Long-hold stretches for flexibility"),
        .init(title: "Yoga for Beginners", category: "yoga", durationMinutes: 25, intensity: "low", equipment: "none", description: "Gentle introduction to yoga poses"),
        .init(title: "Core Stability", category: "core", durationMinutes: 12, intensity: "medium", equipment: "none", description: "Build a stable, strong core foundation"),
        .init(title: "Tabata Workout", category: "hiit", durationMinutes: 15, intensity: "high", equipment: "none", description: "20 seconds on, 10 seconds off intervals"),
        .init(title: "Upper Body Power", category: "strength", durationMinutes: 35, intensity: "high", equipment: "dumbbells", description: "Focus on chest, back, shoulders, and arms"),
        .init(title: "Hip Mobility", category: "mobility", durationMinutes: 15, intensity: "low", equipment: "none", description: "Open tight hips and improve range of motion"),
        .init(title: "Brisk Walk", category: "walk", durationMinutes: 20, intensity: "medium", equipment: "none", description: "Fast-paced walk to get your heart rate up"),
        .init(title: "Interval Run", category: "run", durationMinutes: 30, intensity: "high", equipment: "none", description: "Alternating sprints and jog intervals"),
        .init(title: "Full Body Stretch", category: "stretch", durationMinutes: 25, intensity: "low", equipment: "none", description: "Complete stretching routine for all major muscles"),
        .init(title: "Vinyasa Flow", category: "yoga", durationMinutes: 40, intensity: "medium", equipment: "none", description: "Flowing yoga practice linking breath and movement"),
        .init(title: "Ab Shredder", category: "core", durationMinutes: 10, intensity: "high", equipment: "none", description: "Intense abdominal workout for definition"),
        .init(title: "EMOM Challenge", category: "hiit", durationMinutes: 25, intensity: "high", equipment: "none", description: "Every minute on the minute intensity training"),
        .init(title: "Lower Body Blast", category: "strength", durationMinutes: 40, intensity: "high", equipment: "dumbbells", description: "Legs, glutes, and hamstrings workout"),
        .init(title: "Shoulder Mobility", category: "mobility", durationMinutes: 12, intensity: "low", equipment: "bands", description: "Improve shoulder flexibility and health"),
        .init(title: "Recovery Walk", category: "walk", durationMinutes: 45, intensity: "low", equipment: "none", description: "Long, easy walk for active recovery"),
        .init(title: "Tempo Run", category: "run", durationMinutes: 35, intensity: "medium", equipment: "none", description: "Sustained moderate-hard effort run"),
        .init(title: "Resistance Band Workout", category: "strength", durationMinutes: 30, intensity: "medium", equipment: "bands", description: "Full-body strength using resistance bands"),
        .init(title: "Gym Session", category: "strength", durationMinutes: 60, intensity: "high", equipment: "gym", description: "Complete gym workout with machines and free weights"),
        .init(title: "Core + Stretch", category: "core", durationMinutes: 20, intensity: "medium", equipment: "none", description: "Core work followed by deep stretching"),
        .init(title: "Yin Yoga", category: "yoga", durationMinutes: 45, intensity: "low", equipment: "none", description: "Restorative yoga with long-held poses"),
        .init(title: "Sprint Intervals", category: "hiit", durationMinutes: 12, intensity: "high", equipment: "none", description: "All-out sprint intervals for maximum burn"),
        .init(title: "Morning Mobility", category: "mobility", durationMinutes: 10, intensity: "low", equipment: "none", description: "Wake up your body with mobility drills"),
    ]
}

enum FitnessCategory {
    static let all = ["stretch", "yoga", "core", "hiit", "strength", "mobility", "walk", "run"]
    static func icon(_ c: String) -> String {
        switch c {
        case "stretch": "figure.flexibility"
        case "yoga": "figure.yoga"
        case "core": "figure.core.training"
        case "hiit": "bolt.heart.fill"
        case "strength": "dumbbell.fill"
        case "mobility": "figure.cooldown"
        case "walk": "figure.walk"
        case "run": "figure.run"
        default: "figure.mixed.cardio"
        }
    }
    static func tint(_ c: String) -> Color {
        switch c {
        case "stretch": AZ.sky
        case "yoga": AZ.purple
        case "core": AZ.amber
        case "hiit": AZ.red
        case "strength": AZ.indigo
        case "mobility": AZ.green
        case "walk": AZ.emerald
        case "run": AZ.orange
        default: AZ.violetLight
        }
    }
    static func label(_ c: String) -> String { c == "hiit" ? "HIIT" : c.capitalized }
}

// MARK: - Steps

@Observable
final class StepCounter {
    var steps: Int = 0
    var available = CMPedometer.isStepCountingAvailable()
    private let pedometer = CMPedometer()

    func start() {
        guard available else { return }
        let start = Calendar.current.startOfDay(for: Date())
        pedometer.startUpdates(from: start) { [weak self] data, _ in
            let value = data?.numberOfSteps.intValue ?? 0
            Task { @MainActor in self?.steps = value }
        }
    }

    func stop() { pedometer.stopUpdates() }
}

// MARK: - Main

struct FitnessView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @State private var stepCounter = StepCounter()
    @State private var showLog = false
    @State private var activeWorkout: WorkoutTemplate?

    private let minutesGoal = 30, caloriesGoal = 400, stepsGoal = 8000

    private var today: [WorkoutSession] { sessions.filter { Calendar.current.isDateInToday($0.date) } }
    private var week: [WorkoutSession] {
        let start = Calendar.current.date(byAdding: .day, value: -6, to: Date().startOfDay) ?? Date()
        return sessions.filter { $0.date >= start }
    }
    private var suggested: [WorkoutTemplate] {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let all = WorkoutTemplate.all
        return (0..<4).map { all[(day * 3 + $0 * 7) % all.count] }
    }

    var body: some View {
        ZStack {
            ImageBackdrop(url: AZImages.featureBackground, overlay: Color(red: 5/255, green: 2/255, blue: 17/255).opacity(0.7))
            ScrollView {
                VStack(spacing: 18) {
                    ringsCard
                    HStack(spacing: 12) {
                        bigAction("Log Workout", "square.and.pencil", AZ.emerald) { showLog = true }
                        NavigationLink { WorkoutBrowseView(onStart: { activeWorkout = $0 }) } label: {
                            actionLabel("Browse", "square.grid.2x2.fill", AZ.indigo)
                        }
                        .buttonStyle(.squish)
                        .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                    }
                    suggestedSection
                    weeklyCard
                    awardsCard
                    recentSection
                }
                .padding(20)
                .padding(.bottom, 30)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
        }
        .cosmicNavigation("Fitness")
        .onAppear { stepCounter.start() }
        .onDisappear { stepCounter.stop() }
        .sheet(isPresented: $showLog) { WorkoutLogEditor() }
        .fullScreenCover(item: $activeWorkout) { WorkoutTimerView(template: $0) }
    }

    private var ringsCard: some View {
        let minutes = today.reduce(0) { $0 + $1.durationMinutes }
        let cals = today.reduce(0) { $0 + $1.calories }
        return VStack(alignment: .leading, spacing: 16) {
            Text("Today's Progress").font(.title3.bold()).foregroundStyle(.white)
            HStack(spacing: 8) {
                ring(minutes, minutesGoal, AZ.emerald, "Minutes")
                ring(cals, caloriesGoal, Color(hex: 0xF59E0B), "Calories")
                ring(stepCounter.steps, stepsGoal, AZ.blue, "Steps")
            }
            if !stepCounter.available {
                Text("Step counting isn't available on this device.").font(.caption).foregroundStyle(AZ.textTertiary)
            }
        }
        .glassCard(radius: 24, tint: AZ.emerald, padding: 18)
    }

    private func ring(_ value: Int, _ goal: Int, _ tint: Color, _ label: String) -> some View {
        let p = min(1, Double(value) / Double(max(goal, 1)))
        return VStack(spacing: 8) {
            ZStack {
                Circle().stroke(tint.opacity(0.15), lineWidth: 9)
                Circle().trim(from: 0, to: p)
                    .stroke(tint, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tint.opacity(0.6), radius: 6)
                    .animation(.spring(duration: 0.9), value: p)
                Text(value >= 10_000 ? String(format: "%.1fk", Double(value) / 1000) : "\(value)")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                    .padding(10)
            }
            .frame(width: 84, height: 84)
            Text(label).font(.caption.weight(.medium)).foregroundStyle(AZ.textSecondary)
            Text("of \(goal)").font(.caption2).foregroundStyle(AZ.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func bigAction(_ title: String, _ icon: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: { actionLabel(title, icon, tint) }
            .buttonStyle(.squish)
    }

    private func actionLabel(_ title: String, _ icon: String, _ tint: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.headline).foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(tint.gradient, in: .rect(cornerRadius: 16))
            .shadow(color: tint.opacity(0.4), radius: 10, y: 4)
    }

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Suggested for Today", icon: "sparkles", tint: AZ.lavender)
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(suggested) { t in
                        WorkoutTemplateCard(template: t, compact: true) { activeWorkout = t }
                            .frame(width: 200)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }

    private var weeklyCard: some View {
        let cal = Calendar.current
        let days: [Date] = (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: Date().startOfDay) }
        let perDay = days.map { d in week.filter { cal.isDate($0.date, inSameDayAs: d) }.reduce(0) { $0 + $1.durationMinutes } }
        let maxV = max(perDay.max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "This Week", icon: "chart.bar.fill", tint: AZ.emerald)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(perDay[i] > 0 ? AnyShapeStyle(LinearGradient(colors: [AZ.emerald, AZ.emerald.opacity(0.4)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(.white.opacity(0.08)))
                            .frame(height: max(6, 80 * CGFloat(perDay[i]) / CGFloat(maxV)))
                        Text(d.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2.weight(cal.isDateInToday(d) ? .bold : .regular))
                            .foregroundStyle(cal.isDateInToday(d) ? .white : AZ.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100, alignment: .bottom)
            .animation(.spring, value: perDay)
            HStack {
                weekStat("\(week.count)", "Workouts", AZ.emerald)
                weekStat("\(week.reduce(0) { $0 + $1.durationMinutes })", "Minutes", AZ.blue)
                weekStat("\(week.reduce(0) { $0 + $1.calories })", "Calories", Color(hex: 0xF59E0B))
            }
        }
        .glassCard(radius: 22, padding: 18)
    }

    private func weekStat(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold().monospacedDigit()).foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(AZ.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var awardsCard: some View {
        let total = sessions.count
        let variety = Set(sessions.map(\.category)).count
        let awards: [(String, String, Bool)] = [
            ("First Steps", "Complete your first workout", total >= 1),
            ("Getting Started", "Complete 10 workouts", total >= 10),
            ("Building Momentum", "Complete 25 workouts", total >= 25),
            ("Half Century", "Complete 50 workouts", total >= 50),
            ("Century Club", "Complete 100 workouts", total >= 100),
            ("Variety Seeker", "Try 5 different workout categories", variety >= 5),
        ]
        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Awards", icon: "medal.fill", tint: Color(hex: 0xF59E0B))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(awards, id: \.0) { a in
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: a.2 ? "rosette" : "lock.fill")
                            .font(.title3)
                            .foregroundStyle(a.2 ? Color(hex: 0xF59E0B) : .white.opacity(0.3))
                            .symbolEffect(.bounce, value: a.2)
                        Text(a.0).font(.subheadline.weight(.semibold)).foregroundStyle(a.2 ? .white : .white.opacity(0.5))
                        Text(a.1).font(.caption2).foregroundStyle(AZ.textTertiary).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background((a.2 ? Color(hex: 0xF59E0B).opacity(0.12) : .white.opacity(0.04)), in: .rect(cornerRadius: 14))
                }
            }
        }
        .glassCard(radius: 22, padding: 18)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Recent Workouts", icon: "clock.arrow.circlepath", tint: AZ.lavender)
            if sessions.isEmpty {
                EmptyStateView(icon: "figure.run", title: "No workouts yet", message: "Start a guided workout or log one you've done.",
                               actionTitle: "Log Workout") { showLog = true }
            }
            ForEach(sessions.prefix(8)) { s in
                HStack(spacing: 12) {
                    Image(systemName: FitnessCategory.icon(s.category))
                        .foregroundStyle(FitnessCategory.tint(s.category))
                        .frame(width: 40, height: 40)
                        .background(FitnessCategory.tint(s.category).opacity(0.15), in: .rect(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Text("\(s.date.formatted(.dateTime.month(.abbreviated).day())) · \(s.durationMinutes) min")
                            .font(.caption).foregroundStyle(AZ.textSecondary)
                    }
                    Spacer()
                    Text("\(s.calories) kcal").font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(Color(hex: 0xF59E0B))
                }
                .glassCard(radius: 18, padding: 12)
                .contextMenu {
                    Button("Delete", systemImage: "trash", role: .destructive) { withAnimation { context.delete(s) } }
                }
            }
        }
    }
}

// MARK: - Template card

struct WorkoutTemplateCard: View {
    let template: WorkoutTemplate
    var compact = false
    let onStart: () -> Void

    var body: some View {
        let tint = FitnessCategory.tint(template.category)
        Button { Haptics.medium(); onStart() } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: FitnessCategory.icon(template.category))
                        .font(.title3).foregroundStyle(tint)
                        .frame(width: 42, height: 42).background(tint.opacity(0.16), in: .rect(cornerRadius: 12))
                    Spacer()
                    Text(template.intensity.capitalized)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(tint.opacity(0.15), in: .capsule)
                }
                Text(template.title).font(.headline).foregroundStyle(.white).lineLimit(1)
                if !compact {
                    Text(template.description).font(.caption).foregroundStyle(AZ.textSecondary).lineLimit(2)
                }
                HStack(spacing: 10) {
                    Label("\(template.durationMinutes) min", systemImage: "clock")
                    Label("~\(template.estimatedCalories)", systemImage: "flame")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(AZ.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: 20, tint: tint, padding: 14)
        }
        .buttonStyle(.squish(0.96))
    }
}

// MARK: - Browse

struct WorkoutBrowseView: View {
    let onStart: (WorkoutTemplate) -> Void
    @State private var category: String?
    @State private var search = ""

    private var filtered: [WorkoutTemplate] {
        WorkoutTemplate.all.filter {
            (category == nil || $0.category == category) &&
            (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        ZStack {
            ImageBackdrop(url: AZImages.featureBackground, overlay: Color(red: 5/255, green: 2/255, blue: 17/255).opacity(0.75))
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            Chip(title: "All", isSelected: category == nil, tint: AZ.indigo) { category = nil }
                            ForEach(FitnessCategory.all, id: \.self) { c in
                                Chip(title: FitnessCategory.label(c), isSelected: category == c, tint: FitnessCategory.tint(c)) { category = c }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                        ForEach(filtered) { t in
                            WorkoutTemplateCard(template: t) { onStart(t) }
                                .transition(.scale(scale: 0.95).combined(with: .opacity))
                        }
                    }
                    .animation(.snappy, value: filtered)
                }
                .padding(20)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
        }
        .cosmicNavigation("Browse Workouts")
        .searchable(text: $search, prompt: "Search workouts")
    }
}

// MARK: - Timer

struct WorkoutTimerView: View {
    let template: WorkoutTemplate
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var elapsed: TimeInterval = 0
    @State private var running = true
    @State private var finished = false
    @State private var breathe = false

    private var total: TimeInterval { TimeInterval(template.durationMinutes * 60) }
    private var progress: Double { min(1, elapsed / max(total, 1)) }
    private var tint: Color { FitnessCategory.tint(template.category) }
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AZ.ink.ignoresSafeArea()
            RadialGradient(colors: [tint.opacity(breathe ? 0.45 : 0.25), .clear], center: .center, startRadius: 20, endRadius: 420)
                .ignoresSafeArea()
            StarField(count: 40).ignoresSafeArea().opacity(0.6)

            VStack(spacing: 28) {
                HStack {
                    Button { Haptics.tap(); dismiss() } label: {
                        Image(systemName: "xmark").font(.headline).foregroundStyle(.white)
                            .frame(width: 44, height: 44).background(.white.opacity(0.1), in: .circle)
                    }
                    .buttonStyle(.squish)
                    .accessibilityLabel("Close")
                    Spacer()
                }
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: FitnessCategory.icon(template.category)).font(.largeTitle).foregroundStyle(tint)
                        .symbolEffect(.pulse, isActive: running)
                    Text(template.title).font(.title.bold()).foregroundStyle(.white).multilineTextAlignment(.center)
                    Text(template.description).font(.subheadline).foregroundStyle(AZ.textSecondary).multilineTextAlignment(.center)
                }
                ZStack {
                    Circle().stroke(.white.opacity(0.08), lineWidth: 14)
                    Circle().trim(from: 0, to: progress)
                        .stroke(tint, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: tint.opacity(0.7), radius: 12)
                        .animation(.linear(duration: 1), value: progress)
                    VStack(spacing: 4) {
                        Text(format(max(0, total - elapsed)))
                            .font(.system(size: 54, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                            .contentTransition(.numericText(countsDown: true))
                        Text(finished ? "Complete!" : running ? "remaining" : "paused")
                            .font(.subheadline).foregroundStyle(AZ.textSecondary)
                    }
                }
                .frame(width: 260, height: 260)
                .scaleEffect(breathe && running ? 1.02 : 1)

                Spacer()
                HStack(spacing: 16) {
                    Button {
                        Haptics.medium()
                        withAnimation(.snappy) { running.toggle() }
                    } label: {
                        Image(systemName: running ? "pause.fill" : "play.fill")
                            .font(.title2).foregroundStyle(.white)
                            .frame(width: 72, height: 72)
                            .background(.white.opacity(0.12), in: .circle)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.squish)
                    .disabled(finished)
                    .accessibilityLabel(running ? "Pause" : "Resume")
                    GradientButton(title: finished ? "Save Workout" : "Finish", icon: "checkmark",
                                   gradient: LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .leading, endPoint: .trailing)) { save() }
                }
            }
            .padding(24)
            .frame(maxWidth: 600)
        }
        .onAppear { withAnimation(.easeInOut(duration: 3).repeatForever()) { breathe = true } }
        .onReceive(ticker) { _ in
            guard running, !finished else { return }
            elapsed += 1
            if elapsed >= total {
                finished = true
                running = false
                Haptics.success()
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: Int(elapsed) / 60)
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func save() {
        let minutes = max(1, Int((elapsed / 60).rounded()))
        context.insert(WorkoutSession(title: template.title, category: template.category, durationMinutes: minutes,
                                      calories: WorkoutTemplate.burn(category: template.category, intensity: template.intensity, minutes: minutes),
                                      notes: "", source: "timer"))
        Haptics.success()
        dismiss()
    }
}

// MARK: - Manual log

struct WorkoutLogEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category = "strength"
    @State private var minutes = 30
    @State private var calories = ""
    @State private var notes = ""
    @State private var date = Date()
    @State private var estimating = false
    @State private var explanation: String?
    @State private var error: String?

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            SheetCanvas {
                FieldLabel(text: "Workout Name")
                TextField("e.g. Leg day, Morning jog", text: $title).cosmicField()
                FieldLabel(text: "Type")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                    ForEach(FitnessCategory.all, id: \.self) { c in
                        Chip(title: FitnessCategory.label(c), isSelected: category == c, tint: FitnessCategory.tint(c)) { category = c }
                    }
                }
                FieldLabel(text: "Duration")
                Stepper(value: $minutes, in: 1...300, step: 5) {
                    Text("\(minutes) min").font(.title3.bold().monospacedDigit()).foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
                .cosmicField()
                FieldLabel(text: "Calories Burned")
                HStack(spacing: 10) {
                    TextField("\(WorkoutTemplate.burn(category: category, intensity: "medium", minutes: minutes))", text: $calories)
                        .keyboardType(.numberPad).cosmicField()
                    Button { Task { await estimate() } } label: {
                        Group {
                            if estimating { ProgressView().tint(.white) } else { Label("AI", systemImage: "sparkles") }
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 48)
                        .background(AZ.primaryGradient, in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.squish)
                    .disabled(estimating)
                    .accessibilityLabel("Estimate calories with AI")
                }
                if let explanation {
                    Text(explanation).font(.caption).foregroundStyle(AZ.lavender)
                        .transition(.opacity)
                }
                if let error {
                    Text(error).font(.caption).foregroundStyle(AZ.red)
                }
                FieldLabel(text: "Date")
                DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    .foregroundStyle(.white).tint(AZ.emerald).cosmicField()
                FieldLabel(text: "Notes")
                TextField("How did it feel?", text: $notes, axis: .vertical).lineLimit(2...5).cosmicField()
                GradientButton(title: "Save Workout", icon: "checkmark",
                               gradient: LinearGradient(colors: [AZ.emerald, Color(hex: 0x059669)], startPoint: .leading, endPoint: .trailing)) { save() }
                    .disabled(!canSave).opacity(canSave ? 1 : 0.5)
            }
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { SheetToolbar(canSave: canSave, onCancel: { dismiss() }, onSave: save) }
        }
        .presentationBackground(AZ.night)
    }

    private func estimate() async {
        error = nil
        estimating = true
        defer { estimating = false }
        do {
            let r = try await AIService.estimateBurn(type: FitnessCategory.label(category), minutes: minutes,
                                                     description: [title, notes].filter { !$0.isEmpty }.joined(separator: ". "))
            withAnimation { calories = "\(r.calories)"; explanation = r.explanation }
            Haptics.success()
        } catch {
            self.error = "Couldn't estimate right now. Enter calories manually or try again."
            Haptics.warning()
        }
    }

    private func save() {
        guard canSave else { return }
        let cals = Int(calories) ?? WorkoutTemplate.burn(category: category, intensity: "medium", minutes: minutes)
        context.insert(WorkoutSession(title: title.trimmingCharacters(in: .whitespaces), category: category, durationMinutes: minutes,
                                      calories: cals, notes: notes, date: date, source: "manual"))
        Haptics.success()
        dismiss()
    }
}

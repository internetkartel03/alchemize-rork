import SwiftUI
import SwiftData

private let mealTypes: [(id: String, label: String, icon: String)] = [
    ("breakfast", "Breakfast", "sunrise.fill"),
    ("lunch", "Lunch", "sun.max.fill"),
    ("dinner", "Dinner", "moon.stars.fill"),
    ("snack", "Snack", "carrot.fill"),
]
private let darkBackdrop = Color(red: 5/255, green: 2/255, blue: 17/255).opacity(0.7)

private func defaultMealType(for date: Date = Date()) -> String {
    switch Calendar.current.component(.hour, from: date) {
    case ..<11: "breakfast"
    case ..<16: "lunch"
    case 16..<21: "dinner"
    default: "snack"
    }
}

// MARK: - Main

struct CalorieView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodLog.loggedAt, order: .reverse) private var foods: [FoodLog]
    @Query(sort: \WaterLog.loggedAt, order: .reverse) private var water: [WaterLog]
    @State private var profile: NutritionProfile?
    @State private var showAdd = false
    @State private var showScan = false
    @State private var showProfile = false
    @State private var showMealPrep = false

    private var today: [FoodLog] { foods.filter { Calendar.current.isDateInToday($0.loggedAt) } }
    private var waterToday: Int { water.filter { Calendar.current.isDateInToday($0.loggedAt) }.reduce(0) { $0 + $1.amountMl } }
    private var consumed: Int { today.reduce(0) { $0 + $1.calories } }
    private func sum(_ k: KeyPath<FoodLog, Double>) -> Double { today.reduce(0) { $0 + $1[keyPath: k] } }

    var body: some View {
        ZStack {
            ImageBackdrop(url: AZImages.featureBackground, overlay: darkBackdrop)
            ScrollView {
                VStack(spacing: 16) {
                    if let p = profile {
                        ring(goal: p.calories)
                        macros(p)
                        waterCard(goal: p.waterMl)
                    }
                    actionsRow
                    scanBanner
                    mealsList
                }
                .padding(20)
                .padding(.bottom, 90)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingAddButton(icon: "plus") { showAdd = true }
                }
            }
            .padding(24)
        }
        .cosmicNavigation("Calorie Tracker")
        .onAppear { if profile == nil { profile = context.singleton { NutritionProfile() } } }
        .sheet(isPresented: $showAdd) { FoodEditor() }
        .sheet(isPresented: $showScan) { FoodScanView() }
        .sheet(isPresented: $showProfile) { if let profile { NutritionProfileEditor(profile: profile) } }
        .navigationDestination(isPresented: $showMealPrep) { MealPrepView() }
    }

    private func ring(goal: Int) -> some View {
        let progress = goal > 0 ? min(1, Double(consumed) / Double(goal)) : 0
        let remaining = goal - consumed
        return VStack(spacing: 14) {
            ZStack {
                Circle().stroke(.white.opacity(0.08), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(AngularGradient(colors: [Color(hex: 0xF97316), Color(hex: 0xFB923C), Color(hex: 0xFDBA74), Color(hex: 0xF97316)], center: .center),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: AZ.orange.opacity(0.5), radius: 10)
                    .animation(.spring(duration: 0.8), value: progress)
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill").font(.title2).foregroundStyle(AZ.orange)
                    Text("\(abs(remaining))")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(remaining >= 0 ? "kcal remaining" : "kcal over").font(.caption).foregroundStyle(AZ.textSecondary)
                }
            }
            .frame(width: 200, height: 200)
            HStack {
                ringStat("Goal", goal)
                Divider().frame(height: 30).overlay(.white.opacity(0.15))
                ringStat("Eaten", consumed)
            }
        }
        .frame(maxWidth: .infinity)
        .glassCard(radius: 24, tint: AZ.orange, padding: 20)
    }

    private func ringStat(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.headline.monospacedDigit()).foregroundStyle(.white)
            Text(label).font(.caption).foregroundStyle(AZ.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func macros(_ p: NutritionProfile) -> some View {
        VStack(spacing: 12) {
            macroRow("Protein", sum(\.protein), p.protein, AZ.red)
            macroRow("Carbs", sum(\.carbs), p.carbs, AZ.green)
            macroRow("Fat", sum(\.fat), p.fat, Color(hex: 0xEAB308))
            macroRow("Fiber", sum(\.fiber), p.fiber, AZ.purple)
        }
        .glassCard(radius: 22, padding: 18)
    }

    private func macroRow(_ label: String, _ value: Double, _ goal: Int, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Spacer()
                Text("\(Int(value.rounded())) / \(goal)g").font(.caption.monospacedDigit()).foregroundStyle(AZ.textSecondary)
            }
            ProgressBar(value: goal > 0 ? min(1, value / Double(goal)) : 0, tint: tint, height: 8)
        }
    }

    private func waterCard(goal: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "Water", icon: "drop.fill", tint: AZ.sky)
                Spacer()
                Text("\(waterToday) / \(goal) ml").font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(AZ.sky)
                    .contentTransition(.numericText())
            }
            ProgressBar(value: goal > 0 ? min(1, Double(waterToday) / Double(goal)) : 0, tint: AZ.sky, height: 10)
            HStack(spacing: 10) {
                ForEach([250, 500], id: \.self) { ml in
                    Button {
                        Haptics.soft()
                        withAnimation(.snappy) { context.insert(WaterLog(amountMl: ml)) }
                    } label: {
                        Label("\(ml) ml", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AZ.sky)
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background(AZ.sky.opacity(0.14), in: .rect(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AZ.sky.opacity(0.3)))
                    }
                    .buttonStyle(.squish)
                }
                if let last = water.first(where: { Calendar.current.isDateInToday($0.loggedAt) }) {
                    Button {
                        Haptics.tap()
                        withAnimation(.snappy) { context.delete(last) }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .foregroundStyle(AZ.textSecondary)
                            .frame(width: 44, height: 40)
                            .background(.white.opacity(0.06), in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.squish)
                    .accessibilityLabel("Undo last water")
                }
            }
        }
        .glassCard(radius: 22, tint: AZ.sky, padding: 18)
    }

    private var actionsRow: some View {
        HStack(spacing: 12) {
            actionTile("Meal Prep", "calendar", AZ.green) { showMealPrep = true }
            actionTile("Profile & Goals", "person.crop.circle", Color(hex: 0xA855F7)) { showProfile = true }
        }
    }

    private func actionTile(_ title: String, _ icon: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).font(.title3).foregroundStyle(tint)
                    .frame(width: 42, height: 42).background(tint.opacity(0.15), in: .rect(cornerRadius: 12))
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: 20, tint: tint, padding: 16)
        }
        .buttonStyle(.squish)
    }

    private var scanBanner: some View {
        Button { Haptics.medium(); showScan = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "bolt.fill").font(.title2).foregroundStyle(AZ.orange)
                    .frame(width: 48, height: 48).background(AZ.orange.opacity(0.15), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Food Scan").font(.headline).foregroundStyle(.white)
                    Text("Snap a photo, get calories & macros instantly").font(.caption).foregroundStyle(AZ.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(AZ.orange)
            }
            .glassCard(radius: 22, tint: AZ.orange, padding: 16)
        }
        .buttonStyle(.squish(0.97))
    }

    private var mealsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Today's Meals", icon: "fork.knife", tint: AZ.lavender)
            if today.isEmpty {
                EmptyStateView(icon: "fork.knife", title: "No meals logged", message: "Add food manually or scan a photo with AI.",
                               actionTitle: "Add Food") { showAdd = true }
            }
            ForEach(mealTypes, id: \.id) { meal in
                let items = today.filter { $0.mealType == meal.id }
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label(meal.label, systemImage: meal.icon).font(.headline).foregroundStyle(.white)
                            Spacer()
                            Text("\(items.reduce(0) { $0 + $1.calories }) kcal").font(.subheadline.weight(.semibold)).foregroundStyle(AZ.orange)
                        }
                        ForEach(items) { f in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(f.name).font(.subheadline.weight(.medium)).foregroundStyle(.white)
                                        if f.source == "ai" {
                                            Image(systemName: "sparkles").font(.caption2).foregroundStyle(AZ.amber)
                                        }
                                    }
                                    Text("\(f.serving.isEmpty ? "1 serving" : f.serving) · P \(Int(f.protein))g · C \(Int(f.carbs))g · F \(Int(f.fat))g")
                                        .font(.caption).foregroundStyle(AZ.textSecondary)
                                }
                                Spacer()
                                Text("\(f.calories)").font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(.white)
                            }
                            .padding(.vertical, 4)
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    withAnimation { context.delete(f) }
                                }
                            }
                        }
                    }
                    .glassCard(radius: 20, padding: 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
        }
        .animation(.snappy, value: today.count)
    }
}

// MARK: - Add food

struct FoodEditor: View {
    var estimate: FoodEstimate? = nil
    var onSaved: (() -> Void)? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var serving = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var fiber = ""
    @State private var mealType = defaultMealType()

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && (Int(calories) ?? -1) >= 0 && !calories.isEmpty }

    var body: some View {
        Group {
            if onSaved == nil { NavigationStack { form } } else { form }
        }
        .presentationBackground(AZ.night)
        .onAppear {
            guard let e = estimate, name.isEmpty else { return }
            name = e.foodName; serving = e.servingDescription; calories = "\(e.calories)"
            protein = clean(e.protein); carbs = clean(e.carbs); fat = clean(e.fat); fiber = clean(e.fiber)
        }
    }

    private var form: some View {
            SheetCanvas {
                FieldLabel(text: "Meal")
                HStack(spacing: 8) {
                    ForEach(mealTypes, id: \.id) { m in
                        Chip(title: m.label, isSelected: mealType == m.id, tint: AZ.orange) { mealType = m.id }
                    }
                }
                FieldLabel(text: "Food Name")
                TextField("e.g. Grilled chicken salad", text: $name).cosmicField()
                FieldLabel(text: "Serving")
                TextField("e.g. 1 bowl", text: $serving).cosmicField()
                FieldLabel(text: "Calories")
                TextField("0", text: $calories).keyboardType(.numberPad).font(.title2.bold()).cosmicField()
                HStack(spacing: 10) {
                    macroField("Protein (g)", $protein)
                    macroField("Carbs (g)", $carbs)
                }
                HStack(spacing: 10) {
                    macroField("Fat (g)", $fat)
                    macroField("Fiber (g)", $fiber)
                }
                GradientButton(title: "Add Food", icon: "plus") { save() }
                    .disabled(!canSave).opacity(canSave ? 1 : 0.5)
            }
            .navigationTitle(estimate == nil ? "Add Food" : "Review Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { SheetToolbar(canSave: canSave, onCancel: { dismiss() }, onSave: save) }
    }

    private func clean(_ v: Double) -> String { v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v) }

    private func macroField(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: label)
            TextField("0", text: text).keyboardType(.decimalPad).cosmicField()
        }
    }

    private func num(_ s: String) -> Double { Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    private func save() {
        guard canSave else { return }
        context.insert(FoodLog(name: name.trimmingCharacters(in: .whitespaces), serving: serving, calories: Int(calories) ?? 0,
                               protein: num(protein), carbs: num(carbs), fat: num(fat), fiber: num(fiber),
                               mealType: mealType, source: estimate == nil ? "manual" : "ai"))
        Haptics.success()
        if let onSaved { onSaved() } else { dismiss() }
    }
}

// MARK: - AI scan

struct FoodScanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var error: String?
    @State private var estimate: FoodEstimate?
    @State private var pulse = false

    var body: some View {
        NavigationStack {
            SheetCanvas {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(AZ.orange.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: image == nil ? [8, 6] : [])))
                    if let image {
                        Color.clear.overlay(Image(uiImage: image).resizable().scaledToFill())
                            .clipShape(.rect(cornerRadius: 24, style: .continuous))
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.viewfinder").font(.system(size: 46)).foregroundStyle(AZ.orange)
                                .scaleEffect(pulse ? 1.06 : 0.96)
                            Text("Snap your meal").font(.headline).foregroundStyle(.white)
                            Text("AI estimates calories and macros").font(.caption).foregroundStyle(AZ.textSecondary)
                        }
                    }
                    if isLoading {
                        RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.black.opacity(0.55))
                        VStack(spacing: 10) {
                            ProgressView().tint(.white).controlSize(.large)
                            Text("Analyzing your food...").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        }
                    }
                }
                .frame(height: 300)
                .onAppear { withAnimation(.easeInOut(duration: 1.4).repeatForever()) { pulse = true } }

                PhotoSourceButtons { img in
                    image = img
                    Task { await analyze(img) }
                }

                if let error {
                    VStack(spacing: 10) {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline).foregroundStyle(AZ.red)
                        if let image {
                            Button("Try Again") { Task { await analyze(image) } }
                                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .glassCard(radius: 16, tint: AZ.red, padding: 14)
                }
            }
            .navigationTitle("AI Food Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .navigationDestination(item: Binding(get: { estimate.map(EstimateBox.init) }, set: { estimate = $0?.value })) { box in
                FoodEditor(estimate: box.value, onSaved: { dismiss() })
            }
        }
        .presentationBackground(AZ.night)
    }

    private struct EstimateBox: Hashable, Identifiable {
        let value: FoodEstimate
        var id: String { "\(value.foodName)-\(value.calories)" }
        static func == (a: Self, b: Self) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }

    private func analyze(_ img: UIImage) async {
        error = nil
        isLoading = true
        Haptics.soft()
        defer { isLoading = false }
        do {
            estimate = try await AIService.estimateFood(image: img)
            Haptics.success()
        } catch {
            self.error = "Couldn't analyze this photo. Check your connection and try again."
            Haptics.warning()
        }
    }
}

// MARK: - Profile

struct NutritionProfileEditor: View {
    @Bindable var profile: NutritionProfile
    @Environment(\.dismiss) private var dismiss

    private let activities: [(String, String)] = [("sedentary", "Sedentary"), ("light", "Light"), ("moderate", "Moderate"), ("active", "Active"), ("very_active", "Very Active")]
    private let goals: [(String, String)] = [("lose", "Lose"), ("maintain", "Maintain"), ("gain", "Gain")]

    var body: some View {
        NavigationStack {
            SheetCanvas {
                FieldLabel(text: "Gender")
                HStack(spacing: 8) {
                    Chip(title: "Female", isSelected: profile.gender == "female", tint: Color(hex: 0xA855F7)) { profile.gender = "female" }
                    Chip(title: "Male", isSelected: profile.gender == "male", tint: Color(hex: 0xA855F7)) { profile.gender = "male" }
                }
                HStack(spacing: 10) {
                    numberField("Age", value: Binding(get: { Double(profile.age) }, set: { profile.age = max(10, Int($0)) }))
                    numberField("Height (cm)", value: $profile.heightCm)
                }
                HStack(spacing: 10) {
                    numberField("Weight (kg)", value: $profile.weightKg)
                    numberField("Target (kg)", value: $profile.targetWeightKg)
                }
                FieldLabel(text: "Activity Level")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(activities, id: \.0) { a in
                        Chip(title: a.1, isSelected: profile.activityLevel == a.0, tint: Color(hex: 0xA855F7)) { profile.activityLevel = a.0 }
                    }
                }
                FieldLabel(text: "Goal")
                HStack(spacing: 8) {
                    ForEach(goals, id: \.0) { g in
                        Chip(title: g.1, isSelected: profile.goal == g.0, tint: Color(hex: 0xA855F7)) { profile.goal = g.0 }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Targets").font(.headline).foregroundStyle(.white)
                    HStack {
                        target("\(profile.calories)", "kcal", AZ.orange)
                        target("\(profile.protein)g", "protein", AZ.red)
                        target("\(profile.carbs)g", "carbs", AZ.green)
                        target("\(profile.fat)g", "fat", Color(hex: 0xEAB308))
                    }
                    Text("Water: \(profile.waterMl) ml · Fiber: \(profile.fiber)g").font(.caption).foregroundStyle(AZ.textSecondary)
                }
                .glassCard(radius: 18, tint: Color(hex: 0xA855F7), padding: 16)
                GradientButton(title: "Recalculate Targets", icon: "arrow.triangle.2.circlepath") {
                    withAnimation(.snappy) { profile.recalculate() }
                    Haptics.success()
                }
            }
            .navigationTitle("Profile & Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { profile.recalculate(); dismiss() }.fontWeight(.semibold) }
            }
        }
        .presentationBackground(AZ.night)
    }

    private func numberField(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: label)
            TextField("0", value: value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad).cosmicField()
        }
    }

    private func target(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.weight(.bold).monospacedDigit()).foregroundStyle(tint).contentTransition(.numericText())
            Text(label).font(.caption2).foregroundStyle(AZ.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Meal prep

struct MealPrepView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MealPlanItem.name) private var items: [MealPlanItem]
    @State private var weekday = Calendar.current.component(.weekday, from: Date())
    @State private var addingFor: String?
    @State private var newName = ""
    @State private var newCalories = ""

    private let symbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        ZStack {
            ImageBackdrop(url: AZImages.featureBackground, overlay: darkBackdrop)
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { d in
                            let selected = d == weekday
                            Button {
                                Haptics.select()
                                withAnimation(.snappy) { weekday = d }
                            } label: {
                                VStack(spacing: 4) {
                                    Text(symbols[d - 1].prefix(3)).font(.caption.weight(.semibold))
                                    Circle().fill(items.contains { $0.weekday == d } ? AZ.green : .clear).frame(width: 5, height: 5)
                                }
                                .foregroundStyle(selected ? .white : AZ.textSecondary)
                                .frame(maxWidth: .infinity).frame(height: 52)
                                .background(selected ? AZ.green.opacity(0.85) : .white.opacity(0.05), in: .rect(cornerRadius: 14))
                            }
                            .buttonStyle(.squish(0.92))
                        }
                    }
                    let dayItems = items.filter { $0.weekday == weekday }
                    HStack {
                        Text(Calendar.current.weekdaySymbols[weekday - 1]).font(.title3.bold()).foregroundStyle(.white)
                        Spacer()
                        Text("\(dayItems.reduce(0) { $0 + $1.calories }) kcal planned").font(.subheadline.weight(.semibold)).foregroundStyle(AZ.green)
                    }
                    ForEach(mealTypes, id: \.id) { meal in
                        mealSection(meal, items: dayItems.filter { $0.mealType == meal.id })
                    }
                }
                .padding(20)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
        }
        .cosmicNavigation("Meal Prep")
        .alert("Add to \(mealTypes.first { $0.id == addingFor }?.label ?? "")", isPresented: Binding(get: { addingFor != nil }, set: { if !$0 { addingFor = nil } })) {
            TextField("Meal name", text: $newName)
            TextField("Calories", text: $newCalories).keyboardType(.numberPad)
            Button("Cancel", role: .cancel) { newName = ""; newCalories = "" }
            Button("Add") {
                let n = newName.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty, let type = addingFor {
                    withAnimation { context.insert(MealPlanItem(weekday: weekday, mealType: type, name: n, calories: Int(newCalories) ?? 0)) }
                    Haptics.success()
                }
                newName = ""; newCalories = ""
            }
        }
    }

    private func mealSection(_ meal: (id: String, label: String, icon: String), items: [MealPlanItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(meal.label, systemImage: meal.icon).font(.headline).foregroundStyle(.white)
                Spacer()
                Button { Haptics.tap(); addingFor = meal.id } label: {
                    Image(systemName: "plus").font(.footnote.weight(.bold)).foregroundStyle(AZ.green)
                        .frame(width: 30, height: 30).background(AZ.green.opacity(0.15), in: .circle)
                }
                .buttonStyle(.squish(0.85))
                .accessibilityLabel("Add \(meal.label)")
            }
            if items.isEmpty {
                Text("Nothing planned").font(.caption).foregroundStyle(AZ.textTertiary)
            }
            ForEach(items) { item in
                HStack(spacing: 12) {
                    Button {
                        Haptics.tap()
                        withAnimation(.snappy) { item.isCompleted.toggle() }
                    } label: {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3).foregroundStyle(item.isCompleted ? AZ.green : .white.opacity(0.4))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.squish(0.85))
                    Text(item.name).font(.subheadline).foregroundStyle(.white)
                        .strikethrough(item.isCompleted, color: .white.opacity(0.5))
                        .opacity(item.isCompleted ? 0.6 : 1)
                    Spacer()
                    if item.calories > 0 {
                        Text("\(item.calories) kcal").font(.caption.monospacedDigit()).foregroundStyle(AZ.textSecondary)
                    }
                }
                .contextMenu {
                    Button("Delete", systemImage: "trash", role: .destructive) { withAnimation { context.delete(item) } }
                }
            }
        }
        .glassCard(radius: 20, padding: 16)
    }
}

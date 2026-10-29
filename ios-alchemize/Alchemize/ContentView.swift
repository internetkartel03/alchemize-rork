import SwiftUI

enum Feature: String, CaseIterable, Identifiable, Hashable {
    case manifestation, affirmations, goals, habits, financial, calorie, todos, gratitude, fitness, appointments

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manifestation: "Manifestation Board"
        case .affirmations: "Affirmations"
        case .goals: "Set Goals"
        case .habits: "Habit Tracker"
        case .financial: "Financial Tracker"
        case .calorie: "Calorie Tracker"
        case .todos: "To-Do List"
        case .gratitude: "Gratitude Journal"
        case .fitness: "Fitness"
        case .appointments: "Appointments"
        }
    }

    var subtitle: String {
        switch self {
        case .manifestation: "Visualize and feel your desires until they become real."
        case .affirmations: "Reprogram your subconscious mind with powerful affirmations."
        case .goals: "Turn intention into measurable progress."
        case .habits: "Build consistency and condition yourself for greatness."
        case .financial: "Gain clarity over money, habits, and priorities."
        case .calorie: "Understand what fuels your body."
        case .todos: "Shape your day, one focused action at a time."
        case .gratitude: "Gratitude is the ability to experience life as a gift."
        case .fitness: "Track movement, energy, and physical transformation."
        case .appointments: "Organize your time with intention and clarity."
        }
    }

    var image: String {
        switch self {
        case .manifestation: AZImages.manifestationCard
        case .affirmations: AZImages.affirmationsCard
        case .goals: AZImages.goalsCard
        case .habits: AZImages.habitsCard
        case .financial: AZImages.financialCard
        case .calorie: AZImages.calorieCard
        case .todos: AZImages.todosCard
        case .gratitude: AZImages.gratitudeCard
        case .fitness: AZImages.fitnessCard
        case .appointments: AZImages.appointmentsCard
        }
    }

    var symbol: String {
        switch self {
        case .manifestation: "sparkles"
        case .affirmations: "quote.bubble"
        case .goals: "target"
        case .habits: "repeat"
        case .financial: "dollarsign.circle"
        case .calorie: "flame"
        case .todos: "checklist"
        case .gratitude: "heart"
        case .fitness: "figure.run"
        case .appointments: "calendar"
        }
    }
}

enum Route: Hashable {
    case feature(Feature)
    case settings
}

/// Shared visibility + theme preferences.
enum Prefs {
    static let hiddenFeaturesKey = "prefs.hiddenFeatures"
    static let themeKey = "prefs.theme" // "classic" | "cosmic"

    static func visible(from raw: String) -> [Feature] {
        let hidden = Set(raw.split(separator: ",").map(String.init))
        return Feature.allCases.filter { !hidden.contains($0.rawValue) }
    }
}

struct ContentView: View {
    @Environment(AuthStore.self) private var auth

    var body: some View {
        ZStack {
            if auth.isAuthenticated {
                RootNavigation()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                AuthView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: auth.isAuthenticated)
    }
}

struct RootNavigation: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .settings: SettingsView()
                    case .feature(let f): FeatureDestination(feature: f)
                    }
                }
        }
    }
}

struct FeatureDestination: View {
    let feature: Feature
    var body: some View {
        switch feature {
        case .manifestation: ManifestationBoardView()
        case .affirmations: AffirmationsView()
        case .goals: GoalsView()
        case .habits: HabitsView()
        case .financial: FinancialView()
        case .calorie: CalorieView()
        case .todos: TodosView()
        case .gratitude: GratitudeView()
        case .fitness: FitnessView()
        case .appointments: AppointmentsView()
        }
    }
}

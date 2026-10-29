import Foundation
import SwiftData

// MARK: - Manifestation

@Model
final class Manifestation {
    var id: UUID = UUID()
    var title: String = ""
    var intention: String = ""
    var details: String = ""
    var category: String = "other"
    @Attribute(.externalStorage) var imageData: Data?
    var isFavorite: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(title: String, intention: String, category: String, imageData: Data?) {
        self.title = title
        self.intention = intention
        self.category = category
        self.imageData = imageData
    }
}

// MARK: - Affirmation

@Model
final class Affirmation {
    var id: UUID = UUID()
    var text: String = ""
    var category: String = "self-love"
    var isFavorite: Bool = false
    var createdAt: Date = Date()

    init(text: String, category: String) {
        self.text = text
        self.category = category
    }
}

// MARK: - Goals

@Model
final class Goal {
    var id: UUID = UUID()
    var title: String = ""
    var details: String = ""
    var targetDate: Date?
    var status: String = "in_progress"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \GoalChecklistItem.goal) var checklist: [GoalChecklistItem] = []
    @Relationship(deleteRule: .cascade, inverse: \GoalCompletion.goal) var completions: [GoalCompletion] = []

    init(title: String, details: String, targetDate: Date?, status: String) {
        self.title = title
        self.details = details
        self.targetDate = targetDate
        self.status = status
    }

    var sortedChecklist: [GoalChecklistItem] { checklist.sorted { $0.order < $1.order } }
}

@Model
final class GoalChecklistItem {
    var id: UUID = UUID()
    var text: String = ""
    var isDone: Bool = false
    var order: Int = 0
    var goal: Goal?

    init(text: String, order: Int) {
        self.text = text
        self.order = order
    }
}

@Model
final class GoalCompletion {
    var id: UUID = UUID()
    var date: Date = Date()
    var goal: Goal?

    init(date: Date) { self.date = date }
}

// MARK: - Habits

@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "✨"
    var goal: Int = 1
    var goalUnit: String = "times"
    var type: String = "checkbox"
    var frequency: String = "daily"
    var customDays: [Int] = []
    var section: String = "custom"
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit) var logs: [HabitLog] = []

    init(name: String, icon: String, goal: Int, goalUnit: String, type: String, frequency: String, customDays: [Int], section: String) {
        self.name = name
        self.icon = icon
        self.goal = goal
        self.goalUnit = goalUnit
        self.type = type
        self.frequency = frequency
        self.customDays = customDays
        self.section = section
    }

    func log(on day: Date) -> HabitLog? {
        logs.first { Calendar.current.isDate($0.day, inSameDayAs: day) }
    }

    func progress(on day: Date) -> Int { log(on: day)?.value ?? 0 }

    /// Timer habits store seconds; goal is in minutes or hours.
    var goalTarget: Int {
        guard type == "timer" else { return max(goal, 1) }
        return goal * (goalUnit == "hours" ? 3600 : 60)
    }

    func isComplete(on day: Date) -> Bool { progress(on: day) >= goalTarget }

    func isScheduled(on day: Date) -> Bool {
        switch frequency {
        case "custom", "weekly":
            if customDays.isEmpty { return true }
            let weekday = Calendar.current.component(.weekday, from: day) - 1
            return customDays.contains(weekday)
        default: return true
        }
    }

    var streak: Int {
        var count = 0
        var day = Calendar.current.startOfDay(for: Date())
        if !isComplete(on: day) {
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        while isComplete(on: day) {
            count += 1
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }
}

@Model
final class HabitLog {
    var id: UUID = UUID()
    var day: Date = Date()
    var value: Int = 0
    var habit: Habit?

    init(day: Date, value: Int) {
        self.day = Calendar.current.startOfDay(for: day)
        self.value = value
    }
}

// MARK: - Todos

@Model
final class TodoTask {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var dueDate: Date?
    var isDone: Bool = false
    var priority: String = "none"
    var order: Int = 0
    var reminderDate: Date?
    var notificationId: String?
    var createdAt: Date = Date()
    var completedAt: Date?

    init(title: String, notes: String = "", dueDate: Date? = nil, priority: String = "none", order: Int = 0) {
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.priority = priority
        self.order = order
    }
}

// MARK: - Gratitude

@Model
final class GratitudeEntry {
    var id: UUID = UUID()
    var entryDate: Date = Date()
    var gratitude1: String = ""
    var gratitude2: String = ""
    var gratitude3: String = ""
    var reflection: String = ""
    var createdAt: Date = Date()

    init(entryDate: Date, gratitude1: String, gratitude2: String, gratitude3: String, reflection: String) {
        self.entryDate = entryDate
        self.gratitude1 = gratitude1
        self.gratitude2 = gratitude2
        self.gratitude3 = gratitude3
        self.reflection = reflection
    }

    var items: [String] { [gratitude1, gratitude2, gratitude3].filter { !$0.isEmpty } }
}

// MARK: - Appointments

@Model
final class Appointment {
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = Date()
    var category: String = "personal"
    var notes: String = ""
    var reminder: Bool = false
    var notificationId: String?
    var createdAt: Date = Date()

    init(title: String, date: Date, category: String, notes: String, reminder: Bool) {
        self.title = title
        self.date = date
        self.category = category
        self.notes = notes
        self.reminder = reminder
    }
}

// MARK: - Finance

@Model
final class FinanceEntry {
    var id: UUID = UUID()
    var kind: String = "expense" // income | expense
    var title: String = ""
    var amount: Double = 0
    /// Income only: take-home after taxes. Falls back to gross when 0.
    var netAmount: Double = 0
    var category: String = "other"
    var date: Date = Date()
    var notes: String = ""
    var createdAt: Date = Date()

    init(kind: String, title: String, amount: Double, netAmount: Double = 0, category: String, date: Date, notes: String) {
        self.kind = kind
        self.title = title
        self.amount = amount
        self.netAmount = netAmount
        self.category = category
        self.date = date
        self.notes = notes
    }
}

@Model
final class FinanceNotes {
    var loginInfo: String = ""
    var debtNotes: String = ""
    var debtAmount: Double = 0
    var savingsAmount: Double = 0
    var emergencyFund: Double = 0
    var savingsNotes: String = ""
    var notepad: String = ""
    var updatedAt: Date = Date()

    init() {}
}

// MARK: - Nutrition

@Model
final class FoodLog {
    var id: UUID = UUID()
    var name: String = ""
    var serving: String = ""
    var calories: Int = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0
    var mealType: String = "breakfast"
    var source: String = "manual"
    var loggedAt: Date = Date()

    init(name: String, serving: String, calories: Int, protein: Double, carbs: Double, fat: Double, fiber: Double, mealType: String, source: String, loggedAt: Date = Date()) {
        self.name = name
        self.serving = serving
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.mealType = mealType
        self.source = source
        self.loggedAt = loggedAt
    }
}

@Model
final class WaterLog {
    var id: UUID = UUID()
    var amountMl: Int = 0
    var loggedAt: Date = Date()

    init(amountMl: Int) { self.amountMl = amountMl }
}

@Model
final class NutritionProfile {
    var heightCm: Double = 170
    var weightKg: Double = 70
    var targetWeightKg: Double = 68
    var age: Int = 30
    var gender: String = "female"
    var activityLevel: String = "moderate"
    var goal: String = "maintain"
    var calories: Int = 2000
    var protein: Int = 150
    var carbs: Int = 250
    var fat: Int = 65
    var fiber: Int = 25
    var waterMl: Int = 2000

    init() {}

    func recalculate() {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        let bmr = gender == "male" ? base + 5 : base - 161
        let factor: Double = switch activityLevel {
        case "sedentary": 1.2
        case "light": 1.375
        case "active": 1.725
        case "very_active": 1.9
        default: 1.55
        }
        var tdee = bmr * factor
        if goal == "lose" { tdee -= 500 }
        if goal == "gain" { tdee += 300 }
        calories = max(1200, Int(tdee.rounded()))
        protein = Int((weightKg * 2.0).rounded())
        fat = Int((Double(calories) * 0.25 / 9).rounded())
        carbs = max(0, Int(((Double(calories) - Double(protein * 4) - Double(fat * 9)) / 4).rounded()))
        fiber = gender == "male" ? 38 : 25
        waterMl = Int((weightKg * 33).rounded())
    }
}

@Model
final class MealPlanItem {
    var id: UUID = UUID()
    var weekday: Int = 1
    var mealType: String = "breakfast"
    var name: String = ""
    var calories: Int = 0
    var isCompleted: Bool = false

    init(weekday: Int, mealType: String, name: String, calories: Int) {
        self.weekday = weekday
        self.mealType = mealType
        self.name = name
        self.calories = calories
    }
}

// MARK: - Fitness

@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var title: String = ""
    var category: String = "other"
    var durationMinutes: Int = 0
    var calories: Int = 0
    var notes: String = ""
    var date: Date = Date()
    var source: String = "manual"

    init(title: String, category: String, durationMinutes: Int, calories: Int, notes: String, date: Date = Date(), source: String = "manual") {
        self.title = title
        self.category = category
        self.durationMinutes = durationMinutes
        self.calories = calories
        self.notes = notes
        self.date = date
        self.source = source
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Manifestation.self, Affirmation.self, Goal.self, GoalChecklistItem.self, GoalCompletion.self,
        Habit.self, HabitLog.self, TodoTask.self, GratitudeEntry.self, Appointment.self,
        FinanceEntry.self, FinanceNotes.self, FoodLog.self, WaterLog.self, NutritionProfile.self,
        MealPlanItem.self, WorkoutSession.self,
    ]
}

import Foundation

struct Goal: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var emoji: String
    var isCustom: Bool
    var strategy: String
    var subPlans: [String]
    var generatedPlan: [String]?
    
    init(id: UUID = UUID(), title: String, emoji: String, isCustom: Bool = false, strategy: String = "", subPlans: [String] = [], generatedPlan: [String]? = nil) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.isCustom = isCustom
        self.strategy = strategy
        self.subPlans = subPlans
        self.generatedPlan = generatedPlan
    }
}

// Predefined goals
extension Goal {
    static let predefinedGoals: [Goal] = [
        Goal(title: "Drink more water", emoji: "💧"),
        Goal(title: "Read", emoji: "📚"),
        Goal(title: "Meditate", emoji: "🙏"),
        Goal(title: "Run", emoji: "🏃"),
        Goal(title: "Journal", emoji: "✍️"),
        Goal(title: "Lift", emoji: "🏋️"),
        Goal(title: "Budget", emoji: "💰"),
        Goal(title: "Sleep better", emoji: "😴"),
        Goal(title: "Eat right", emoji: "🥗"),
        Goal(title: "Stay tidy", emoji: "🧹"),
        Goal(title: "Learn a language", emoji: "🗣️"),
        Goal(title: "Practice guitar", emoji: "🎸"),
        Goal(title: "Take vitamins", emoji: "💊"),
        Goal(title: "Walk 10k steps", emoji: "👣"),
        Goal(title: "Stretch daily", emoji: "🧘‍♂️"),
        Goal(title: "Call family", emoji: "👨‍👩‍👧‍👦"),
        Goal(title: "Save money", emoji: "🏦"),
        Goal(title: "Cook meals", emoji: "👨‍🍳"),
        Goal(title: "Less screen time", emoji: "📱"),
        Goal(title: "Practice gratitude", emoji: "🙌")
    ]
} 
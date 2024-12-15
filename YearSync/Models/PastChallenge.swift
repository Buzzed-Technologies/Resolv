import Foundation

struct PastChallenge: Identifiable, Codable {
    let id: UUID
    let completedDate: Date
    let duration: Int
    let goals: [Goal]
    let completionRate: Double
    let journalEntries: [JournalEntry]
    
    enum CodingKeys: String, CodingKey {
        case id
        case completedDate
        case duration
        case goals
        case completionRate
        case journalEntries
    }
    
    init(from userData: UserData) {
        self.id = UUID()
        self.completedDate = Date()
        self.duration = userData.planDuration
        self.goals = userData.goals
        
        // Calculate completion rate from task history
        let allTasks = userData.dailyTaskHistory.flatMap { $0.tasks }
        let completedTasks = allTasks.filter { $0.isCompleted }
        self.completionRate = Double(completedTasks.count) / Double(max(1, allTasks.count))
        
        self.journalEntries = userData.journalEntries
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        completedDate = try container.decode(Date.self, forKey: .completedDate)
        duration = try container.decode(Int.self, forKey: .duration)
        goals = try container.decode([Goal].self, forKey: .goals)
        completionRate = try container.decode(Double.self, forKey: .completionRate)
        journalEntries = try container.decode([JournalEntry].self, forKey: .journalEntries)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(completedDate, forKey: .completedDate)
        try container.encode(duration, forKey: .duration)
        try container.encode(goals, forKey: .goals)
        try container.encode(completionRate, forKey: .completionRate)
        try container.encode(journalEntries, forKey: .journalEntries)
    }
}

#if DEBUG
extension PastChallenge {
    static var preview: PastChallenge {
        PastChallenge(
            from: UserData(
                planDuration: 21,
                goals: [
                    Goal(title: "Exercise More", emoji: "🏃‍♂️", strategy: "Daily workout routine", subPlans: ["Morning jog", "Evening stretches"]),
                    Goal(title: "Read Books", emoji: "📚", strategy: "Read before bed", subPlans: ["30 minutes reading", "Take notes"])
                ]
            )
        )
    }
}
#endif 
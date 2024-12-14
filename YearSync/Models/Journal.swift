import Foundation

struct JournalEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    var content: String
    var completedTasks: [String]
    var isVisible: Bool
    
    init(content: String, completedTasks: [String], date: Date = Date()) {
        self.id = UUID()
        self.content = content
        self.completedTasks = completedTasks
        self.date = date
        self.isVisible = false
    }
}

struct WeeklySummary: Identifiable, Codable {
    let id: UUID
    let weekStartDate: Date
    let weekEndDate: Date
    var aiAnalysis: String
    var suggestedGoals: [String]
    
    init(weekStartDate: Date, weekEndDate: Date, aiAnalysis: String = "", suggestedGoals: [String] = []) {
        self.id = UUID()
        self.weekStartDate = weekStartDate
        self.weekEndDate = weekEndDate
        self.aiAnalysis = aiAnalysis
        self.suggestedGoals = suggestedGoals
    }
} 
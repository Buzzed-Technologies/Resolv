import Foundation
import SwiftUI

extension Notification.Name {
    static let weeklyJournalAnalysisCompleted = Notification.Name("weeklyJournalAnalysisCompleted")
}

struct WeeklySummaryData {
    let oldEntries: [JournalEntry]
    let weekStartDate: Date
    let weekEndDate: Date
    let entriesToUpdate: [Int]
}

struct UserData: Codable {
    var name: String?
    var sex: String?
    var age: Int?
    var height: Double?
    var weight: Double?
    var wakeTime: Date?
    var sleepTime: Date?
    var notificationPreference: NotificationPreference
    var planDuration: Int
    var goals: [Goal]
    var planStartDate: Date?
    var lastCompletedDay: Int?
    var dailyTaskHistory: [DailyTaskHistory]
    var journalEntries: [JournalEntry]
    var weeklySummaries: [WeeklySummary]
    var pastChallenges: [PastChallenge] = []
    
    init(name: String? = nil,
         sex: String? = nil,
         age: Int? = nil,
         height: Double? = nil,
         weight: Double? = nil,
         wakeTime: Date? = nil,
         sleepTime: Date? = nil,
         notificationPreference: NotificationPreference = .occasionally,
         planDuration: Int = 21,
         goals: [Goal] = [],
         planStartDate: Date? = nil,
         lastCompletedDay: Int? = nil,
         dailyTaskHistory: [DailyTaskHistory] = [],
         journalEntries: [JournalEntry] = [],
         weeklySummaries: [WeeklySummary] = []) {
        self.name = name
        self.sex = sex
        self.age = age
        self.height = height
        self.weight = weight
        self.wakeTime = wakeTime
        self.sleepTime = sleepTime
        self.notificationPreference = notificationPreference
        self.planDuration = planDuration
        self.goals = goals
        self.planStartDate = planStartDate
        self.lastCompletedDay = lastCompletedDay
        self.dailyTaskHistory = dailyTaskHistory
        self.journalEntries = journalEntries
        self.weeklySummaries = weeklySummaries
        
        // Save initial state
        saveState()
    }
    
    private func saveState() {
        // Ensure we're on the main thread for UserDefaults
        if Thread.isMainThread {
            UserDefaultsHelper.shared.saveUserData(self)
        } else {
            DispatchQueue.main.async {
                UserDefaultsHelper.shared.saveUserData(self)
            }
        }
    }
    
    var currentDay: Int? {
        guard let startDate = planStartDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return min(days + 1, planDuration)
    }
    
    var isCompleted: Bool {
        guard let currentDay = currentDay else { return false }
        return currentDay >= planDuration
    }
    
    var formattedWakeTime: String {
        guard let wakeTime = wakeTime else { return "6:00 AM" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: wakeTime)
    }
    
    var formattedSleepTime: String {
        guard let sleepTime = sleepTime else { return "10:00 PM" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: sleepTime)
    }
    
    mutating func addDailyHistory(day: Int, tasks: [DailyTask]) {
        let history = DailyTaskHistory(day: day, date: Date(), tasks: tasks)
        dailyTaskHistory.append(history)
        
        // Keep only the last 7 days of history
        if dailyTaskHistory.count > 7 {
            dailyTaskHistory.removeFirst(dailyTaskHistory.count - 7)
        }
        
        saveState()
    }
    
    mutating func updateLastDayTasks(_ tasks: [DailyTask]) {
        guard !dailyTaskHistory.isEmpty else { return }
        dailyTaskHistory[dailyTaskHistory.count - 1].tasks = tasks
        saveState()
    }
    
    func getTaskHistory(for goalTitle: String) -> [DailyTask] {
        return dailyTaskHistory.flatMap { $0.tasks.filter { $0.goalTitle == goalTitle } }
    }
    
    mutating func addJournalEntry(_ entry: JournalEntry) {
        journalEntries.append(entry)
        saveState()
        
        // Return early if there's nothing to analyze
        guard shouldGenerateWeeklySummary() else { return }
        
        let analysisData = prepareWeeklySummaryData()
        
        // Start analysis in a separate task
        Task {
            await WeeklySummaryAnalyzer.shared.analyze(data: analysisData)
        }
    }
    
    private func shouldGenerateWeeklySummary() -> Bool {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        let oldEntries = journalEntries.filter { $0.date <= oneWeekAgo }
        return !oldEntries.isEmpty
    }
    
    private func prepareWeeklySummaryData() -> WeeklySummaryData {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        
        let oldEntries = journalEntries.filter { $0.date <= oneWeekAgo }
        let weekStartDate = calendar.date(byAdding: .day, value: -7, to: oldEntries[0].date)!
        let weekEndDate = oldEntries[0].date
        
        let entriesToUpdate = journalEntries.enumerated()
            .filter { $0.element.date <= oneWeekAgo }
            .map { $0.offset }
        
        return WeeklySummaryData(
            oldEntries: oldEntries,
            weekStartDate: weekStartDate,
            weekEndDate: weekEndDate,
            entriesToUpdate: entriesToUpdate
        )
    }
    
    mutating func applyWeeklySummary(_ summary: WeeklySummary, entryIndices: [Int]) {
        weeklySummaries.append(summary)
        for index in entryIndices {
            if index < journalEntries.count {
                journalEntries[index].isVisible = true
            }
        }
        saveState()
        
        // Notify UI of changes
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .init("userDataUpdated"), object: nil)
        }
    }
    
    func getCurrentWeekEntries() -> [JournalEntry] {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        return journalEntries.filter { $0.date > oneWeekAgo }
    }
    
    func getVisibleEntries() -> [JournalEntry] {
        return journalEntries.filter { $0.isVisible }
    }
    
    mutating func resetPlan() {
        if !goals.isEmpty {
            let pastChallenge = PastChallenge(from: self)
            pastChallenges.append(pastChallenge)
        }
        
        planStartDate = nil
        lastCompletedDay = nil
        goals = []
        dailyTaskHistory = []
        journalEntries = []
        weeklySummaries = []
        saveState()
    }
}

struct DailyTaskHistory: Codable {
    let day: Int
    let date: Date
    var tasks: [DailyTask]
    var summary: String?
}

struct DailyTask: Codable, Identifiable, Hashable {
    let id: UUID
    let goalTitle: String
    let task: String
    let emoji: String
    var isCompleted: Bool
    var completedAt: Date?
    let intensity: TaskIntensity
    
    init(id: UUID = UUID(), 
         goalTitle: String, 
         task: String, 
         emoji: String = "📝", 
         isCompleted: Bool = false, 
         completedAt: Date? = nil,
         intensity: TaskIntensity = .beginner) {
        self.id = id
        self.goalTitle = goalTitle
        self.task = task
        self.emoji = emoji
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.intensity = intensity
    }
    
    enum TaskIntensity: String, Codable {
        case beginner
        case intermediate
        case advanced
        
        static func forDay(_ day: Int, totalDays: Int) -> TaskIntensity {
            let progress = Double(day) / Double(totalDays)
            switch progress {
            case 0.0...0.3:
                return .beginner
            case 0.3...0.7:
                return .intermediate
            default:
                return .advanced
            }
        }
    }
    
    var formattedCompletionTime: String? {
        guard let completedAt = completedAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: completedAt)
    }
    
    var completionStatus: CompletionStatus {
        if isCompleted {
            return .completed
        }
        return .pending
    }
    
    enum CompletionStatus {
        case pending
        case completed
        
        var color: Color {
            switch self {
            case .pending:
                return .gray
            case .completed:
                return .green
            }
        }
    }
}

enum NotificationPreference: String, Codable, CaseIterable {
    case never = "Never"
    case occasionally = "Occasionally"
    case often = "Often"
} 

// Create a separate class to handle the analysis
actor WeeklySummaryAnalyzer {
    static let shared = WeeklySummaryAnalyzer()
    
    private init() {}
    
    func analyze(data: WeeklySummaryData) async {
        if let (summary, indices) = try? await generateWeeklySummary(from: data) {
            NotificationCenter.default.post(
                name: .weeklyJournalAnalysisCompleted,
                object: nil,
                userInfo: ["summary": summary, "indices": indices]
            )
        }
    }
    
    private func generateWeeklySummary(from data: WeeklySummaryData) async throws -> (WeeklySummary, [Int]) {
        let (analysis, goals) = try await OpenAIService.shared.analyzeWeeklyJournalEntries(data.oldEntries)
        
        let summary = WeeklySummary(
            weekStartDate: data.weekStartDate,
            weekEndDate: data.weekEndDate,
            aiAnalysis: analysis,
            suggestedGoals: goals
        )
        
        return (summary, data.entriesToUpdate)
    }
} 
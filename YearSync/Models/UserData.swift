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
    }
    
    mutating func updateLastDayTasks(_ tasks: [DailyTask]) {
        guard !dailyTaskHistory.isEmpty else { return }
        dailyTaskHistory[dailyTaskHistory.count - 1].tasks = tasks
    }
    
    func getTaskHistory(for goalTitle: String) -> [DailyTask] {
        return dailyTaskHistory.flatMap { $0.tasks.filter { $0.goalTitle == goalTitle } }
    }
    
    mutating func addJournalEntry(_ entry: JournalEntry) {
        journalEntries.append(entry)
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
            journalEntries[index].isVisible = true
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
        planStartDate = nil
        lastCompletedDay = nil
        goals = []
        dailyTaskHistory = []
        journalEntries = []
        weeklySummaries = []
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
    let scheduledTime: Date
    let emoji: String
    var isCompleted: Bool
    var completedAt: Date?
    let intensity: TaskIntensity
    
    init(id: UUID = UUID(), 
         goalTitle: String, 
         task: String, 
         scheduledTime: Date, 
         emoji: String = "📝", 
         isCompleted: Bool = false, 
         completedAt: Date? = nil,
         intensity: TaskIntensity = .beginner) {
        self.id = id
        self.goalTitle = goalTitle
        self.task = task
        self.scheduledTime = scheduledTime
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
    
    var timeWindow: ClosedRange<Date> {
        let calendar = Calendar.current
        let oneHourBefore = calendar.date(byAdding: .hour, value: -1, to: scheduledTime)!
        let oneHourAfter = calendar.date(byAdding: .hour, value: 1, to: scheduledTime)!
        return oneHourBefore...oneHourAfter
    }
    
    var isInCurrentTimeWindow: Bool {
        timeWindow.contains(Date())
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: scheduledTime)
    }
    
    var formattedCompletionTime: String? {
        guard let completedAt = completedAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: completedAt)
    }
    
    var completionStatus: CompletionStatus {
        guard let completedAt = completedAt else { return .pending }
        
        let diffInMinutes = Calendar.current.dateComponents([.minute], 
                                                          from: scheduledTime, 
                                                          to: completedAt).minute ?? 0
        
        if abs(diffInMinutes) <= 15 {
            return .onTime
        } else if diffInMinutes < 0 {
            return .early
        } else {
            return .late
        }
    }
    
    enum CompletionStatus {
        case pending
        case early
        case onTime
        case late
        
        var color: Color {
            switch self {
            case .pending:
                return .gray
            case .early:
                return .yellow
            case .onTime:
                return .green
            case .late:
                return .red
            }
        }
    }
    
    static func parseTime(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        if let date = formatter.date(from: timeString) {
            // Convert the parsed time to today's date
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.hour, .minute], from: date)
            return calendar.date(bySettingHour: components.hour ?? 0,
                               minute: components.minute ?? 0,
                               second: 0,
                               of: now)
        }
        return nil
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
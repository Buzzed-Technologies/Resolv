import Foundation
import SwiftUI

@MainActor
class AppViewModel: ObservableObject {
    @Published var userData: UserData {
        didSet {
            saveUserData()
        }
    }
    @Published var currentScreen: Screen = .welcome
    @Published var isLoading = false
    @Published var isLoadingTasks = false
    @Published var dailyTasks: [DailyTask] = []
    @Published var showingHistory = false
    @Published var showingPlanOverview = false
    @Published var dailySummary: String = ""
    
    private let userDefaults = UserDefaults.standard
    private let userDataKey = "userData"
    private var taskRefreshTimer: Timer?
    
    var taskHistory: [DailyTaskHistory] {
        userData.dailyTaskHistory.sorted { $0.date > $1.date }
    }
    
    var completedTasksToday: Int {
        dailyTasks.filter { $0.isCompleted }.count
    }
    
    var totalTasksToday: Int {
        dailyTasks.count
    }
    
    var completionPercentage: Double {
        guard totalTasksToday > 0 else { return 0 }
        return Double(completedTasksToday) / Double(totalTasksToday)
    }
    
    init() {
        // Load saved user data or create new
        if let savedData = userDefaults.data(forKey: userDataKey),
           let decodedData = try? JSONDecoder().decode(UserData.self, from: savedData) {
            self.userData = decodedData
            
            // If we have a saved plan, check if we should show the daily checklist
            if decodedData.planStartDate != nil {
                self.currentScreen = .dailyChecklist
                // Generate daily tasks if needed
                Task {
                    await generateDailyTasksIfNeeded()
                }
            }
        } else {
            self.userData = UserData()
        }
        
        // Start timer to refresh visible tasks
        startTaskRefreshTimer()
    }
    
    deinit {
        taskRefreshTimer?.invalidate()
    }
    
    private func startTaskRefreshTimer() {
        // Refresh every minute to check for new tasks entering their time window
        taskRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.objectWillChange.send()
            }
        }
    }
    
    var currentTasks: [DailyTask] {
        let now = Date()
        return dailyTasks
            .filter { !$0.isCompleted && $0.isInCurrentTimeWindow }
            .sorted { $0.scheduledTime < $1.scheduledTime }
    }
    
    var upcomingTasks: [DailyTask] {
        let now = Date()
        return dailyTasks
            .filter { !$0.isCompleted && $0.scheduledTime > now }
            .sorted { $0.scheduledTime < $1.scheduledTime }
            .prefix(3)
            .map { $0 }
    }
    
    enum Screen {
        case welcome
        case goalSelection
        case durationSelection
        case personalInfo
        case userPreferences
        case planCreation
        case dailyChecklist
    }
    
    func moveToNextScreen() {
        switch currentScreen {
        case .welcome:
            currentScreen = .goalSelection
        case .goalSelection:
            currentScreen = .durationSelection
        case .durationSelection:
            currentScreen = .personalInfo
        case .personalInfo:
            currentScreen = .userPreferences
        case .userPreferences:
            currentScreen = .planCreation
        case .planCreation:
            currentScreen = .dailyChecklist
            // Generate initial daily tasks
            Task {
                await generateDailyTasksIfNeeded()
            }
        case .dailyChecklist:
            break
        }
    }
    
    func updateUserPreferences(name: String, wakeTime: Date, sleepTime: Date) {
        userData.name = name
        userData.wakeTime = wakeTime
        userData.sleepTime = sleepTime
        saveUserData()
    }
    
    func addGoal(_ goal: Goal) {
        userData.goals.append(goal)
    }
    
    func removeGoal(_ goal: Goal) {
        userData.goals.removeAll { $0.id == goal.id }
    }
    
    func updatePlanDuration(_ days: Int) {
        userData.planDuration = days
    }
    
    func updateNotificationPreference(_ preference: NotificationPreference) {
        userData.notificationPreference = preference
        saveUserData()
        
        // Schedule notifications based on the new preference
        Task {
            await NotificationManager.shared.scheduleNotifications(for: preference, userData: userData)
        }
    }
    
    private func saveUserData() {
        if let encoded = try? JSONEncoder().encode(userData) {
            userDefaults.set(encoded, forKey: userDataKey)
        }
        
        // Reschedule notifications when user data is saved
        Task {
            await NotificationManager.shared.scheduleNotifications(
                for: userData.notificationPreference,
                userData: userData
            )
        }
    }
    
    enum PlanGenerationError: LocalizedError {
        case failedToGeneratePlan
        case invalidResponse
        case decodingError
        
        var errorDescription: String? {
            switch self {
            case .failedToGeneratePlan:
                return "Failed to generate plan. Please try again."
            case .invalidResponse:
                return "Received invalid response from the server."
            case .decodingError:
                return "Error processing the generated plan."
            }
        }
    }
    
    func generatePlan() async throws -> [Goal] {
        isLoading = true
        defer { isLoading = false }
        
        print("Generating plan for goals:", userData.goals.map { $0.title })
        
        return try await withCheckedThrowingContinuation { continuation in
            let goalTitles = userData.goals.map { $0.title }
            
            OpenAIService.shared.generatePlan(for: goalTitles, duration: userData.planDuration) { result in
                if let planJSON = result {
                    print("Received plan JSON:", planJSON)
                    do {
                        // Parse the JSON response
                        let decoder = JSONDecoder()
                        let data = planJSON.data(using: .utf8)!
                        let response = try decoder.decode(PlanResponse.self, from: data)
                        
                        print("Decoded response:", response)
                        
                        // Create new goals with generated sub-plans while preserving IDs and emojis
                        var updatedGoals = self.userData.goals
                        for i in 0..<updatedGoals.count {
                            if let generatedGoal = response.goals.first(where: { $0.title == updatedGoals[i].title }) {
                                updatedGoals[i].subPlans = generatedGoal.subPlans
                            }
                        }
                        
                        // Update userData with the new goals and start date
                        Task { @MainActor in
                            self.userData.goals = updatedGoals
                            self.userData.planStartDate = Date()
                            self.userData.lastCompletedDay = nil
                            self.userData.dailyTaskHistory = []
                        }
                        
                        continuation.resume(returning: updatedGoals)
                    } catch {
                        print("Decoding error:", error)
                        continuation.resume(throwing: PlanGenerationError.decodingError)
                    }
                } else {
                    print("Failed to generate plan: No result received")
                    continuation.resume(throwing: PlanGenerationError.failedToGeneratePlan)
                }
            }
        }
    }
    
    func generateDailyTasksIfNeeded() async {
        guard let currentDay = userData.currentDay else { return }
        
        // Check if we already have tasks for today
        if let lastHistory = userData.dailyTaskHistory.last {
            let calendar = Calendar.current
            let isNewDay = !calendar.isDate(lastHistory.date, inSameDayAs: Date())
            
            if isNewDay {
                // It's a new day, complete previous day if not completed
                if userData.lastCompletedDay != currentDay - 1 {
                    userData.lastCompletedDay = currentDay - 1
                    userData.updateLastDayTasks(dailyTasks)
                    saveUserData()
                }
            } else {
                // Same day, return existing tasks
                self.dailyTasks = lastHistory.tasks
                if let summary = lastHistory.summary {
                    self.dailySummary = summary
                } else {
                    await generateDailySummary()
                }
                return
            }
        }
        
        isLoadingTasks = true
        defer { isLoadingTasks = false }
        
        // Get previous day's tasks and completion rate
        let previousTasks = userData.dailyTaskHistory.last?.tasks ?? []
        let previousCompletion = previousTasks.isEmpty ? nil :
            Double(previousTasks.filter { $0.isCompleted }.count) / Double(previousTasks.count)
        
        return await withCheckedContinuation { continuation in
            OpenAIService.shared.generateDailyTasks(
                for: userData.goals,
                day: currentDay,
                previousTasks: previousTasks,
                wakeTime: userData.formattedWakeTime,
                sleepTime: userData.formattedSleepTime
            ) { result in
                if let tasksJSON = result {
                    do {
                        let decoder = JSONDecoder()
                        let data = tasksJSON.data(using: .utf8)!
                        let response = try decoder.decode(DailyTasksResponse.self, from: data)
                        
                        Task { @MainActor in
                            let tasks = response.dailyTasks.flatMap { goalTasks in
                                goalTasks.tasks.compactMap { task in
                                    if let scheduledTime = DailyTask.parseTime(task.time) {
                                        return DailyTask(
                                            goalTitle: goalTasks.goalTitle,
                                            task: task.description,
                                            scheduledTime: scheduledTime,
                                            emoji: task.emoji
                                        )
                                    }
                                    return nil
                                }
                            }
                            self.dailyTasks = tasks
                            self.userData.addDailyHistory(day: currentDay, tasks: tasks)
                            
                            // Generate daily summary after tasks are created
                            await self.generateDailySummary(previousCompletion: previousCompletion)
                        }
                    } catch {
                        print("Failed to decode daily tasks:", error)
                    }
                }
                continuation.resume()
            }
        }
    }
    
    private func generateDailySummary(previousCompletion: Double? = nil) async {
        guard let currentDay = userData.currentDay else { return }
        
        return await withCheckedContinuation { continuation in
            OpenAIService.shared.generateDailySummary(
                day: currentDay,
                totalDays: userData.planDuration,
                name: userData.name,
                goals: userData.goals,
                previousDayCompletion: previousCompletion
            ) { summary in
                Task { @MainActor in
                    if let summary = summary {
                        self.dailySummary = summary
                        if var lastHistory = self.userData.dailyTaskHistory.last {
                            lastHistory.summary = summary
                            self.userData.dailyTaskHistory[self.userData.dailyTaskHistory.count - 1] = lastHistory
                        }
                    }
                }
                continuation.resume()
            }
        }
    }
    
    func toggleTask(_ task: DailyTask) {
        if let index = dailyTasks.firstIndex(where: { $0.id == task.id }) {
            var updatedTask = dailyTasks[index]
            updatedTask.isCompleted.toggle()
            if updatedTask.isCompleted {
                updatedTask.completedAt = Date()
            } else {
                updatedTask.completedAt = nil
            }
            dailyTasks[index] = updatedTask
            userData.updateLastDayTasks(dailyTasks)
            saveUserData()
        }
    }
    
    private func completeDay() {
        userData.lastCompletedDay = userData.currentDay
        userData.updateLastDayTasks(dailyTasks)
        saveUserData()
    }
    
    func getTasksForDate(_ date: Date) -> [DailyTask] {
        userData.dailyTaskHistory
            .first { Calendar.current.isDate($0.date, inSameDayAs: date) }?
            .tasks ?? []
    }
    
    func resetPlan() {
        userData.planStartDate = nil
        userData.lastCompletedDay = nil
        userData.goals = []
        userData.dailyTaskHistory = []
        dailyTasks = []
        currentScreen = .welcome
        saveUserData()
    }
    
    func updateSubPlan(for goal: Goal, oldPlan: String, newPlan: String) {
        if let index = userData.goals.firstIndex(where: { $0.id == goal.id }) {
            if let planIndex = userData.goals[index].subPlans.firstIndex(of: oldPlan) {
                userData.goals[index].subPlans[planIndex] = newPlan
                saveUserData()
            }
        }
    }
}

// Response models for OpenAI
struct PlanResponse: Codable {
    struct GeneratedGoal: Codable {
        let title: String
        let strategy: String
        let subPlans: [String]
    }
    
    let goals: [GeneratedGoal]
}

struct DailyTasksResponse: Codable {
    struct GoalTasks: Codable {
        let goalTitle: String
        let tasks: [TaskWithTime]
    }
    
    struct TaskWithTime: Codable {
        let description: String
        let time: String
        let emoji: String
    }
    
    let dailyTasks: [GoalTasks]
} 
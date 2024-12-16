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
    @Published var isGeneratingPlan = false
    @Published var dailyTasks: [DailyTask] = []
    @Published var showingHistory = false
    @Published var showingPlanOverview = false
    @Published var dailySummary: String = ""
    @Published var showConfetti: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let userDataKey = "userData"
    private var taskRefreshTimer: Timer?
    
    var taskHistory: [TaskHistory] {
        return userData.dailyTaskHistory.map { history in
            TaskHistory(date: history.date, tasks: history.tasks)
        }
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
            
            // Check if we have a valid active plan using UserDefaultsHelper
            if UserDefaultsHelper.shared.hasActivePlan() {
                print("Found active plan - Starting in daily checklist")
                self.currentScreen = .dailyChecklist
                // Generate daily tasks if needed
                Task {
                    await self.generateDailyTasksIfNeeded()
                }
            } else {
                print("No active plan found - Starting in welcome")
                self.currentScreen = .welcome
            }
        } else {
            print("No saved data found - Starting fresh")
            self.userData = UserData()
            self.currentScreen = .welcome
        }
        
        // Start timer to refresh visible tasks
        startTaskRefreshTimer()
        
        // Check subscription status
        Task {
            await StoreKitManager.shared.updateSubscriptionStatus()
            
            // Only redirect to welcome if there's no active plan AND user is not subscribed
            await MainActor.run {
                if !StoreKitManager.shared.isSubscribed && !UserDefaultsHelper.shared.hasActivePlan() {
                    self.currentScreen = .welcome
                }
            }
        }
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
        dailyTasks
            .filter { !$0.isCompleted }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }
    
    var completedTasks: [DailyTask] {
        dailyTasks
            .filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? Date()) > ($1.completedAt ?? Date()) }
    }
    
    var upcomingTasks: [DailyTask] {
        []  // No longer needed since we show all tasks at once
    }
    
    enum Screen {
        case welcome
        case goalSelection
        case durationSelection
        case subscriptions
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
            // If this is a plan reset (we have a name and subscription), go straight to plan creation
            if userData.name != nil && StoreKitManager.shared.isSubscribed {
                currentScreen = .planCreation
                isGeneratingPlan = true
                Task {
                    do {
                        _ = try await generatePlan()
                        await MainActor.run {
                            isGeneratingPlan = false
                        }
                    } catch {
                        print("Error generating plan:", error)
                        await MainActor.run {
                            isGeneratingPlan = false
                        }
                    }
                }
            } else {
                currentScreen = .subscriptions
            }
        case .subscriptions:
            currentScreen = .planCreation
            isGeneratingPlan = true
            Task {
                do {
                    _ = try await generatePlan()
                    await MainActor.run {
                        isGeneratingPlan = false
                    }
                } catch {
                    print("Error generating plan:", error)
                    await MainActor.run {
                        isGeneratingPlan = false
                    }
                }
            }
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
        print("Saving user data...")
        print("Plan start date: \(String(describing: userData.planStartDate))")
        print("Goals count: \(userData.goals.count)")
        print("Current day: \(String(describing: userData.currentDay))")
        print("Plan duration: \(userData.planDuration)")
        
        if let encoded = try? JSONEncoder().encode(userData) {
            userDefaults.set(encoded, forKey: userDataKey)
            userDefaults.synchronize() // Force immediate save
            
            // Also save to UserDefaultsHelper for consistency
            UserDefaultsHelper.shared.saveUserData(userData)
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
                            // Normalize titles for comparison
                            let normalizedUserTitle = updatedGoals[i].title.lowercased().trimmingCharacters(in: .whitespaces)
                            
                            if let generatedGoal = response.goals.first(where: { 
                                let normalizedGeneratedTitle = $0.title.lowercased().trimmingCharacters(in: .whitespaces)
                                return normalizedUserTitle == normalizedGeneratedTitle || 
                                      normalizedGeneratedTitle.contains(normalizedUserTitle) ||
                                      normalizedUserTitle.contains(normalizedGeneratedTitle)
                            }) {
                                // First set the strategy
                                updatedGoals[i].strategy = generatedGoal.strategy
                                
                                // Set both subPlans and generatedPlan to the initial generated plans
                                let initialPlans = generatedGoal.subPlans
                                updatedGoals[i].subPlans = initialPlans
                                updatedGoals[i].generatedPlan = initialPlans
                                
                                print("Set generated plan for goal '\(updatedGoals[i].title)': \(initialPlans)")
                            }
                        }
                        
                        print("Updated goals with strategies and sub-plans:", updatedGoals)
                        
                        // Update userData with the new goals and start date
                        Task { @MainActor in
                            print("Updating userData goals")
                            self.userData.goals = updatedGoals
                            self.userData.planStartDate = Date()
                            self.userData.lastCompletedDay = nil
                            self.userData.dailyTaskHistory = []
                            
                            // Force an immediate save after plan generation
                            self.saveUserData()
                            
                            print("userData after plan generation:")
                            print("- Goals count: \(self.userData.goals.count)")
                            print("- Plan start date: \(String(describing: self.userData.planStartDate))")
                            print("- Plan duration: \(self.userData.planDuration)")
                            
                            // Only resume continuation after userData is updated and saved
                            continuation.resume(returning: self.userData.goals)
                        }
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
                                goalTasks.tasks.map { task in
                                    DailyTask(
                                        goalTitle: goalTasks.goalTitle,
                                        task: task.description,
                                        emoji: task.emoji,
                                        intensity: DailyTask.TaskIntensity.forDay(currentDay, totalDays: self.userData.planDuration)
                                    )
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
                            
                            // Remove the generation of blank additional tasks
                            // We'll only use the AI-generated tasks that are relevant to goals
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
            
            // Update the task history
            userData.updateLastDayTasks(dailyTasks)
            saveUserData()
            
            // Trigger UI update
            objectWillChange.send()
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
    
    func handlePlanReset() {
        print("Starting plan reset process...")
        // First ensure we're on the main thread
        DispatchQueue.main.async {
            // Close the sheet first
            self.showingPlanOverview = false
            
            // Wait for the sheet to close
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("Sheet closed, resetting plan-specific data...")
                // Reset only plan-related data, keeping user preferences and subscription info
                self.userData.planStartDate = nil
                self.userData.lastCompletedDay = nil
                self.userData.goals = []
                self.userData.dailyTaskHistory = []
                self.userData.planDuration = 0
                self.dailyTasks = []
                
                // Save changes
                self.saveUserData()
                
                print("Data reset, starting new plan flow...")
                // Navigate to goal selection, the moveToNextScreen function will handle
                // the proper navigation through duration selection, plan creation, and back to daily checklist
                withAnimation(.easeInOut) {
                    self.currentScreen = .goalSelection
                }
            }
        }
    }
    
    func resetPlan() {
        handlePlanReset()
    }
    
    func updateSubPlan(for goal: Goal, oldPlan: String, newPlan: String) {
        if let index = userData.goals.firstIndex(where: { $0.id == goal.id }) {
            if let planIndex = userData.goals[index].subPlans.firstIndex(of: oldPlan) {
                userData.goals[index].subPlans[planIndex] = newPlan
                saveUserData()
            }
        }
    }
    
    func updateTaskCompletion(_ updatedTask: DailyTask) {
        if let index = dailyTasks.firstIndex(where: { $0.id == updatedTask.id }) {
            dailyTasks[index] = updatedTask
            
            // Update the task history
            userData.updateLastDayTasks(dailyTasks)
            saveUserData()
            
            // Trigger UI update
            objectWillChange.send()
        }
    }
    
    func triggerConfetti() {
        showConfetti = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.showConfetti = false
        }
    }
    
    func updateTaskNotes(_ task: DailyTask, notes: String) {
        if let index = dailyTasks.firstIndex(where: { $0.id == task.id }) {
            dailyTasks[index].notes = notes
            // Update the task in history if it exists
            if let historyIndex = userData.dailyTaskHistory.lastIndex(where: { history in
                history.tasks.contains(where: { $0.id == task.id })
            }) {
                if let taskIndex = userData.dailyTaskHistory[historyIndex].tasks.firstIndex(where: { $0.id == task.id }) {
                    userData.dailyTaskHistory[historyIndex].tasks[taskIndex].notes = notes
                }
            }
            // Save the updated user data
            UserDefaultsHelper.shared.saveUserData(userData)
        }
    }
}

// Response models for OpenAI
struct DailyTasksResponse: Codable {
    struct GoalTasks: Codable {
        let goalTitle: String
        let tasks: [TaskItem]
    }
    
    struct TaskItem: Codable {
        let description: String
        let emoji: String
    }
    
    let dailyTasks: [GoalTasks]
} 
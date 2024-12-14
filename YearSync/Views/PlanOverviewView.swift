import SwiftUI

// MARK: - Progress Card Component
struct ProgressCardView: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.appTextSecondary)
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.appText)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Progress Overview Component
struct ProgressOverviewView: View {
    let currentDay: Int?
    let planDuration: Int
    let completedTasks: Int
    let totalTasks: Int
    let progressPercentage: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Plan Progress")
                .font(.custom("Baskerville-Bold", size: 24))
                .foregroundColor(.appText)
            
            HStack(spacing: 24) {
                ProgressCardView(
                    title: "Day",
                    value: "\(currentDay ?? 0)/\(planDuration)",
                    subtitle: "of your journey"
                )
                
                ProgressCardView(
                    title: "Tasks",
                    value: "\(completedTasks)/\(totalTasks)",
                    subtitle: "completed"
                )
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(UIColor.systemGray6))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black)
                            .frame(width: geometry.size.width * progressPercentage,
                                   height: 12)
                    }
                }
                .frame(height: 12)
            }
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Performance Insights Component
struct PerformanceInsightsView: View {
    let insights: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Insights")
                .font(.custom("Baskerville-Bold", size: 24))
                .foregroundColor(.appText)
            
            ForEach(insights, id: \.self) { insight in
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.appAccent)
                    Text(insight)
                        .font(.system(size: 17))
                        .foregroundColor(.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Goals List Component
struct GoalsListView: View {
    let goals: [Goal]
    let getTaskHistory: (String) -> [DailyTask]
    let onEditGoal: (Goal) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Goals")
                .font(.custom("Baskerville-Bold", size: 24))
                .foregroundColor(.appText)
            
            ForEach(goals) { goal in
                Button(action: { onEditGoal(goal) }) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(goal.title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.appText)
                            Text(goal.emoji)
                                .font(.system(size: 17))
                            Spacer()
                            Image(systemName: "pencil")
                                .foregroundColor(.appAccent)
                        }
                        
                        let goalTasks = getTaskHistory(goal.title)
                        let completedCount = goalTasks.filter { $0.isCompleted }.count
                        let totalCount = goalTasks.count
                        
                        if totalCount > 0 {
                            Text("\(completedCount) of \(totalCount) tasks completed")
                                .font(.system(size: 15))
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Main View
struct PlanOverviewView: View {
    @Binding var userData: UserData
    @Environment(\.dismiss) var dismiss
    @State private var showingResetAlert = false
    @State private var selectedGoalForEdit: Goal?
    @State private var showingEditGoal = false
    
    private var completedTasksCount: Int {
        userData.dailyTaskHistory.flatMap { $0.tasks }.filter { $0.isCompleted }.count
    }
    
    private var totalTasksCount: Int {
        userData.dailyTaskHistory.flatMap { $0.tasks }.count
    }
    
    private var progressPercentage: CGFloat {
        guard let currentDay = userData.currentDay else { return 0 }
        return CGFloat(currentDay) / CGFloat(userData.planDuration)
    }
    
    private var performanceInsights: [String] {
        var insights: [String] = []
        
        // Daily Task Completion Rate
        if !userData.dailyTaskHistory.isEmpty {
            let totalDays = userData.dailyTaskHistory.count
            let daysWithFullCompletion = userData.dailyTaskHistory.filter { history in
                !history.tasks.isEmpty && history.tasks.allSatisfy { $0.isCompleted }
            }.count
            
            let completionRate = Double(daysWithFullCompletion) / Double(totalDays)
            
            // Format the completion rate as a percentage
            let percentage = Int(completionRate * 100)
            
            if totalDays >= 3 {
                if completionRate >= 0.8 {
                    insights.append("You're crushing it! Completed all daily tasks \(percentage)% of the time")
                } else if completionRate >= 0.5 {
                    insights.append("You complete all daily tasks \(percentage)% of the time - keep pushing!")
                } else {
                    insights.append("You complete all daily tasks \(percentage)% of the time - try breaking tasks into smaller steps")
                }
                
                // Trend Analysis
                let recentDays = min(3, userData.dailyTaskHistory.count)
                let recentCompletionRate = userData.dailyTaskHistory.suffix(recentDays).map { history in
                    Double(history.tasks.filter { $0.isCompleted }.count) / Double(max(1, history.tasks.count))
                }.reduce(0, +) / Double(recentDays)
                
                let isImproving = recentCompletionRate > completionRate
                if isImproving {
                    insights.append("You're trending upward - recent completion rates are higher than your average")
                } else if recentCompletionRate < completionRate * 0.8 {
                    insights.append("You're falling a bit behind your usual pace - let's get back on track!")
                }
            }
        }
        
        // Journal Entry Analysis
        let journalEntries = userData.journalEntries
        if !journalEntries.isEmpty {
            let totalEntries = journalEntries.count
            
            // Recent entries (last 7 days)
            let calendar = Calendar.current
            let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
            let recentEntries = journalEntries.filter { $0.date > oneWeekAgo }.count
            
            if recentEntries > 0 {
                insights.append("You've written \(recentEntries) journal entries this week")
            }
            
            if totalEntries > recentEntries {
                insights.append("Total of \(totalEntries) entries in your journal")
            }
        } else {
            insights.append("Start journaling to track your thoughts and progress")
        }
        
        // Plan Progress
        if let currentDay = userData.currentDay {
            let progressPercentage = Int((Double(currentDay) / Double(userData.planDuration)) * 100)
            if progressPercentage > 0 {
                insights.append("\(progressPercentage)% through your \(userData.planDuration)-day journey")
            }
        }
        
        // Default insight if none generated
        if insights.isEmpty {
            insights.append("Complete tasks and journal entries to see your performance insights")
        }
        
        return Array(insights.prefix(5))
    }
    
    private func resetPlan() {
        var updatedUserData = userData
        updatedUserData.resetPlan()
        userData = updatedUserData
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    ProgressOverviewView(
                        currentDay: userData.currentDay,
                        planDuration: userData.planDuration,
                        completedTasks: completedTasksCount,
                        totalTasks: totalTasksCount,
                        progressPercentage: progressPercentage
                    )
                    
                    PerformanceInsightsView(insights: performanceInsights)
                    
                    GoalsListView(
                        goals: userData.goals,
                        getTaskHistory: { userData.getTaskHistory(for: $0) },
                        onEditGoal: { goal in
                            selectedGoalForEdit = goal
                            showingEditGoal = true
                        }
                    )
                    
                    Button(action: { showingResetAlert = true }) {
                        Text("Reset Plan")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(25)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 24)
            }
            .navigationTitle("Plan Overview")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Reset Plan", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetPlan()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to reset your plan? This will delete all your progress.")
            }
            .sheet(isPresented: $showingEditGoal) {
                if let goal = selectedGoalForEdit {
                    EditGoalView(userData: $userData, goal: goal)
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

struct EditGoalView: View {
    @Binding var userData: UserData
    let goal: Goal
    @Environment(\.dismiss) var dismiss
    @State private var editedPlans: [String]
    @State private var showingDeleteAlert = false
    @State private var editingPlanIndex: Int?
    @State private var editedPlanText: String = ""
    @State private var isAnimating = false
    
    init(userData: Binding<UserData>, goal: Goal) {
        self._userData = userData
        self.goal = goal
        self._editedPlans = State(initialValue: goal.subPlans)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(goal.emoji)
                                .font(.system(size: 34))
                            Text(goal.title)
                                .font(.custom("Baskerville-Bold", size: 34))
                                .foregroundColor(.appText)
                        }
                        Text("Edit your plan to better align with your progress and goals")
                            .font(.system(size: 17))
                            .foregroundColor(.appTextSecondary)
                    }
                    .padding(.horizontal)
                    
                    // Plan Items
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(editedPlans.enumerated()), id: \.element) { index, plan in
                            if editingPlanIndex == index {
                                // Edit Mode
                                VStack(alignment: .leading, spacing: 12) {
                                    TextEditor(text: $editedPlanText)
                                        .font(.system(size: 17))
                                        .foregroundColor(.appText)
                                        .frame(minHeight: 100)
                                        .padding(8)
                                        .background(Color(UIColor.systemGray6))
                                        .scrollContentBackground(.hidden)
                                        .cornerRadius(8)
                                        .opacity(isAnimating ? 1 : 0)
                                        .onAppear {
                                            withAnimation(.easeIn(duration: 0.2)) {
                                                isAnimating = true
                                            }
                                        }
                                    
                                    HStack {
                                        Spacer()
                                        Button("Cancel") {
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                isAnimating = false
                                                editingPlanIndex = nil
                                            }
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                        .foregroundColor(.appTextSecondary)
                                        .padding(.trailing, 16)
                                        
                                        Button("Save") {
                                            if !editedPlanText.isEmpty {
                                                withAnimation(.easeOut(duration: 0.2)) {
                                                    editedPlans[index] = editedPlanText
                                                    isAnimating = false
                                                    editingPlanIndex = nil
                                                }
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            }
                                        }
                                        .foregroundColor(.appAccent)
                                    }
                                }
                                .padding(16)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                            } else {
                                // View Mode
                                HStack(alignment: .top) {
                                    Text("\(index + 1).")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.appTextSecondary)
                                        .frame(width: 30, alignment: .leading)
                                    
                                    Text(plan)
                                        .font(.system(size: 17))
                                        .foregroundColor(.appText)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        editedPlanText = plan
                                        isAnimating = false
                                        editingPlanIndex = index
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.appAccent)
                                    }
                                }
                                .padding(16)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                                .transition(.opacity)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.2), value: editingPlanIndex)
                    
                    // Save Button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        saveChanges()
                        dismiss()
                    }) {
                        Text("Save Changes")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.black)
                            .cornerRadius(25)
                    }
                    .padding(.horizontal)
                    
                    // Delete Button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Goal")
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(25)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Delete Goal", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteGoal()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this goal? This action cannot be undone.")
            }
        }
        .preferredColorScheme(.light)
    }
    
    private func saveChanges() {
        if let index = userData.goals.firstIndex(where: { $0.id == goal.id }) {
            var updatedGoal = goal
            updatedGoal.subPlans = editedPlans
            userData.goals[index] = updatedGoal
        }
    }
    
    private func deleteGoal() {
        userData.goals.removeAll { $0.id == goal.id }
    }
} 
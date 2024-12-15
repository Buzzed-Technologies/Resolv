import SwiftUI

// MARK: - Progress Item Component
struct ProgressItemView: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("PlayfairDisplay-Regular", size: 14))
                .foregroundColor(.secondary)
            Text(value)
                .font(.custom("PlayfairDisplay-SemiBold", size: 28))
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.custom("PlayfairDisplay-Regular", size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        VStack(alignment: .leading, spacing: 24) {
            Text("Plan Progress")
                .font(.custom("PlayfairDisplay-Regular", size: 28))
                .foregroundColor(.primary)
            
            HStack(spacing: 24) {
                ProgressItemView(
                    title: "Day",
                    value: "\(currentDay ?? 0)/\(planDuration)",
                    subtitle: "of your journey"
                )
                
                Divider()
                    .frame(height: 50)
                
                ProgressItemView(
                    title: "Tasks",
                    value: "\(completedTasks)/\(totalTasks)",
                    subtitle: "completed"
                )
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemGray6))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: geometry.size.width * progressPercentage,
                                   height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Performance Insights Component
struct PerformanceInsightsView: View {
    let insights: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Insights")
                .font(.custom("PlayfairDisplay-Regular", size: 28))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(insights, id: \.self) { insight in
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                        Text(insight)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.vertical, 16)
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
                .font(.custom("PlayfairDisplay-Regular", size: 28))
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                ForEach(goals) { goal in
                    Button(action: { onEditGoal(goal) }) {
                        HStack(spacing: 12) {
                            Text(goal.emoji)
                                .font(.system(size: 24))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(goal.title)
                                    .font(.custom("PlayfairDisplay-SemiBold", size: 17))
                                    .foregroundColor(.primary)
                                
                                let goalTasks = getTaskHistory(goal.title)
                                let completedCount = goalTasks.filter { $0.isCompleted }.count
                                let totalCount = goalTasks.count
                                
                                if totalCount > 0 {
                                    Text("\(completedCount) of \(totalCount) tasks completed")
                                        .font(.custom("PlayfairDisplay-Regular", size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.green)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.vertical, 16)
                    }
                    
                    if goal.id != goals.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Main View
struct PlanOverviewView: View {
    @Binding var userData: UserData
    @Environment(\.dismiss) var dismiss
    @State private var showingResetAlert = false
    @State private var showingPersonalDetails = false
    @State private var showingPastChallenges = false
    @State private var summaryText: String = "Loading..."
    
    private var progressPercentage: Double {
        guard let currentDay = userData.currentDay else { return 0 }
        return Double(currentDay) / Double(userData.planDuration)
    }
    
    private var targetDate: String {
        guard let startDate = userData.planStartDate else { return "" }
        let targetDate = Calendar.current.date(byAdding: .day, value: userData.planDuration, to: startDate)!
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: targetDate) + "rd"
    }
    
    private func loadDailySummary() {
        guard let currentDay = userData.currentDay else {
            summaryText = ""
            return
        }
        
        // Calculate previous day completion rate
        let previousDayCompletion: Double? = {
            guard let lastDayTasks = userData.dailyTaskHistory.last?.tasks else { return nil }
            let completedCount = lastDayTasks.filter { $0.isCompleted }.count
            return Double(completedCount) / Double(lastDayTasks.count)
        }()
        
        // Generate summary using OpenAI service
        OpenAIService.shared.generateDailySummary(
            day: currentDay,
            totalDays: userData.planDuration,
            name: userData.name,
            goals: userData.goals,
            previousDayCompletion: previousDayCompletion
        ) { summary in
            DispatchQueue.main.async {
                if let summary = summary {
                    self.summaryText = summary
                } else {
                    self.summaryText = "Unable to generate summary"
                }
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Current Plan Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Plan")
                        .font(.custom("PlayfairDisplay-Regular", size: 34))
                        .foregroundColor(.primary)
                    
                    Text("Target: \(targetDate)")
                        .font(.custom("PlayfairDisplay-Regular", size: 17))
                        .foregroundColor(.primary)
                    
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color(UIColor.systemGray6))
                                .frame(height: 8)
                                .cornerRadius(4)
                            
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: geometry.size.width * progressPercentage, height: 8)
                                .cornerRadius(4)
                        }
                    }
                    .frame(height: 8)
                    .padding(.vertical, 16)
                    
                    Text(summaryText)
                        .font(.custom("PlayfairDisplay-Regular", size: 17))
                        .foregroundColor(.primary)
                        .padding(.bottom, 24)
                        .onAppear {
                            loadDailySummary()
                        }
                }
                .padding(.horizontal, 24)
                
                Divider()
                
                // Menu Items
                VStack(spacing: 0) {
                    Button(action: { showingPastChallenges = true }) {
                        MenuRowView(
                            title: "Past Challenges",
                            subtitle: "When you complete one of your plans and reach a goal, they'll be listed here!",
                            subtitleAlignment: .leading
                        )
                    }
                    
                    Divider()
                    
                    Button(action: { showingPersonalDetails = true }) {
                        MenuRowView(
                            title: "Personal Details"
                        )
                    }
                    
                    Divider()
                    
                    Button(action: { showingResetAlert = true }) {
                        MenuRowView(
                            title: "Start from Scratch",
                            subtitle: "Goals changed? Want to start over?"
                        )
                    }
                    
                    Divider()
                }
                
                // Footer Links
                VStack(spacing: 16) {
                    Button("Privacy Policy") {
                        // Handle privacy policy action
                    }
                    .font(.custom("PlayfairDisplay-Regular", size: 17))
                    .foregroundColor(.secondary)
                    
                    Button("Terms & Conditions") {
                        // Handle terms action
                    }
                    .font(.custom("PlayfairDisplay-Regular", size: 17))
                    .foregroundColor(.secondary)
                    
                    Text("Made with ❤️ by the Resolv team")
                        .font(.custom("PlayfairDisplay-Regular", size: 15))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .padding(.vertical, 32)
            }
            .padding(.top, 24)
        }
        .alert("Reset Plan", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                archiveCurrentPlan()
                userData.resetPlan()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to reset your plan? Your current progress will be archived in Past Challenges.")
        }
        .sheet(isPresented: $showingPersonalDetails) {
            PersonalDetailsView(userData: $userData)
        }
        .sheet(isPresented: $showingPastChallenges) {
            PastChallengesView()
        }
    }
    
    private func archiveCurrentPlan() {
        // The archiving is now handled in userData.resetPlan()
        // which creates and stores a PastChallenge before clearing the current plan
    }
}

struct MenuRowView: View {
    let title: String
    var subtitle: String? = nil
    var subtitleAlignment: HorizontalAlignment = .center
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("PlayfairDisplay-Regular", size: 28))
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.custom("PlayfairDisplay-Regular", size: 17))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 24)
            
            Image(systemName: "chevron.right")
                .foregroundColor(.green)
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 32)
        }
        .padding(.horizontal, 24)
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
                                .font(.custom("PlayfairDisplay-Bold", size: 34))
                                .foregroundColor(.appText)
                        }
                        Text("Edit your plan to better align with your progress and goals")
                            .font(.custom("PlayfairDisplay-Regular", size: 17))
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
                                        .font(.custom("PlayfairDisplay-Regular", size: 17))
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
                                        .font(.custom("PlayfairDisplay-SemiBold", size: 17))
                                        .foregroundColor(.appTextSecondary)
                                        .frame(width: 30, alignment: .leading)
                                    
                                    Text(plan)
                                        .font(.custom("PlayfairDisplay-Regular", size: 17))
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
                    ModernButton(title: "Save Changes") {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        saveChanges()
                        dismiss()
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
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            ZStack {
                                // Deep layer (darkest)
                                Capsule()
                                    .fill(Color.red.opacity(0.8))
                                    .offset(y: 6)
                                
                                // Middle layer
                                Capsule()
                                    .fill(Color.red.opacity(0.9))
                                    .offset(y: 3)
                                
                                // Top layer
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.red.opacity(0.7),
                                                Color.red
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                
                                // Glossy overlay
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.25),
                                                Color.clear
                                            ]),
                                            startPoint: .top,
                                            endPoint: .center
                                        )
                                    )
                                    .padding(2)
                            }
                        )
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

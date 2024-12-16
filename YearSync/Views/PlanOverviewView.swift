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
    @State private var summaryText: String = ""
    @State private var isLoadingSummary: Bool = true
    @State private var summaryOpacity: Double = 0
    @State private var loadingDots = ""
    @State private var loadingTimer: Timer?
    
    // Add cache-related properties
    private let cacheKey = "dailySummaryCacheKey"
    private let cacheDuration: TimeInterval = 10800 // 3 hours in seconds
    
    private var progressPercentage: Double {
        guard let currentDay = userData.currentDay else { return 0 }
        return Double(currentDay) / Double(userData.planDuration)
    }
    
    private var targetDate: String {
        guard let startDate = userData.planStartDate else { return "" }
        let targetDate = Calendar.current.date(byAdding: .day, value: userData.planDuration, to: startDate)!
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        let day = Calendar.current.component(.day, from: targetDate)
        
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        
        return formatter.string(from: targetDate) + suffix
    }
    
    private func loadDailySummary() {
        guard let currentDay = userData.currentDay else {
            summaryText = ""
            isLoadingSummary = false
            return
        }
        
        // Check cache first
        if let cachedSummary = getCachedSummary() {
            withAnimation {
                self.isLoadingSummary = false
                self.summaryText = cachedSummary
                withAnimation(.easeIn(duration: 0.5)) {
                    self.summaryOpacity = 1
                }
            }
            return
        }
        
        let previousDayCompletion: Double? = {
            guard let lastDayTasks = userData.dailyTaskHistory.last?.tasks else { return nil }
            let completedCount = lastDayTasks.filter { $0.isCompleted }.count
            return Double(completedCount) / Double(lastDayTasks.count)
        }()
        
        OpenAIService.shared.generateDailySummary(
            day: currentDay,
            totalDays: userData.planDuration,
            name: userData.name,
            goals: userData.goals,
            previousDayCompletion: previousDayCompletion
        ) { summary in
            DispatchQueue.main.async {
                if let summary = summary {
                    withAnimation {
                        self.isLoadingSummary = false
                    }
                    self.summaryText = summary
                    self.cacheSummary(summary)
                    
                    withAnimation(.easeIn(duration: 0.5)) {
                        self.summaryOpacity = 1
                    }
                } else {
                    withAnimation {
                        self.isLoadingSummary = false
                    }
                    self.summaryText = "Unable to generate summary"
                    self.summaryOpacity = 1
                }
            }
        }
    }
    
    // Add caching methods
    private func cacheSummary(_ summary: String) {
        let cache = [
            "summary": summary,
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        UserDefaults.standard.set(cache, forKey: cacheKey)
    }
    
    private func getCachedSummary() -> String? {
        guard let cache = UserDefaults.standard.dictionary(forKey: cacheKey),
              let summary = cache["summary"] as? String,
              let timestamp = cache["timestamp"] as? TimeInterval else {
            return nil
        }
        
        let age = Date().timeIntervalSince1970 - timestamp
        return age < cacheDuration ? summary : nil
    }
    
    private func startLoadingAnimation() {
        loadingDots = ""
        loadingTimer?.invalidate()
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation {
                if loadingDots.count < 3 {
                    loadingDots += "."
                } else {
                    loadingDots = ""
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
                    
                    // Improved Summary Section
                    VStack(alignment: .leading, spacing: 8) {
                        if isLoadingSummary {
                            Text("Analyzing your progress\(loadingDots)")
                                .font(.custom("PlayfairDisplay-Regular", size: 17))
                                .foregroundColor(.secondary)
                                .opacity(0.8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .onAppear {
                                    startLoadingAnimation()
                                }
                                .onDisappear {
                                    loadingTimer?.invalidate()
                                    loadingTimer = nil
                                }
                        } else {
                            Text(summaryText)
                                .font(.custom("PlayfairDisplay-Regular", size: 17))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .opacity(summaryOpacity)
                                .animation(.easeIn(duration: 0.5), value: summaryOpacity)
                        }
                    }
                    .padding(.bottom, 24)
                    .onAppear {
                        isLoadingSummary = true
                        summaryOpacity = 0
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
                            title: "Personal Details",
                            subtitle: "Update your profile, preferences, and personal goals",
                            subtitleAlignment: .leading
                        )
                    }
                    
                    Divider()
                    
                    Button(action: { showingResetAlert = true }) {
                        MenuRowView(
                            title: "Start from Scratch",
                            subtitle: "Goals changed? Want to start over? Reset your journey here",
                            subtitleAlignment: .leading
                        )
                    }
                    
                    Divider()
                }
                
                // Footer Links
                VStack(spacing: 16) {
                    Button("Privacy Policy") {
                        // Handle privacy policy action
                    }
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    
                    Button("Terms & Conditions") {
                        // Handle terms action
                    }
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    
                    VStack(spacing: 4) {
                        Text("Made with ❤️ by the Resolv team")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                        
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                            Text("Version \(version) (\(build))")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .opacity(0.7)
                        }
                    }
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
    @State private var showingDeleteAlert = false
    @State private var editedStrategy: String
    @State private var isEditing = false
    @State private var isAnimating = false
    
    init(userData: Binding<UserData>, goal: Goal) {
        self._userData = userData
        self.goal = goal
        self._editedStrategy = State(initialValue: goal.strategy)
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
                        Text("Review and edit your goal strategy")
                            .font(.custom("PlayfairDisplay-Regular", size: 17))
                            .foregroundColor(.appTextSecondary)
                    }
                    .padding(.horizontal)
                    
                    // Strategy Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Strategy")
                                .font(.custom("PlayfairDisplay-Regular", size: 24))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if !isEditing {
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        isEditing = true
                                    }
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.appAccent)
                                }
                            }
                        }
                        
                        if isEditing {
                            VStack(spacing: 16) {
                                TextEditor(text: $editedStrategy)
                                    .font(.custom("PlayfairDisplay-Regular", size: 17))
                                    .foregroundColor(.appText)
                                    .frame(minHeight: 300)
                                    .padding(16)
                                    .background(Color(UIColor.systemGray6))
                                    .scrollContentBackground(.hidden)
                                    .cornerRadius(12)
                                    .opacity(isAnimating ? 1 : 0)
                                    .onAppear {
                                        withAnimation(.easeIn(duration: 0.2)) {
                                            isAnimating = true
                                        }
                                    }
                                
                                HStack {
                                    Spacer()
                                    Button("Cancel") {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            isEditing = false
                                            editedStrategy = goal.strategy
                                        }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                    .foregroundColor(.appTextSecondary)
                                    .padding(.trailing, 16)
                                    
                                    Button("Save") {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            isEditing = false
                                            saveChanges()
                                        }
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }
                                    .foregroundColor(.appAccent)
                                }
                                .font(.system(size: 17, weight: .medium))
                            }
                        } else {
                            Text(editedStrategy)
                                .font(.custom("PlayfairDisplay-Regular", size: 17))
                                .foregroundColor(.appTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
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
            updatedGoal.strategy = editedStrategy
            userData.goals[index] = updatedGoal
        }
    }
    
    private func deleteGoal() {
        userData.goals.removeAll { $0.id == goal.id }
    }
} 

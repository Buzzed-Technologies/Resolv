import SwiftUI

struct JournalView: View {
    @Binding var userData: UserData
    @State private var journalText = ""
    @State private var showingWeeklySummary = false
    @State private var selectedTab = 0
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Segmented Control
                    HStack(spacing: 0) {
                        ForEach(["Current Week", "Past Entries"], id: \.self) { tab in
                            Button(action: {
                                withAnimation {
                                    selectedTab = tab == "Current Week" ? 0 : 1
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }) {
                                VStack(spacing: 8) {
                                    Text(tab)
                                        .font(.system(size: 17))
                                        .foregroundColor(selectedTab == (tab == "Current Week" ? 0 : 1) ? .appText : .appTextSecondary)
                                    
                                    Rectangle()
                                        .fill(selectedTab == (tab == "Current Week" ? 0 : 1) ? Color.appAccent : Color.clear)
                                        .frame(height: 2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
                    
                    if selectedTab == 0 {
                        currentWeekView
                    } else {
                        pastEntriesView
                    }
                }
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingWeeklySummary) {
                WeeklySummaryView(summary: userData.weeklySummaries.last ?? WeeklySummary(weekStartDate: Date(), weekEndDate: Date()))
            }
            .onReceive(NotificationCenter.default.publisher(for: .weeklyJournalAnalysisCompleted)) { notification in
                if let summary = notification.userInfo?["summary"] as? WeeklySummary,
                   let indices = notification.userInfo?["indices"] as? [Int] {
                    userData.applyWeeklySummary(summary, entryIndices: indices)
                    showingWeeklySummary = true
                }
            }
        }
        .preferredColorScheme(.light)
    }
    
    private var currentWeekView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Journal Entry Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("How was your day?")
                        .font(.custom("PlayfairDisplay-Regular", size: 24))
                        .foregroundColor(.appText)
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $journalText)
                            .font(.system(size: 17))
                            .foregroundColor(.appText)
                            .frame(height: 150)
                            .scrollContentBackground(.hidden)
                            .background(Color(UIColor.systemGray6))
                        
                        if journalText.isEmpty {
                            Text("Write about your day, challenges, victories, or anything else on your mind...")
                                .font(.system(size: 17))
                                .foregroundColor(.appTextSecondary.opacity(0.7))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    ModernButton(title: "Save Entry") {
                        saveJournalEntry()
                    }
                }
                .padding(.horizontal)
                
                // Today's Completed Tasks Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Today's Completed Tasks")
                        .font(.custom("PlayfairDisplay-Bold", size: 24))
                        .foregroundColor(.appText)
                    
                    ForEach(userData.dailyTaskHistory.last?.tasks.filter { $0.isCompleted } ?? [], id: \.id) { task in
                        HStack(spacing: 12) {
                            Text(task.emoji)
                                .font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.task)
                                    .font(.system(size: 17))
                                    .foregroundColor(.appText)
                                Text(task.formattedCompletionTime ?? "")
                                    .font(.system(size: 15))
                                    .foregroundColor(.appTextSecondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // This Week's Entries Section
                if !userData.getCurrentWeekEntries().isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("This Week's Entries")
                            .font(.custom("PlayfairDisplay-Bold", size: 24))
                            .foregroundColor(.appText)
                        
                        ForEach(userData.getCurrentWeekEntries()) { entry in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(formatDate(entry.date))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.appText)
                                Text(entry.content)
                                    .font(.system(size: 17))
                                    .foregroundColor(.appTextSecondary)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 24)
        }
    }
    
    private var pastEntriesView: some View {
        ScrollView {
            if userData.weeklySummaries.isEmpty {
                VStack(spacing: 32) {
                    AnimatedGradientCircle(
                        size: 120,
                        primaryColor: .appAccent
                    )
                    
                    VStack(spacing: 16) {
                        Text("No Past Entries Yet")
                            .font(.custom("PlayfairDisplay-Regular", size: 24))
                            .foregroundColor(.appText)
                        
                        Text("Keep journaling daily! After a week, you'll see AI-powered insights and personalized goal suggestions here.")
                            .font(.system(size: 17))
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 60)
            } else {
                VStack(spacing: 24) {
                    ForEach(userData.weeklySummaries) { summary in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(formatWeekRange(start: summary.weekStartDate, end: summary.weekEndDate))
                                .font(.custom("PlayfairDisplay-Bold", size: 24))
                                .foregroundColor(.appText)
                            
                            VStack(alignment: .leading, spacing: 16) {
                                Text("AI Analysis")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.appText)
                                Text(summary.aiAnalysis)
                                    .font(.system(size: 17))
                                    .foregroundColor(.appTextSecondary)
                                
                                if !summary.suggestedGoals.isEmpty {
                                    Text("Suggested Goals")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.appText)
                                        .padding(.top, 8)
                                    
                                    ForEach(summary.suggestedGoals, id: \.self) { goal in
                                        HStack(spacing: 8) {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.appAccent)
                                            Text(goal)
                                                .font(.system(size: 17))
                                                .foregroundColor(.appTextSecondary)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 24)
            }
        }
    }
    
    private func saveJournalEntry() {
        guard !journalText.isEmpty else { return }
        let completedTasks = userData.dailyTaskHistory.last?.tasks.filter { $0.isCompleted }.map { $0.task } ?? []
        let entry = JournalEntry(content: journalText, completedTasks: completedTasks)
        userData.addJournalEntry(entry)
        journalText = ""
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatWeekRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

struct WeeklySummaryView: View {
    let summary: WeeklySummary
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Weekly Wrap-up")
                        .font(.custom("PlayfairDisplay-Regular", size: 34))
                        .foregroundColor(.appText)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AI Analysis")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.appText)
                        Text(summary.aiAnalysis)
                            .font(.system(size: 17))
                            .foregroundColor(.appTextSecondary)
                        
                        if !summary.suggestedGoals.isEmpty {
                            Text("Suggested Goals")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.appText)
                                .padding(.top, 8)
                            
                            ForEach(summary.suggestedGoals, id: \.self) { goal in
                                HStack(spacing: 8) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.appAccent)
                                    Text(goal)
                                        .font(.system(size: 17))
                                        .foregroundColor(.appTextSecondary)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
        }
        .preferredColorScheme(.light)
    }
} 

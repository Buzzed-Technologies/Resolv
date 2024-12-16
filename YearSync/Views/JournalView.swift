import SwiftUI

// Message model for chat interface
struct Message: Identifiable, Codable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    let title: String? // Optional title for entries
    
    init(content: String, isUser: Bool, timestamp: Date = Date(), title: String? = nil) {
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.title = title
    }
}

struct JournalView: View {
    @Binding var userData: UserData
    @State private var currentMessage = ""
    @State private var messages: [Message] = []
    @State private var showingWeeklySummary = false
    @State private var selectedTab = 0
    @State private var isTyping = false
    @Environment(\.dismiss) var dismiss
    @State private var midnightTimer: Timer?
    @FocusState private var isInputFocused: Bool
    
    // Animation states
    @State private var messageOpacity = 0.0
    @State private var messageOffset: CGFloat = 20
    @State private var isInputBarVisible = false
    
    // Initial prompt to start the conversation
    private let initialPrompt = "How was your day?"
    
    // UserDefaults keys
    private let messagesKey = "journalMessages"
    private let lastSaveDateKey = "lastJournalSaveDate"
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Segmented Control
                    HStack(spacing: 0) {
                        ForEach(["Current Week", "Past Entries"], id: \.self) { tab in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTab = tab == "Current Week" ? 0 : 1
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }) {
                                VStack(spacing: 8) {
                                    Text(tab)
                                        .font(.custom("PlayfairDisplay-Regular", size: 17))
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
                        chatView
                            .transition(.opacity)
                    } else {
                        pastEntriesView
                            .transition(.opacity)
                    }
                }
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Journal")
                        .font(.custom("PlayfairDisplay-Bold", size: 17))
                        .foregroundColor(.appText)
                }
            }
            .sheet(isPresented: $showingWeeklySummary) {
                WeeklySummaryView(summary: userData.weeklySummaries.last ?? WeeklySummary(weekStartDate: Date(), weekEndDate: Date()))
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                    isInputBarVisible = true
                }
                
                loadMessages()
                setupMidnightTimer()
                
                // Add observer for weekly analysis completion
                NotificationCenter.default.addObserver(
                    forName: .weeklyJournalAnalysisCompleted,
                    object: nil,
                    queue: .main
                ) { notification in
                    if let summary = notification.userInfo?["summary"] as? WeeklySummary,
                       let indices = notification.userInfo?["indices"] as? [Int] {
                        userData.applyWeeklySummary(summary, entryIndices: indices)
                    }
                }
            }
            .onDisappear {
                midnightTimer?.invalidate()
                saveMessages()
                
                // Remove observer
                NotificationCenter.default.removeObserver(self)
            }
            .onTapGesture {
                isInputFocused = false
            }
        }
        .preferredColorScheme(.light)
    }
    
    private func setupMidnightTimer() {
        // Calculate time until next midnight
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
              let nextMidnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) else {
            return
        }
        
        let timeUntilMidnight = nextMidnight.timeIntervalSince(Date())
        
        // Set up timer for next midnight
        midnightTimer = Timer.scheduledTimer(withTimeInterval: timeUntilMidnight, repeats: false) { _ in
            saveJournalAndReset()
            // Set up next timer
            setupMidnightTimer()
        }
    }
    
    private func loadMessages() {
        // Check if we need to start fresh (new day)
        if let lastSaveDate = UserDefaults.standard.object(forKey: lastSaveDateKey) as? Date {
            let calendar = Calendar.current
            if !calendar.isDate(lastSaveDate, inSameDayAs: Date()) {
                // It's a new day, start fresh
                messages = []
                addAIMessage(initialPrompt)
                return
            }
        }
        
        // Load saved messages
        if let savedData = UserDefaults.standard.data(forKey: messagesKey),
           let savedMessages = try? JSONDecoder().decode([Message].self, from: savedData) {
            messages = savedMessages
        } else if messages.isEmpty {
            addAIMessage(initialPrompt)
        }
    }
    
    private func saveMessages() {
        if let encoded = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(encoded, forKey: messagesKey)
            UserDefaults.standard.set(Date(), forKey: lastSaveDateKey)
        }
    }
    
    private func saveJournalAndReset() {
        guard !messages.isEmpty else { return }
        
        // Save the conversation
        let fullConversation = messages.map { msg in
            "\(msg.isUser ? "User" : "AI"): \(msg.content)"
        }.joined(separator: "\n")
        
        saveJournalEntry(content: fullConversation)
        
        // Clear messages and start fresh
        messages = []
        addAIMessage(initialPrompt)
        
        // Save the empty state
        saveMessages()
    }
    
    private var chatView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Paper header
                    Text(formatTodayDate())
                        .font(.custom("PlayfairDisplay-Bold", size: 24))
                        .foregroundColor(.appText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                    
                    // Journal content
                    VStack(alignment: .leading, spacing: 24) {
                        // Past entries and reflections
                        ForEach(Array(zip(messages.indices, messages)), id: \.0) { index, message in
                            if message.isUser {
                                // User entry
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(formatTime(message.timestamp))
                                        .font(.custom("PlayfairDisplay-Regular", size: 14))
                                        .foregroundColor(.appTextSecondary)
                                    
                                    Text(message.content)
                                        .font(.custom("PlayfairDisplay-Regular", size: 17))
                                        .foregroundColor(.appText)
                                        .lineSpacing(8)
                                }
                                .padding(.horizontal, 24)
                            } else if index > 0 && messages[index - 1].isUser {
                                // AI insight
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Reflection")
                                        .font(.custom("PlayfairDisplay-Italic", size: 15))
                                        .foregroundColor(.appAccent)
                                    
                                    Text(message.content)
                                        .font(.custom("PlayfairDisplay-Regular", size: 16))
                                        .foregroundColor(.appTextSecondary)
                                        .lineSpacing(6)
                                }
                                .padding(16)
                                .padding(.horizontal, 24)
                                .background(
                                    Rectangle()
                                        .fill(Color(UIColor.systemGray6).opacity(0.3))
                                        .cornerRadius(4)
                                )
                                .overlay(
                                    Rectangle()
                                        .fill(Color.appAccent.opacity(0.3))
                                        .frame(width: 3)
                                        .padding(.vertical, 4),
                                    alignment: .leading
                                )
                                
                                Divider()
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 16)
                            }
                        }
                        
                        // Current writing area
                        VStack(alignment: .leading, spacing: 8) {
                            if !messages.isEmpty {
                                Text(formatTime(Date()))
                                    .font(.custom("PlayfairDisplay-Regular", size: 14))
                                    .foregroundColor(.appTextSecondary)
                            }
                            
                            TextEditor(text: $currentMessage)
                                .focused($isInputFocused)
                                .font(.custom("PlayfairDisplay-Regular", size: 17))
                                .foregroundColor(.appText)
                                .lineSpacing(8)
                                .frame(minHeight: 120)
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .overlay(
                                    Group {
                                        if currentMessage.isEmpty {
                                            Text("Write about your day...")
                                                .font(.custom("PlayfairDisplay-Regular", size: 17))
                                                .foregroundColor(.appTextSecondary)
                                                .padding(.top, 8)
                                                .padding(.leading, 5)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        .padding(.horizontal, 24)
                        
                        if isTyping {
                            HStack(spacing: 12) {
                                ForEach(0..<3) { index in
                                    Circle()
                                        .fill(Color.appAccent.opacity(0.6))
                                        .frame(width: 4, height: 4)
                                        .offset(y: index % 2 == 0 ? -2 : 2)
                                        .animation(
                                            Animation.easeInOut(duration: 0.6)
                                                .repeatForever(autoreverses: true)
                                                .delay(Double(index) * 0.15),
                                            value: isTyping
                                        )
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 24)
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .padding(.bottom, 24)
                }
                .background(
                    Color(UIColor.systemBackground)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                )
                .onChange(of: messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    isInputFocused = false
                }
            )
            .overlay(
                // Floating send button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: sendMessage) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.appAccent)
                                .opacity(!currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1.0 : 0.0)
                                .scaleEffect(!currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1.0 : 0.8)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: !currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        }
                        .disabled(currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .padding(24)
                    }
                }
            )
        }
        .background(Color(UIColor.systemGray6).opacity(0.1))
    }
    
    private func sendMessage() {
        let messageText = currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty else { return }
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        // Add user message
        let userMessage = Message(content: messageText, isUser: true)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            messages.append(userMessage)
            currentMessage = ""
        }
        
        // Process the message and generate AI response
        processUserMessage()
    }
    
    private func processUserMessage() {
        withAnimation(.easeIn(duration: 0.2)) {
            isTyping = true
        }
        
        // Get AI response
        Task {
            do {
                let response = try await OpenAIService.shared.processJournalMessage(messages)
                
                // Add AI response with animation
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        addAIMessage(response)
                        isTyping = false
                    }
                }
            } catch {
                print("Error getting AI response: \(error)")
                DispatchQueue.main.async {
                    withAnimation {
                        addAIMessage("I'm having trouble processing that. Let's try again - how was your day?")
                        isTyping = false
                    }
                }
            }
        }
    }
    
    private func addAIMessage(_ content: String) {
        let aiMessage = Message(content: content, isUser: false)
        messages.append(aiMessage)
    }
    
    private func saveJournalEntry(content: String) {
        let completedTasks = userData.dailyTaskHistory.last?.tasks.filter { $0.isCompleted }.map { $0.task } ?? []
        let entry = JournalEntry(content: content, completedTasks: completedTasks)
        userData.addJournalEntry(entry)
    }
    
    private var pastEntriesView: some View {
        ScrollView {
            if userData.weeklySummaries.isEmpty {
                VStack(spacing: 32) {
                    AnimatedGradientCircle(
                        size: 120,
                        primaryColor: .green
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
    
    private func formatTodayDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: Date())
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
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


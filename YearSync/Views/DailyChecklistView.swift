import SwiftUI
import CoreFoundation

struct DailyChecklistView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingResetAlert = false
    @State private var isRefreshing = false
    @State private var selectedTab = 0
    @State private var appearAnimation = false
    @State private var hasLoaded = false
    
    private let headerHeight: CGFloat = 180
    private let minimizedHeaderHeight: CGFloat = 60
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Header Views with improved animation
                    if let currentDay = viewModel.userData.currentDay {
                        headerView(currentDay: currentDay)
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : -20)
                    }
                    
                    // Content
                    if let currentDay = viewModel.userData.currentDay {
                        if !hasLoaded && viewModel.isLoadingTasks {
                            LoadingView(message: "")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            contentView(currentDay: currentDay)
                                .transition(.opacity)
                        }
                    }
                }
                
                // Floating Action Button
                HStack(spacing: 40) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.showingHistory.toggle()
                    }) {
                        Image(systemName: "book")
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                    }
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.showingPlanOverview.toggle()
                    }) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(
                    Capsule()
                        .fill(Color.white)
                        .shadow(color: Color.white.opacity(0.2), radius: 8, x: 0, y: 0)
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 0, green: 0.4, blue: 0), lineWidth: 1.5)
                                .shadow(color: Color(red: 0, green: 0.3, blue: 0).opacity(0.9), radius: 4, x: 0, y: 0)
                        )
                )
                .padding(.bottom, 30)
                .opacity(appearAnimation ? 1 : 0)
                .offset(y: appearAnimation ? 0 : 20)
            }
            .ignoresSafeArea(edges: .top)
            .alert("Reset Plan", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    viewModel.resetPlan()
                }
            } message: {
                Text("Are you sure you want to reset your plan? This will delete all your progress.")
            }
            .overlay {
                if isRefreshing {
                    LoadingView(message: "")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white.opacity(0.95))
                        .transition(.opacity)
                }
            }
            .sheet(isPresented: $viewModel.showingHistory) {
                JournalView(userData: $viewModel.userData)
            }
            .sheet(isPresented: $viewModel.showingPlanOverview) {
                PlanOverviewView(userData: $viewModel.userData)
            }
        }
        .task {
            await viewModel.generateDailyTasksIfNeeded()
            
            // Animate everything in sequence
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
                hasLoaded = true
            }
        }
        .preferredColorScheme(.light)
    }
    
    @ViewBuilder
    private func contentView(currentDay: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Sort tasks: incomplete first, then completed
                let sortedTasks = viewModel.dailyTasks.sorted { task1, task2 in
                    if task1.isCompleted == task2.isCompleted {
                        // If both completed or both incomplete, maintain original order
                        return task1.id.uuidString < task2.id.uuidString
                    }
                    // Put incomplete tasks first
                    return !task1.isCompleted
                }
                
                ForEach(sortedTasks) { task in
                    TaskCard(task: task)
                        .padding(.horizontal)
                        .transition(.opacity)
                }
                
                // Add bottom padding to account for floating action button
                Spacer()
                    .frame(height: 100)
            }
            .padding(.top, 16)
            .opacity(appearAnimation ? 1 : 0)
            .offset(y: appearAnimation ? 0 : 20)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.dailyTasks.map { $0.isCompleted })
        }
    }
    
    @ViewBuilder
    private func headerView(currentDay: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                // Day counter with calendar icon
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 28))
                        .foregroundColor(.black)
                    Text("Day \(currentDay)/\(viewModel.userData.planDuration)")
                        .font(.custom("PlayfairDisplay-Regular", size: 34))
                        .foregroundColor(.black)
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemGray6))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: geometry.size.width * (CGFloat(currentDay) / CGFloat(viewModel.userData.planDuration)),
                                   height: 8)
                    }
                }
                .frame(height: 8)
                .padding(.top, 8)  // Align with text
            }
            
            if !viewModel.dailySummary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    TypewriterText(viewModel.dailySummary)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                    
                    Rectangle()
                        .fill(Color.black.opacity(0.1))
                        .frame(height: 1)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, UIApplication.shared.windows.first?.safeAreaInsets.top ?? 47)
        .padding(.bottom, 16)
        .background(Color.white)
    }
    
    @ViewBuilder
    private func progressBar(currentDay: Int) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(UIColor.systemGray6))
                    .frame(height: 12)
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.green)
                    .frame(width: geometry.size.width * (CGFloat(currentDay) / CGFloat(viewModel.userData.planDuration)),
                           height: 12)
            }
        }
        .frame(height: 12)
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ConfettiView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            ForEach(0..<50) { _ in
                Circle()
                    .fill(Color.random)
                    .frame(width: 8, height: 8)
                    .modifier(ParticlesModifier())
                    .offset(x: .random(in: -150...150), y: isAnimating ? 400 : -100)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatCount(1)) {
                isAnimating = true
            }
        }
    }
}

struct ParticlesModifier: ViewModifier {
    @State private var time = 0.0
    let duration = 1.5
    
    func body(content: Content) -> some View {
        content
            .modifier(FireworkParticlesGeometryEffect(time: time))
            .onAppear {
                withAnimation(.easeOut(duration: duration)) {
                    self.time = duration
                }
            }
    }
}

struct FireworkParticlesGeometryEffect: GeometryEffect {
    var time: Double
    var speed = Double.random(in: 20...200)
    var direction = Double.random(in: -Double.pi...Double.pi)
    
    var animatableData: Double {
        get { time }
        set { time = newValue }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let xTranslation = speed * cos(direction) * time
        let yTranslation = speed * sin(direction) * time
        let affineTransform = CGAffineTransform(translationX: xTranslation, y: yTranslation)
        return ProjectionTransform(affineTransform)
    }
}

extension Color {
    static var random: Color {
        Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}

struct TaskCard: View {
    let task: DailyTask
    @EnvironmentObject var viewModel: AppViewModel
    @State private var offset: CGFloat = 0
    @State private var showConfetti = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring()) {
                viewModel.toggleTask(task)
                if !task.isCompleted {
                    showConfetti = true
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            }
        }) {
            VStack(spacing: 0) {
                // Top section with emoji and task
                HStack(spacing: 16) {
                    Text(task.emoji)
                        .font(.system(size: 32))
                    
                    Text(task.task)
                        .font(.custom("PlayfairDisplay-Regular", size: 20))
                        .foregroundColor(.black)
                        .strikethrough(task.isCompleted, color: .black)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 24))
                        .foregroundColor(task.isCompleted ? .green : .gray.opacity(0.3))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Divider line
                if task.isCompleted {
                    Rectangle()
                        .fill(Color(UIColor.systemGray5))
                        .frame(height: 1)
                    
                    // Bottom section with completion time
                    if let completionTime = task.formattedCompletionTime {
                        HStack {
                            Text(completionTime)
                                .font(.system(size: 17))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            Spacer()
                        }
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
        }
        .buttonStyle(TaskCardButtonStyle())
        
        if showConfetti {
            ConfettiView()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showConfetti = false
                    }
                }
        }
    }
}

struct TaskHistory: Identifiable {
    let id = UUID()
    let date: Date
    let tasks: [DailyTask]
}

struct TaskHistoryItemView: View {
    let task: DailyTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(task.emoji)
                    .font(.system(size: 17))
                Text(task.task)
                    .font(.system(size: 17))
                    .foregroundColor(.appText)
            }
            
            if let completionTime = task.formattedCompletionTime {
                HStack(spacing: 8) {
                    Text("Completed: \(completionTime)")
                        .font(.system(size: 15))
                        .foregroundColor(task.completionStatus.color)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct TaskHistorySection: View {
    let history: TaskHistory
    
    var body: some View {
        Section {
            ForEach(history.tasks) { task in
                TaskHistoryItemView(task: task)
            }
        } header: {
            Text(formatDate(history.date))
                .font(.custom("PlayfairDisplay-Regular", size: 20))
                .foregroundColor(.appText)
                .textCase(nil)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct TaskHistoryView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()
                
                List {
                    ForEach(viewModel.taskHistory, id: \.date) { history in
                        TaskHistorySection(history: history)
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("Task History")
                .navigationBarItems(trailing: Button("Done") {
                    dismiss()
                })
            }
        }
        .preferredColorScheme(.light)
    }
}

struct TaskCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
} 


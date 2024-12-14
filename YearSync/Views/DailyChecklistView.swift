import SwiftUI
import CoreFoundation

struct DailyChecklistView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingResetAlert = false
    @State private var isRefreshing = false
    @State private var selectedTab = 0
    @State private var appearAnimation = false
    
    private let headerHeight: CGFloat = 180
    private let minimizedHeaderHeight: CGFloat = 60
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                Color.white.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 24) {
                    if let currentDay = viewModel.userData.currentDay {
                        if viewModel.isLoadingTasks {
                            LoadingView(message: "")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .transition(.opacity)
                        } else {
                            contentView(currentDay: currentDay)
                                .transition(.opacity)
                        }
                    }
                }
                .padding(.top, headerHeight)
                .padding(.bottom, 100)
                
                // Header Views
                if let currentDay = viewModel.userData.currentDay {
                    headerView(currentDay: currentDay)
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : -20)
                }
                
                // Bottom Navigation Bar
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
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
                                .overlay(
                                    Capsule()
                                        .stroke(Color.green.opacity(0.8), lineWidth: 1.5)
                                        .shadow(color: Color.green.opacity(0.5), radius: 4, x: 0, y: 0)
                                )
                                .shadow(color: Color.green.opacity(0.2), radius: 8, x: 0, y: 0)
                        )
                        Spacer()
                    }
                    .padding(.bottom, 30)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                }
            }
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
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
        }
        .preferredColorScheme(.light)
    }
    
    @ViewBuilder
    private func contentView(currentDay: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let currentTask = viewModel.currentTasks.first {
                TaskCard(task: currentTask, isCompleted: false)
                    .padding(.top, 24)
                    .padding(.horizontal)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9)
                            .combined(with: .opacity)
                            .combined(with: .offset(y: 20)),
                        removal: .opacity
                    ))
            } else {
                emptyStateCard()
            }
            
            upcomingTasksSection()
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
    }
    
    @ViewBuilder
    private func emptyStateCard() -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text("🎉")
                        .font(.system(size: 20))
                    Text("Good work, keep it up!")
                        .font(.system(size: 17))
                        .foregroundColor(.appText)
                }
                
                Text("Your next task is coming up soon")
                    .font(.system(size: 15))
                    .foregroundColor(.appTextSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .padding(.top, 24)
        .padding(.horizontal)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9)
                .combined(with: .opacity)
                .combined(with: .offset(y: 20)),
            removal: .opacity
        ))
    }
    
    @ViewBuilder
    private func upcomingTasksSection() -> some View {
        let upcomingTasks = viewModel.upcomingTasks
        
        if !upcomingTasks.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Coming Up")
                    .font(.custom("Baskerville-Bold", size: 24))
                    .foregroundColor(.appText)
                    .padding(.top, 8)
                    .transition(.opacity)
                
                ForEach(Array(upcomingTasks.enumerated()), id: \.element.id) { index, task in
                    UpcomingTaskCard(task: task)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9)
                                .combined(with: .opacity)
                                .combined(with: .offset(y: 20))
                                .animation(.easeOut.delay(Double(index) * 0.1)),
                            removal: .opacity
                        ))
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func headerView(currentDay: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Day \(currentDay) of \(viewModel.userData.planDuration)")
                        .font(.custom("Baskerville-Bold", size: 34))
                        .foregroundColor(.appText)
                    HStack(spacing: 4) {
                        Text("\(viewModel.completedTasksToday) of \(viewModel.totalTasksToday)")
                            .font(.system(size: 17, weight: .semibold))
                        Text("tasks completed")
                            .font(.system(size: 17))
                            .foregroundColor(.appTextSecondary)
                    }
                }
                Spacer()
            }
            
            progressBar(currentDay: currentDay)
            
            if !viewModel.dailySummary.isEmpty {
                Text(viewModel.dailySummary)
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .frame(height: headerHeight)
        .background(Color.white)
    }
    
    @ViewBuilder
    private func progressBar(currentDay: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
    let isCompleted: Bool
    @EnvironmentObject var viewModel: AppViewModel
    @State private var offset: CGFloat = 0
    @State private var showConfetti = false
    
    var body: some View {
        ZStack {
            Button(action: {
                if !isCompleted {
                    withAnimation(.spring()) {
                        offset = -200
                        viewModel.toggleTask(task)
                        showConfetti = true
                        
                        // Haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                }
            }) {
                HStack(alignment: .center, spacing: 16) {
                    // Left side: Emoji and Time
                    VStack(spacing: 2) {
                        Text(task.emoji)
                            .font(.system(size: 32))
                            .frame(height: 32)
                        
                        Text(task.formattedTime)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.appTextSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        if let completionTime = task.formattedCompletionTime {
                            Text(completionTime)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(task.completionStatus.color)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .frame(width: 65)
                    
                    // Task description
                    Text(task.task)
                        .font(.system(size: 17))
                        .foregroundColor(task.isCompleted || isCompleted ? .appText : .appText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Checkbox
                    Image(systemName: task.isCompleted || isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.isCompleted || isCompleted ? .appAccent : .appTextSecondary)
                        .font(.system(size: 24))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
            }
            .offset(y: offset)
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
}

struct UpcomingTaskCard: View {
    let task: DailyTask
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Left side: Emoji and Time
            VStack(spacing: 2) {
                Text(task.emoji)
                    .font(.system(size: 28))
                    .frame(height: 28)
                
                Text(task.formattedTime)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 55)
            
            // Task description
            Text(task.task)
                .font(.system(size: 15))
                .foregroundColor(.appText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
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
                        Section {
                            ForEach(history.tasks) { task in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Text(task.emoji)
                                            .font(.system(size: 17))
                                        Text(task.task)
                                            .font(.system(size: 17))
                                            .foregroundColor(.appText)
                                    }
                                    
                                    HStack(spacing: 8) {
                                        Text(task.formattedTime)
                                            .font(.system(size: 15))
                                            .foregroundColor(.appTextSecondary)
                                        
                                        if let completionTime = task.formattedCompletionTime {
                                            Text("•")
                                                .foregroundColor(.appTextSecondary)
                                            Text("Completed: \(completionTime)")
                                                .font(.system(size: 15))
                                                .foregroundColor(task.completionStatus.color)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        } header: {
                            Text(formatDate(history.date))
                                .font(.custom("Baskerville-Bold", size: 20))
                                .foregroundColor(.appText)
                                .textCase(nil)
                        }
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
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


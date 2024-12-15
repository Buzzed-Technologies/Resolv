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
            ZStack {
                // Main content
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
                            .overlay(
                                Capsule()
                                    .stroke(Color(red: 0, green: 0.4, blue: 0), lineWidth: 1.5)
                            )
                    )
                    .padding(.bottom, 30)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                }
                
                // Confetti overlay
                if viewModel.showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
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
                // Use StableGradientCircle instead of AnimatedGradientCircle
                HStack(spacing: 4) {
                    StableGradientCircle(
                        size: 40,
                        primaryColor: Color(red: 0, green: 0.4, blue: 0)
                    )
                    .frame(width: 40, height: 40)
                    
                    Text("Day \(currentDay)/\(viewModel.userData.planDuration)")
                        .font(.custom("PlayfairDisplay-Regular", size: 34))
                        .foregroundColor(.black)
                }
                
                // Progress bar remains the same
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(UIColor.systemGray6))
                            .frame(height: 20)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0, green: 0.4, blue: 0))
                            .frame(width: geometry.size.width * (CGFloat(currentDay) / CGFloat(viewModel.userData.planDuration)),
                                   height: 20)
                    }
                }
                .frame(height: 12)
                .padding(.top, 8)
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
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<80) { _ in
                    Circle()
                        .fill(Color.random)
                        .frame(width: 8, height: 8)
                        .modifier(ParticlesModifier())
                        .offset(
                            x: .random(in: -geometry.size.width/4...geometry.size.width/4),
                            y: isAnimating ? geometry.size.height : -geometry.size.height/3
                        )
                        .position(x: geometry.size.width/2, y: geometry.size.height/3)
                }
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
    
    var body: some View {
        Button(action: {
            withAnimation(.spring()) {
                viewModel.toggleTask(task)
                if !task.isCompleted {
                    viewModel.triggerConfetti()
                    
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
                        .padding(12)
                        .background(
                            Circle()
                                .fill(Color(UIColor.systemGray6))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.task)
                            .font(.custom("PlayfairDisplay-Regular", size: 20))
                            .foregroundColor(.black)
                            .strikethrough(task.isCompleted, color: .black)
                            .multilineTextAlignment(.leading)
                        
                        if task.isCompleted, let completionTime = task.formattedCompletionTime {
                            Text(completionTime)
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(task.isCompleted ? .green : Color(UIColor.systemGray4))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(UIColor.systemGray5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(TaskCardButtonStyle())
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

// Helper extensions to find parent views
extension UIView {
    func findViewController() -> UIViewController? {
        if let nextResponder = self.next as? UIViewController {
            return nextResponder
        } else if let nextResponder = self.next as? UIView {
            return nextResponder.findViewController()
        } else {
            return nil
        }
    }
    
    func findView<T: View>(ofType type: T.Type) -> T? {
        for subview in subviews {
            if let view = subview as? T {
                return view
            }
            if let foundView = subview.findView(ofType: type) {
                return foundView
            }
        }
        return nil
    }
}

struct StableGradientCircle: View {
    var size: CGFloat = 180
    var primaryColor: Color = Color(red: 76/255, green: 175/255, blue: 80/255)
    
    var body: some View {
        ZStack {
            // Outer blurred circle for fade effect
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            primaryColor.opacity(0.2),
                            primaryColor.opacity(0)
                        ]),
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size * 1.5, height: size * 1.5)
                .blur(radius: 20)
            
            // Main gradient circle
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            primaryColor.opacity(0.7),
                            primaryColor.opacity(0.3),
                            primaryColor.opacity(0.1)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .white.opacity(0.5),
                                    .clear
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .scaleEffect(0.98)
                        .blur(radius: 1)
                )
        }
    }
}


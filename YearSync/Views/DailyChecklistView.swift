import SwiftUI
import CoreFoundation

struct DailyChecklistView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingResetAlert = false
    @State private var isRefreshing = false
    @State private var selectedTab = 0
    @State private var appearAnimation = false
    @State private var hasLoaded = false
    @FocusState private var isAnyTextFieldFocused: Bool
    
    private let headerHeight: CGFloat = 180
    private let minimizedHeaderHeight: CGFloat = 60
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Background tap area with high priority
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                         to: nil,
                                                         from: nil,
                                                         for: nil)
                        }
                        .zIndex(0) // Ensure it's behind other content
                    
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
                    .zIndex(1) // Ensure it's above the tap area
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
        .simultaneousGesture(TapGesture().onEnded { _ in
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                         to: nil,
                                         from: nil,
                                         for: nil)
        })
    }
    
    @ViewBuilder
    private func headerView(currentDay: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top row with circle, day counter, and progress bar
            HStack(alignment: .top, spacing: 16) {
                // Time-based gradient circle
                TimeBasedGradientCircle(size: 40)
                    .frame(width: 40, height: 40)
                
                // Day counter
                Text("Day \(currentDay)/\(viewModel.userData.planDuration)")
                    .font(.custom("PlayfairDisplay-Regular", size: 24))
                    .foregroundColor(.black)
                    .layoutPriority(1)
                
                // Progress bar - moved down 3 pixels
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(UIColor.systemGray6))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0, green: 0.4, blue: 0))
                            .frame(
                                width: geometry.size.width * (CGFloat(currentDay) / CGFloat(viewModel.userData.planDuration)),
                                height: 12
                            )
                    }
                    .offset(y: 13) // Offset added here
                }
                .frame(height: 12)
            }
            
            // Summary text and line
            if !viewModel.dailySummary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    TypewriterText(viewModel.dailySummary)
                        .font(.custom("PlayfairDisplay-Regular", size: 16))
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
    @State private var notes: String
    @FocusState private var isTextFieldFocused: Bool
    
    init(task: DailyTask) {
        self.task = task
        _notes = State(initialValue: task.notes)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top section with task and completion status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Emoji and task title
                    HStack(spacing: 8) {
                        Text(task.emoji)
                            .font(.system(size: 24))
                        Text(task.task)
                            .font(.custom("PlayfairDisplay-Regular", size: 18))
                            .foregroundColor(.primary)
                            .strikethrough(task.isCompleted, color: .primary)
                    }
                }
                
                Spacer()
                
                // Checkmark button
                Button(action: {
                    withAnimation(.spring()) {
                        viewModel.toggleTask(task)
                        if !task.isCompleted {
                            viewModel.triggerConfetti()
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }
                        isTextFieldFocused = false
                    }
                }) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(task.isCompleted ? Color(red: 0, green: 0.4, blue: 0) : Color(UIColor.systemGray4))
                }
            }
            
            Divider()
                .background(Color(UIColor.systemGray5))
            
            // Notes section
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                TextField("Add your notes here...", text: $notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .lineLimit(3...6)
                    .focused($isTextFieldFocused)
                    .onChange(of: notes) { newValue in
                        viewModel.updateTaskNotes(task, notes: newValue)
                    }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(UIColor.systemGray5), lineWidth: 1)
        )
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

struct TimeBasedGradientCircle: View {
    var size: CGFloat
    @State private var currentTime = Date()
    
    private var timeColors: (primary: Color, secondary: Color, accent: Color) {
        let hour = Calendar.current.component(.hour, from: currentTime)
        
        switch hour {
        case 5...8: // Dawn
            return (
                Color(red: 0.2, green: 0.3, blue: 0.5),
                Color(red: 1.0, green: 0.6, blue: 0.2),
                Color(red: 0.9, green: 0.7, blue: 0.4)
            )
        case 9...16: // Day
            return (
                Color(red: 0.95, green: 0.8, blue: 0.2),
                Color(red: 1.0, green: 0.9, blue: 0.4),
                Color.white
            )
        case 17...20: // Dusk
            return (
                Color(red: 0.8, green: 0.4, blue: 0.2),
                Color(red: 0.6, green: 0.2, blue: 0.4),
                Color(red: 1.0, green: 0.6, blue: 0.3)
            )
        default: // Night
            return (
                Color(red: 0.1, green: 0.1, blue: 0.3),
                Color(red: 0.2, green: 0.2, blue: 0.4),
                Color(red: 0.4, green: 0.4, blue: 0.6)
            )
        }
    }
    
    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            timeColors.primary.opacity(0.3),
                            timeColors.primary.opacity(0)
                        ]),
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.8
                    )
                )
                .frame(width: size * 1.5, height: size * 1.5)
                .blur(radius: 15)
            
            // Main sun/moon circle
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            timeColors.secondary,
                            timeColors.primary
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
                                    timeColors.accent.opacity(0.8),
                                    timeColors.accent.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
        .onAppear {
            // Update time every minute
            Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                currentTime = Date()
            }
        }
    }
}

// Add this extension to enable tap gesture to dismiss keyboard globally
extension View {
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                         to: nil,
                                         from: nil,
                                         for: nil)
        }
    }
}


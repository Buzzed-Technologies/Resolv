import SwiftUI
import Foundation

// First, let's create a haptic feedback manager
class HapticManager {
    static let shared = HapticManager()
    
    private let impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .soft)
    
    func playBreathingHaptic(intensity: Double) {
        impactFeedbackGenerator.prepare()
        impactFeedbackGenerator.impactOccurred(intensity: intensity)
    }
}

struct LoadingView: View {
    let message: String
    @State private var overallScale: CGFloat = 1.0
    @State private var breathingScale: CGFloat = 1.0
    @State private var breathingOpacity: Double = 0.6
    @State private var hapticTimer: Timer?
    
    var body: some View {
        VStack(spacing: 32) {
            AnimatedGradientCircle(
                size: 120,
                primaryColor: .green
            )
            .scaleEffect(breathingScale)
            .scaleEffect(overallScale)
            .opacity(breathingOpacity)
            .onAppear {
                // Start the breathing animation
                withAnimation(
                    .easeInOut(duration: 4.0)
                    .repeatForever(autoreverses: true)
                ) {
                    breathingScale = 1.3
                    breathingOpacity = 1.0
                }
                
                // Start the overall growth
                withAnimation(
                    .easeInOut(duration: 20.0)
                ) {
                    overallScale = 1.5
                }
                
                // Start haptic feedback cycle
                hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                    let progress = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 4.0) / 4.0
                    let intensity = sin(progress * .pi * 2) * 0.5 + 0.5
                    HapticManager.shared.playBreathingHaptic(intensity: intensity)
                }
                
                if let timer = hapticTimer {
                    RunLoop.current.add(timer, forMode: .common)
                }
            }
            .onDisappear {
                // Clean up timer when view disappears
                hapticTimer?.invalidate()
                hapticTimer = nil
            }
            
            Text(message)
                .font(.system(size: 17))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

struct PlanCreationView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var goals: [Goal] = []
    @State private var error: Error?
    @State private var showError = false
    @Namespace private var animation
    @State private var appearAnimation = false
    
    private let accentColor = Color(red: 39/255, green: 69/255, blue: 42/255)
    
    var body: some View {
        ZStack {
            if viewModel.isGeneratingPlan {
                LoadingView(message: "")
            } else if !goals.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Your plan is ready!")
                            .font(.custom("PlayfairDisplay-Regular", size: 32))
                            .padding(.top, 60)
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)
                        
                        Text("Here's a recap of what you're going to\nget done in the next \(viewModel.userData.planDuration) days:")
                            .font(.custom("PlayfairDisplay-Regular", size: 20))
                            .foregroundColor(.black.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)
                        
                        // Goal cards
                        VStack(spacing: 24) {
                            ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                                VStack(spacing: 0) {
                                    GoalPlanCard(goal: goal, index: index, totalCount: goals.count)
                                    if index < goals.count - 1 {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 1)
                                            .padding(.vertical, 12)
                                    }
                                }
                                .opacity(appearAnimation ? 1 : 0)
                                .offset(y: appearAnimation ? 0 : 50)
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 100)
                    }
                    .padding(.horizontal, 32)
                }
                
                // Floating button overlay
                .overlay(
                    VStack {
                        Spacer()
                        ModernButton(title: "Let's start") {
                            viewModel.moveToNextScreen()
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)
                    }
                )
                .ignoresSafeArea()
            } else {
                Text("Goals array is empty")
                    .foregroundColor(.red)
            }
        }
        .onChange(of: viewModel.isGeneratingPlan) { isGenerating in
            if !isGenerating {
                goals = viewModel.userData.goals
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    appearAnimation = true
                }
            }
        }
        .alert("Error", isPresented: $showError, presenting: error) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
        .task {
            if goals.isEmpty && !viewModel.isGeneratingPlan {
                await generatePlan()
            }
        }
        .preferredColorScheme(.light)
    }
    
    private func generatePlan() async {
        do {
            print("Generating plan...")
            _ = try await viewModel.generatePlan()
            await MainActor.run {
                print("Plan generated, updating goals")
                goals = viewModel.userData.goals
                print("Goals updated:", goals)
                appearAnimation = true
            }
        } catch {
            print("Error generating plan:", error)
            self.error = error
            self.showError = true
        }
    }
}

struct GoalPlanCard: View {
    let goal: Goal
    let index: Int
    let totalCount: Int
    @EnvironmentObject var viewModel: AppViewModel
    @State private var isEditing = false
    @State private var editedText: String = ""
    @State private var isVisible = false
    private let accentColor = Color(red: 39/255, green: 69/255, blue: 42/255)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Goal title with emoji
            HStack {
                Text("\(goal.emoji) \(goal.title)")
                    .font(.custom("PlayfairDisplay-Regular", size: 20))
                    .fontWeight(.medium)
                
                Spacer()
                
                if !isEditing {
                    Button(action: {
                        editedText = goal.strategy
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isEditing = true
                        }
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(accentColor)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
            
            if isEditing {
                VStack(spacing: 16) {
                    TextEditor(text: $editedText)
                        .font(.custom("PlayfairDisplay-Regular", size: 16))
                        .foregroundColor(.black.opacity(0.8))
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 200)
                    
                    HStack {
                        Spacer()
                        Button("Cancel") {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isEditing = false
                            }
                        }
                        .foregroundColor(.secondary)
                        .padding(.trailing, 16)
                        
                        Button("Save") {
                            if let goalIndex = viewModel.userData.goals.firstIndex(where: { $0.id == goal.id }) {
                                viewModel.userData.goals[goalIndex].strategy = editedText
                            }
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isEditing = false
                            }
                        }
                        .foregroundColor(accentColor)
                    }
                    .font(.system(size: 17, weight: .medium))
                }
            } else {
                Text(goal.strategy)
                    .font(.custom("PlayfairDisplay-Regular", size: 16))
                    .foregroundColor(.black.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            withAnimation(
                .spring(response: 0.6, dampingFraction: 0.8)
                .delay(0.2 + Double(index) * 0.1)
            ) {
                isVisible = true
            }
        }
        .onDisappear {
            isVisible = false
        }
    }
}

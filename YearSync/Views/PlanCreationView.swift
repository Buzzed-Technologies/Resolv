import SwiftUI
import Foundation

struct LoadingView: View {
    let message: String
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.6
    
    var body: some View {
        VStack(spacing: 32) {
            Circle()
                .fill(Color.appAccent.opacity(0.3))
                .frame(width: 120, height: 120)
                .scaleEffect(scale)
                .opacity(opacity)
                .shadow(color: Color.appAccent.opacity(0.3), radius: 20, x: 0, y: 0)
                .animation(
                    Animation.easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: true),
                    value: scale
                )
                .animation(
                    Animation.easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: true),
                    value: opacity
                )
                .onAppear {
                    scale = 0.85
                    opacity = 0.3
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
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 24) {
                if viewModel.isLoading {
                    LoadingView(message: "Coming up with a tailored plan so you can smash your goals")
                        .transition(
                            .asymmetric(
                                insertion: .opacity,
                                removal: .opacity.combined(with: .scale(scale: 0.8))
                            )
                        )
                } else if !goals.isEmpty {
                    planView
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 1.1)),
                                removal: .opacity.combined(with: .scale(scale: 0.9))
                            )
                        )
                } else {
                    generatePlanView
                }
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.isLoading)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: goals.isEmpty)
        .alert("Error", isPresented: $showError, presenting: error) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
        .task {
            if goals.isEmpty && !viewModel.isLoading {
                await generatePlan()
            }
        }
        .preferredColorScheme(.light)
    }
    
    private var generatePlanView: some View {
        VStack(spacing: 24) {
            Text("Ready to create your plan?")
                .font(.custom("Baskerville-Bold", size: 34))
                .foregroundColor(.appText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.trailing, 40)
            
            Button(action: {
                Task {
                    await generatePlan()
                }
            }) {
                Text("Generate Plan")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(28)
            }
            .padding(.horizontal)
        }
    }
    
    private var planView: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your plan is ready!")
                    .font(.custom("Baskerville-Bold", size: 34))
                    .foregroundColor(.appText)
                    .matchedGeometryEffect(id: "title", in: animation)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                
                Text("Here's a recap of what you're going to get done in the next \(viewModel.userData.planDuration) days:")
                    .font(.system(size: 17))
                    .foregroundColor(.appTextSecondary)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
            }
            .padding(.horizontal)
            .padding(.trailing, 40)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                        GoalPlanCard(goal: goal, index: index, totalCount: goals.count)
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 50)
                    }
                }
                .padding(.horizontal)
            }
            
            Button(action: {
                withAnimation {
                    viewModel.moveToNextScreen()
                }
            }) {
                HStack {
                    Text("Let's start")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.black)
                .cornerRadius(28)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
            .opacity(appearAnimation ? 1 : 0)
            .offset(y: appearAnimation ? 0 : 30)
        }
        .onAppear {
            withAnimation(
                .spring(response: 0.6, dampingFraction: 0.8)
                .delay(0.1)
            ) {
                appearAnimation = true
            }
        }
        .onDisappear {
            appearAnimation = false
        }
    }
    
    private func generatePlan() async {
        do {
            goals = try await viewModel.generatePlan()
        } catch {
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Text(goal.emoji)
                        .font(.system(size: 20))
                        .opacity(isVisible ? 1 : 0)
                        .offset(x: isVisible ? 0 : -10)
                    
                    Text(goal.title)
                        .font(.custom("Baskerville-Bold", size: 20))
                        .foregroundColor(.appText)
                        .opacity(isVisible ? 1 : 0)
                        .offset(x: isVisible ? 0 : -10)
                }
                Spacer()
                
                if !isEditing {
                    Button(action: {
                        editedText = goal.subPlans.joined(separator: "\n")
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isEditing = true
                        }
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.appTextSecondary)
                            .opacity(isVisible ? 1 : 0)
                    }
                }
            }
            
            if isEditing {
                // Edit Mode with animation
                VStack(spacing: 16) {
                    TextEditor(text: $editedText)
                        .font(.system(size: 17))
                        .foregroundColor(.appText)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 200)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    
                    // Edit Actions
                    HStack {
                        Spacer()
                        Button("Cancel") {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isEditing = false
                            }
                        }
                        .foregroundColor(.appTextSecondary)
                        .padding(.trailing, 16)
                        
                        Button("Save") {
                            let newPlans = editedText
                                .split(separator: "\n")
                                .map(String.init)
                            if let goalIndex = viewModel.userData.goals.firstIndex(where: { $0.id == goal.id }) {
                                viewModel.userData.goals[goalIndex].subPlans = newPlans
                            }
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isEditing = false
                            }
                        }
                        .foregroundColor(.appAccent)
                    }
                    .font(.system(size: 17, weight: .medium))
                }
            } else {
                // View Mode with staggered animation
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(goal.subPlans.indices, id: \.self) { index in
                        Text("• \(goal.subPlans[index])")
                            .font(.system(size: 17))
                            .foregroundColor(.appText)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(isVisible ? 1 : 0)
                            .offset(y: isVisible ? 0 : 10)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
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
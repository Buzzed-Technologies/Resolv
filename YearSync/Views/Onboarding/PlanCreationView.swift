import SwiftUI
import Foundation

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 32) {
            AnimatedGradientCircle()
                .frame(width: 120, height: 120)
            
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
                VStack {
                    Spacer()
                    ModernButton(title: "Let's start") {
                        withAnimation {
                            viewModel.moveToNextScreen()
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
                    .background(
                        Rectangle()
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                            .edgesIgnoringSafeArea(.bottom)
                    )
                }
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
import SwiftUI

// Shared App Colors
extension Color {
    static let appAccent = Color(red: 39/255, green: 69/255, blue: 42/255)
    static let appBackground = Color.white
    static let appSecondary = Color(UIColor.systemGray6)
    static let appText = Color.black
    static let appTextSecondary = Color(UIColor.systemGray)
}

struct InfiniteScrollRow: View {
    let goals: [Goal]
    let selectedGoals: Set<UUID>
    let onSelect: (Goal) -> Void
    let offset: CGFloat
    
    var body: some View {
        HStack(spacing: 6) {
            // Original set of goals
            ForEach(goals) { goal in
                GoalChip(
                    title: goal.title,
                    emoji: goal.emoji,
                    isSelected: selectedGoals.contains(goal.id)
                ) {
                    onSelect(goal)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
            
            // Repeated set for infinite scroll
            ForEach(goals) { goal in
                GoalChip(
                    title: goal.title,
                    emoji: goal.emoji,
                    isSelected: selectedGoals.contains(goal.id)
                ) {
                    onSelect(goal)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }
        .offset(x: offset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GoalSelectionView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var customGoalText = ""
    @State private var selectedGoals: Set<String> = []
    @State private var currentSuggestionIndex: Int = 0
    @FocusState private var isTextFieldFocused: Bool
    
    private let accentColor = Color(red: 39/255, green: 69/255, blue: 42/255)
    
    // Example suggestions that will fade in/out
    let suggestions = [
        "I want to walk my dog 1 mile every day and lift too",
        "I want to limit myself to coffee only three times a week",
        "Learn how to code, start freelancing"
    ]
    
    // Timer for cycling through suggestions
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    // Predefined goals with their emoji
    let goals: [(String, String)] = [
        ("More water", "💧"),
        ("Read", "📚"),
        ("Meditate", "🧘"),
        ("Budget", "💰"),
        ("Run", "🏃"),
        ("Sleep better", "😴"),
        ("Journal", "✍️"),
        ("Eat right", "🍎"),
        ("Lift", "🏋️"),
        ("Stay tidy", "🏠")
    ]
    
    private var isNextButtonEnabled: Bool {
        !selectedGoals.isEmpty || !customGoalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        ZStack {
            // Main content
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text("Tell me about any goals\nyou have for yourself.")
                    .font(.custom("PlayfairDisplay-Regular", size: 32))
                    .fontWeight(.regular)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                    .padding(.top, 60)
                
                // Goals grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(goals, id: \.0) { goal, emoji in
                        GoalChip(
                            title: goal,
                            emoji: emoji,
                            isSelected: selectedGoals.contains(goal),
                            action: {
                                if selectedGoals.contains(goal) {
                                    selectedGoals.remove(goal)
                                    if let existingGoal = viewModel.userData.goals.first(where: { $0.title == goal }) {
                                        viewModel.removeGoal(existingGoal)
                                    }
                                } else {
                                    selectedGoals.insert(goal)
                                    let newGoal = Goal(title: goal, emoji: emoji)
                                    viewModel.addGoal(newGoal)
                                }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        )
                    }
                }
                
                // Separator line
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1)
                    .padding(.vertical, 3)
                
                // Custom goal section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Don't see what you want?\nNo problem! Type here.")
                        .font(.custom("PlayfairDisplay-Regular", size: 25))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                    
                    ZStack(alignment: .topLeading) {
                        if customGoalText.isEmpty && !isTextFieldFocused {
                            Text(suggestions[currentSuggestionIndex])
                                .font(.custom("PlayfairDisplay-Regular", size: 16))
                                .foregroundColor(.gray.opacity(0.7))
                                .padding(.leading, 5)
                                .padding(.top, 8)
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.5), value: currentSuggestionIndex)
                        }
                        
                        TextEditor(text: $customGoalText)
                            .font(.custom("PlayfairDisplay-Regular", size: 16))
                            .frame(height: 100)
                            .scrollContentBackground(.hidden)
                            .background(Color(.systemGray6))
                            .focused($isTextFieldFocused)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                    .overlay(
                        Group {
                            if isTextFieldFocused {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                isTextFieldFocused = false
                                            }
                                        }) {
                                            Text("Done")
                                                .font(.custom("PlayfairDisplay-Regular", size: 16))
                                                .foregroundColor(accentColor)
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 16)
                                                .background(Color(.systemGray6))
                                                .cornerRadius(8)
                                        }
                                        .padding(8)
                                    }
                                }
                            }
                        }
                    )
                    .scaleEffect(isTextFieldFocused ? 1.02 : 1.0)
                    .shadow(color: .black.opacity(isTextFieldFocused ? 0.1 : 0), radius: 10)
                    
                    Text("Be as simple or detailed as you want —\nour AI will automatically create a plan.")
                        .font(.custom("PlayfairDisplay-Regular", size: 16))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                        .opacity(isTextFieldFocused ? 0 : 1)
                }
                
                Spacer()
                
                // Next button using ModernButton
                ModernButton(title: "Next") {
                    isTextFieldFocused = false
                    if !customGoalText.isEmpty {
                        addCustomGoal()
                    }
                    withAnimation {
                        viewModel.moveToNextScreen()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
            }
            .padding(.horizontal, 32)
            
            // Subtle overlay when focused
            if isTextFieldFocused {
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isTextFieldFocused = false
                        }
                    }
            }
        }
        .background(Color.white)
        .preferredColorScheme(.light)
        .onReceive(timer) { _ in
            withAnimation {
                currentSuggestionIndex = (currentSuggestionIndex + 1) % suggestions.count
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isTextFieldFocused)
    }
    
    private func addCustomGoal() {
        guard !customGoalText.isEmpty else { return }
        let customGoal = Goal(
            title: customGoalText,
            emoji: "🎯",
            isCustom: true
        )
        viewModel.addGoal(customGoal)
        selectedGoals.insert(customGoalText)
    }
}

struct GoalChip: View {
    let title: String
    let emoji: String
    let isSelected: Bool
    let action: () -> Void
    
    private let accentColor = Color(red: 39/255, green: 69/255, blue: 42/255)
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 14))
                Text(title)
                    .font(.custom("PlayfairDisplay-Regular", size: 14))
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? accentColor.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 1)
            )
        }
        .foregroundColor(isSelected ? accentColor : .black)
        .background(Color.white)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return CGSize(width: proposal.width ?? result.width, height: result.height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        
        for (index, subview) in subviews.enumerated() {
            let point = result.points[index]
            subview.place(at: CGPoint(x: point.x + bounds.minX, y: point.y + bounds.minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var width: CGFloat = 0
        var height: CGFloat = 0
        var points: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                points.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                width = max(width, currentX)
            }
            
            height = currentY + lineHeight
        }
    }
} 
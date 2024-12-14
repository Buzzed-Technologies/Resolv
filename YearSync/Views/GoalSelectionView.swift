import SwiftUI

// Shared App Colors
extension Color {
    static let appAccent = Color(red: 0.4, green: 0.8, blue: 0.4).opacity(0.9)
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
    @State private var selectedGoals: Set<UUID> = []
    @State private var offset: CGFloat = 0
    @State private var isAnimating = true
    @FocusState private var isTextFieldFocused: Bool
    let scrollSpeed: Double = 25
    
    // Split goals into 4 rows
    private var goalRows: [[Goal]] {
        let goals = Goal.predefinedGoals
        let rowSize = (goals.count + 3) / 4
        return stride(from: 0, to: goals.count, by: rowSize)
            .map { Array(goals[min($0, goals.count)..<min($0 + rowSize, goals.count)]) }
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Text("What habits would you like to build?")
                    .font(.custom("Baskerville-Bold", size: 34))
                    .foregroundColor(.appText)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 40)
                
                Text("Choose from our suggestions or add your own.")
                    .font(.system(size: 17))
                    .foregroundColor(.appTextSecondary)
                    .padding(.horizontal)
                
                // Scrolling Goal Rows Container
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(Array(goalRows.enumerated()), id: \.offset) { index, goals in
                            InfiniteScrollRow(
                                goals: goals,
                                selectedGoals: selectedGoals,
                                onSelect: { goal in
                                    isAnimating = false
                                    if selectedGoals.contains(goal.id) {
                                        selectedGoals.remove(goal.id)
                                        viewModel.removeGoal(goal)
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } else {
                                        selectedGoals.insert(goal.id)
                                        viewModel.addGoal(goal)
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }
                                },
                                offset: isAnimating ? offset : 0
                            )
                            .frame(height: 44)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { _ in
                            isAnimating = false
                            isTextFieldFocused = false
                        }
                )
                .onAppear {
                    offset = 0 // Start at 0
                    let rowWidth = CGFloat(Goal.predefinedGoals.count) * 150
                    withAnimation(.linear(duration: Double(rowWidth) / scrollSpeed).repeatForever(autoreverses: false)) {
                        offset = -rowWidth
                    }
                }
                .padding(.horizontal)
                
                // Custom Goal Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Any additional goals?")
                        .font(.custom("Baskerville-Bold", size: 24))
                        .foregroundColor(.appText)
                        .padding(.horizontal)
                    
                    Text("Tell us about any other goals you have in mind.")
                        .font(.system(size: 15))
                        .foregroundColor(.appTextSecondary)
                        .padding(.horizontal)
                    
                    TextEditor(text: $customGoalText)
                        .focused($isTextFieldFocused)
                        .font(.system(size: 17))
                        .foregroundColor(.appText)
                        .tint(.appAccent)
                        .scrollContentBackground(.hidden)
                        .frame(height: 100)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(customGoalText.isEmpty ? Color.clear : Color.appText, lineWidth: 1)
                        )
                        .overlay(
                            Group {
                                if customGoalText.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Examples:")
                                            .foregroundColor(.appTextSecondary)
                                            .font(.system(size: 15, weight: .medium))
                                        Text("• Walk my dog 1 mile every day")
                                        Text("• Limit coffee to three times a week")
                                        Text("• Learn to code for 30 minutes daily")
                                    }
                                    .font(.system(size: 16))
                                    .foregroundColor(.appTextSecondary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .allowsHitTesting(false)
                                }
                            }
                        )
                        .padding(.horizontal)
                }
                
                Spacer()
                
                Button(action: {
                    if !customGoalText.isEmpty {
                        addCustomGoal()
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation {
                        viewModel.moveToNextScreen()
                    }
                }) {
                    HStack {
                        Text("Next")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedGoals.isEmpty && customGoalText.isEmpty ? Color.gray.opacity(0.3) : Color.appText)
                    .cornerRadius(28)
                }
                .disabled(selectedGoals.isEmpty && customGoalText.isEmpty)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .background(Color.appBackground)
        .environment(\.colorScheme, .light)
        .onTapGesture {
            isTextFieldFocused = false
        }
        .ignoresSafeArea(.keyboard)
    }
    
    private func addCustomGoal() {
        guard !customGoalText.isEmpty else { return }
        let customGoal = Goal(
            title: customGoalText,
            emoji: "🎯",
            isCustom: true
        )
        viewModel.addGoal(customGoal)
        selectedGoals.insert(customGoal.id)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

struct GoalChip: View {
    let title: String
    let emoji: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15))
                Text(emoji)
                    .font(.system(size: 15))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.appAccent : Color(UIColor.systemGray4), lineWidth: isSelected ? 2 : 1)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: isSelected ? Color.appAccent.opacity(0.3) : .clear, radius: 4, x: 0, y: 0)
            )
            .foregroundColor(.appText)
        }
        .buttonStyle(PlainButtonStyle())
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
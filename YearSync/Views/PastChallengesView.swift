import SwiftUI

struct PastChallengesView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("userData") private var userDataStorage: Data?
    
    private var pastChallenges: [PastChallenge] {
        guard let data = userDataStorage,
              let userData = try? JSONDecoder().decode(UserData.self, from: data) else {
            return []
        }
        return userData.pastChallenges.sorted { $0.completedDate > $1.completedDate }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("Past Challenges")
                    .font(.custom("PlayfairDisplay-Regular", size: 28))
                    .foregroundColor(.black)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                
                if pastChallenges.isEmpty {
                    // Empty State
                    VStack(spacing: 24) {
                        AnimatedGradientCircle(size: 120)
                        
                        VStack(spacing: 8) {
                            Text("No Past Challenges Yet")
                                .font(.custom("PlayfairDisplay-Bold", size: 20))
                                .foregroundColor(.primary)
                            Text("Complete your first challenge to see it here!")
                                .font(.custom("PlayfairDisplay-Regular", size: 17))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    // Challenges List
                    VStack(spacing: 16) {
                        ForEach(pastChallenges) { challenge in
                            ChallengeCardView(challenge: challenge)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 20)
        }
        .navigationBarItems(
            trailing: Button("Done") {
                dismiss()
            }
            .font(.custom("PlayfairDisplay-Regular", size: 17))
        )
    }
}

// Moved outside of PastChallengesView
struct ChallengeCardView: View {
    let challenge: PastChallenge
    
    init(challenge: PastChallenge) {
        self.challenge = challenge
    }
    
    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()
    
    private var completionColor: Color {
        let percentage = challenge.completionRate
        switch percentage {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with completion rate
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateFormatter.string(from: challenge.completedDate))
                        .font(.custom("PlayfairDisplay-SemiBold", size: 17))
                        .foregroundColor(.primary)
                    Text("\(challenge.duration) Day Challenge")
                        .font(.custom("PlayfairDisplay-Regular", size: 15))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Completion Circle
                ZStack {
                    Circle()
                        .stroke(Color(UIColor.systemGray5), lineWidth: 3)
                        .frame(width: 44, height: 44)
                    
                    Circle()
                        .trim(from: 0, to: challenge.completionRate)
                        .stroke(completionColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(challenge.completionRate * 100))%")
                        .font(.custom("PlayfairDisplay-Medium", size: 12))
                        .foregroundColor(completionColor)
                }
            }
            
            // Goals
            if !challenge.goals.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goals")
                        .font(.custom("PlayfairDisplay-Regular", size: 15))
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 80))
                    ], spacing: 8) {
                        ForEach(challenge.goals) { goal in
                            HStack(spacing: 6) {
                                Text(goal.emoji)
                                    .font(.system(size: 16))
                                Text(goal.title)
                                    .font(.custom("PlayfairDisplay-Regular", size: 14))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.systemGray6).opacity(0.5))
        .cornerRadius(16)
    }
}

struct PastChallengesView_Previews: PreviewProvider {
    static var previews: some View {
        PastChallengesView()
    }
} 
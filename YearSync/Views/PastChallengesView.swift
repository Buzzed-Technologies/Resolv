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
            VStack(alignment: .leading, spacing: 32) {
                // Header
                Text("Past Challenges")
                    .font(.custom("PlayfairDisplay-Regular", size: 34))
                    .foregroundColor(.black)
                    .padding(.horizontal)
                    .padding(.top, 20)
                
                if pastChallenges.isEmpty {
                    // Empty State
                    VStack(spacing: 24) {
                        AnimatedGradientCircle(size: 120)
                        
                        VStack(spacing: 8) {
                            Text("No Past Challenges Yet")
                                .font(.custom("PlayfairDisplay-Bold", size: 24))
                                .foregroundColor(.primary)
                            Text("Complete your first challenge to see it here!")
                                .font(.custom("PlayfairDisplay-Regular", size: 18))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    // Journal-style entries
                    VStack(alignment: .leading, spacing: 40) {
                        ForEach(pastChallenges) { challenge in
                            JournalEntryView(challenge: challenge)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemBackground))
        .navigationBarItems(
            trailing: Button("Done") {
                dismiss()
            }
            .font(.custom("PlayfairDisplay-Regular", size: 18))
        )
    }
}

struct JournalEntryView: View {
    let challenge: PastChallenge
    
    var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()
    
    var completionColor: Color {
        let percentage = challenge.completionRate
        switch percentage {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Date and Duration
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateFormatter.string(from: challenge.completedDate))
                        .font(.custom("PlayfairDisplay-SemiBold", size: 22))
                        .foregroundColor(.primary)
                    Text("\(challenge.duration) Day Journey")
                        .font(.custom("PlayfairDisplay-Regular", size: 17))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Completion Circle
                ZStack {
                    Circle()
                        .stroke(Color(UIColor.systemGray5), lineWidth: 3)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: challenge.completionRate)
                        .stroke(completionColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(challenge.completionRate * 100))%")
                        .font(.custom("PlayfairDisplay-Medium", size: 14))
                        .foregroundColor(completionColor)
                }
            }
            
            // Goals Section
            if !challenge.goals.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Goals Pursued")
                        .font(.custom("PlayfairDisplay-Regular", size: 18))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(challenge.goals) { goal in
                            HStack(spacing: 12) {
                                Text(goal.emoji)
                                    .font(.system(size: 20))
                                Text(goal.title)
                                    .font(.custom("PlayfairDisplay-Regular", size: 17))
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            
            // Journal Entries Preview
            if !challenge.journalEntries.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Journal Reflections")
                        .font(.custom("PlayfairDisplay-Regular", size: 18))
                        .foregroundColor(.secondary)
                    
                    Text(challenge.journalEntries.first?.content ?? "")
                        .font(.custom("PlayfairDisplay-Regular", size: 16))
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(UIColor.systemGray5), lineWidth: 1)
        )
    }
}

struct PastChallengesView_Previews: PreviewProvider {
    static var previews: some View {
        PastChallengesView()
    }
} 
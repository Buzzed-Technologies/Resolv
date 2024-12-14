import SwiftUI

struct DurationSelectionView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedDays: Double = 21
    @State private var lastSliderValue: Double = 21
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 24) {
                Text("How long do you want to build these habits?")
                    .font(.custom("Baskerville-Bold", size: 34))
                    .foregroundColor(.appText)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 40)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                
                Text("Research shows it takes at least 21 days to form a new habit.")
                    .font(.system(size: 17))
                    .foregroundColor(.appTextSecondary)
                    .padding(.horizontal)
                    .minimumScaleFactor(0.8)
                    .lineLimit(2)
                
                VStack(alignment: .leading, spacing: 24) {
                    // Duration Selection
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("\(Int(selectedDays))")
                                .font(.custom("Baskerville-Bold", size: 40))
                                .foregroundColor(.appText)
                                .minimumScaleFactor(0.8)
                            Text("days")
                                .font(.system(size: 34))
                                .foregroundColor(.appTextSecondary)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal)
                        
                        Slider(value: $selectedDays, in: 21...90, step: 1)
                            .tint(.appAccent)
                            .padding(.horizontal)
                            .onChange(of: selectedDays) { newValue in
                                viewModel.updatePlanDuration(Int(newValue))
                                if abs(newValue - lastSliderValue) >= 1 {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    lastSliderValue = newValue
                                }
                            }
                    }
                    // Notifications
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Would you like reminders?")
                            .font(.custom("Baskerville-Bold", size: 24))
                            .foregroundColor(.appText)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ForEach(NotificationPreference.allCases, id: \.self) { preference in
                                NotificationOptionCard(
                                    preference: preference,
                                    isSelected: viewModel.userData.notificationPreference == preference
                                ) {
                                    viewModel.updateNotificationPreference(preference)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                Button(action: {
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
                    .background(Color.black)
                    .cornerRadius(28)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            selectedDays = Double(viewModel.userData.planDuration)
            lastSliderValue = selectedDays
        }
    }
}

struct NotificationOptionCard: View {
    let preference: NotificationPreference
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            
            // Request notification permissions if needed
            if preference != .never {
                Task {
                    do {
                        _ = try await NotificationManager.shared.requestAuthorization()
                    } catch {
                        print("Error requesting notification authorization: \(error)")
                    }
                }
            }
            
            action()
        }) {
            HStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.system(size: 22))
                    .foregroundColor(.appAccent)
                    .frame(width: 44, height: 44)
                    .background(Color.appSecondary)
                    .cornerRadius(22)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(preference.rawValue)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.appText)
                    Text(description)
                        .font(.system(size: 15))
                        .foregroundColor(.appTextSecondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.appAccent)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.appAccent : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconName: String {
        switch preference {
        case .never:
            return "bell.slash"
        case .occasionally:
            return "bell.badge"
        case .often:
            return "bell.and.waves.left.and.right"
        }
    }
    private var description: String {
        switch preference {
        case .never:
            return "I'll check the app on my own"
        case .occasionally:
            return "Get a few reminders each day"
        case .often:
            return "Get frequent daily reminders"
        }
    }
} 
import SwiftUI

struct UserPreferencesView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var name: String = ""
    @State private var wakeTime = Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var sleepTime = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var showingWakeTimePicker = false
    @State private var showingSleepTimePicker = false
    @FocusState private var isNameFocused: Bool
    
    private let haptics = UIImpactFeedbackGenerator(style: .light)
    
    private func TimePickerCell(
        title: String,
        time: Binding<Date>,
        isExpanded: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.custom("Baskerville-Bold", size: 20))
                .foregroundColor(.appText)
            
            VStack(spacing: 0) {
                Button(action: {
                    haptics.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.wrappedValue.toggle()
                    }
                }) {
                    HStack {
                        Text(formattedTime(time.wrappedValue))
                            .font(.system(size: 17))
                            .foregroundColor(.appText)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.green)
                            .rotationEffect(.degrees(isExpanded.wrappedValue ? 180 : 0))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .padding(.horizontal, 16)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(isExpanded.wrappedValue ? 12 : 12)
                }
                
                if isExpanded.wrappedValue {
                    DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                        .offset(y: -12) // Overlap with the button above
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .move(edge: .top))
                            )
                        )
                        .zIndex(-1) // Ensure it appears behind the button
                }
            }
            .background(
                Color(UIColor.systemGray6)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
            )
        }
    }
    
    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    isNameFocused = false
                }
            
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Let's personalize your schedule")
                        .font(.custom("Baskerville-Bold", size: 34))
                        .foregroundColor(.appText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 40)
                    
                    Text("We'll use this to create your daily plan.")
                        .font(.system(size: 17))
                        .foregroundColor(.appTextSecondary)
                }
                .padding(.horizontal)
                
                // Main Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Name Input
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What's your name?")
                                .font(.custom("Baskerville-Bold", size: 20))
                                .foregroundColor(.appText)
                            
                            TextField("", text: $name)
                                .font(.system(size: 17))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .padding(.horizontal, 16)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                                .focused($isNameFocused)
                                .overlay(
                                    Text(name.isEmpty ? "Enter your name" : "")
                                        .font(.system(size: 17))
                                        .foregroundColor(.appTextSecondary.opacity(0.7))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 16)
                                        .allowsHitTesting(false)
                                )
                        }
                        
                        // Wake Time
                        TimePickerCell(
                            title: "When do you usually wake up?",
                            time: $wakeTime,
                            isExpanded: $showingWakeTimePicker
                        )
                        
                        // Sleep Time
                        TimePickerCell(
                            title: "When do you usually go to sleep?",
                            time: $sleepTime,
                            isExpanded: $showingSleepTimePicker
                        )
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                Button(action: {
                    haptics.impactOccurred()
                    viewModel.updateUserPreferences(
                        name: name,
                        wakeTime: wakeTime,
                        sleepTime: sleepTime
                    )
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
        .background(Color.appBackground)
        .padding(.top, 20)
        .preferredColorScheme(.light)
        .ignoresSafeArea(.keyboard)
        .onAppear {
            if let savedName = viewModel.userData.name {
                name = savedName
            }
            if let savedWakeTime = viewModel.userData.wakeTime {
                wakeTime = savedWakeTime
            }
            if let savedSleepTime = viewModel.userData.sleepTime {
                sleepTime = savedSleepTime
            }
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
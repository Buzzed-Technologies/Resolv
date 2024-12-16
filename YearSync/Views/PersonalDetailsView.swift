import SwiftUI

struct PersonalDetailsView: View {
    @Binding var userData: UserData
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var age: String = ""
    @State private var heightFeet: String = ""
    @State private var heightInches: String = ""
    @State private var weight: String = ""
    @State private var wakeTime: Date = Calendar.current.startOfDay(for: Date())
    @State private var sleepTime: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedGoal: Goal?
    @State private var showingGoalEditor = false
    @State private var notificationPreference: NotificationPreference = .occasionally
    
    // Add this property to track keyboard focus
    @FocusState private var focusedField: Bool
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Header
                    Text("Personal Details")
                        .font(.custom("PlayfairDisplay-Bold", size: 32))
                        .foregroundColor(.black)
                        .padding(.horizontal)
                    
                    // Main Content
                    VStack(alignment: .leading, spacing: 40) {
                        // Personal Information Section
                        VStack(alignment: .leading, spacing: 24) {
                            Text("About You")
                                .font(.custom("PlayfairDisplay-Regular", size: 24))
                                .foregroundColor(.black)
                            
                            // Name and Age
                            HStack(spacing: 20) {
                                JournalTextField(title: "Name", text: $name, keyboardType: .default)
                                JournalTextField(title: "Age", text: $age, keyboardType: .numberPad)
                                    .frame(width: 100)
                            }
                            
                            // Height and Weight
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Height")
                                        .font(.custom("PlayfairDisplay-Regular", size: 16))
                                        .foregroundColor(.black.opacity(0.6))
                                    HStack(spacing: 12) {
                                        JournalNumberField(text: $heightFeet, unit: "ft", width: 70)
                                        JournalNumberField(text: $heightInches, unit: "in", width: 70)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Weight")
                                        .font(.custom("PlayfairDisplay-Regular", size: 16))
                                        .foregroundColor(.black.opacity(0.6))
                                    JournalNumberField(text: $weight, unit: "lbs", width: 100)
                                }
                            }
                        }
                        
                        // Daily Schedule Section
                        VStack(alignment: .leading, spacing: 24) {
                            Text("Daily Rhythm")
                                .font(.custom("PlayfairDisplay-Regular", size: 24))
                                .foregroundColor(.black)
                            
                            VStack(spacing: 20) {
                                JournalTimePicker(title: "Wake Time", selection: $wakeTime)
                                JournalTimePicker(title: "Sleep Time", selection: $sleepTime)
                            }
                        }
                        
                        // Notification Settings
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Reminders")
                                .font(.custom("PlayfairDisplay-Regular", size: 24))
                                .foregroundColor(.black)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("How often would you like to be reminded?")
                                    .font(.custom("PlayfairDisplay-Regular", size: 16))
                                    .foregroundColor(.black.opacity(0.6))
                                
                                HStack(spacing: 16) {
                                    ForEach(NotificationPreference.allCases, id: \.self) { preference in
                                        Button(action: {
                                            notificationPreference = preference
                                        }) {
                                            Text(preference.rawValue)
                                                .font(.custom("PlayfairDisplay-Regular", size: 16))
                                                .foregroundColor(notificationPreference == preference ? .black : .black.opacity(0.6))
                                                .padding(.bottom, 4)
                                                .overlay(
                                                    Rectangle()
                                                        .frame(height: 1)
                                                        .foregroundColor(notificationPreference == preference ? .black : .clear),
                                                    alignment: .bottom
                                                )
                                        }
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                        
                        // Goals Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Your Goals")
                                .font(.custom("PlayfairDisplay-Regular", size: 24))
                                .foregroundColor(.black)
                            
                            VStack(spacing: 12) {
                                ForEach(userData.goals) { goal in
                                    Button(action: {
                                        selectedGoal = goal
                                        showingGoalEditor = true
                                    }) {
                                        HStack(spacing: 12) {
                                            Text(goal.emoji)
                                                .font(.system(size: 24))
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(goal.title)
                                                    .font(.custom("PlayfairDisplay-Regular", size: 18))
                                                    .foregroundColor(.black)
                                                Text("\(goal.subPlans.count) steps")
                                                    .font(.custom("PlayfairDisplay-Regular", size: 14))
                                                    .foregroundColor(.black.opacity(0.6))
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.black.opacity(0.4))
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .padding(.vertical, 12)
                                    }
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 20)
                .padding(.bottom, 80)
            }
            .onTapGesture {
                focusedField = false // Dismiss keyboard on tap
            }
            
            // Floating button
            VStack {
                Spacer()
                ModernButton(title: "Save Changes") {
                    saveChanges()
                    dismiss()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationBarItems(
            leading: Button("Cancel") {
                dismiss()
            }
        )
        .sheet(isPresented: $showingGoalEditor, content: {
            if let goal = selectedGoal {
                EditGoalView(userData: $userData, goal: goal)
            }
        })
        .onAppear {
            loadUserData()
        }
    }
    
    private func loadUserData() {
        name = userData.name ?? ""
        age = userData.age.map { String($0) } ?? ""
        notificationPreference = userData.notificationPreference
        
        if let heightInCm = userData.height {
            let totalInches = heightInCm / 2.54
            let feet = Int(totalInches / 12)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
            heightFeet = String(feet)
            heightInches = String(inches)
        }
        
        if let weightInKg = userData.weight {
            let weightInLbs = weightInKg * 2.20462
            weight = String(format: "%.0f", weightInLbs)
        }
        
        wakeTime = userData.wakeTime ?? Calendar.current.startOfDay(for: Date())
        sleepTime = userData.sleepTime ?? Calendar.current.startOfDay(for: Date())
    }
    
    private func saveChanges() {
        var updatedUserData = userData
        updatedUserData.name = name.isEmpty ? nil : name
        updatedUserData.age = Int(age)
        updatedUserData.notificationPreference = notificationPreference
        
        if let feet = Int(heightFeet), let inches = Int(heightInches) {
            let totalInches = (feet * 12) + inches
            let heightInCm = Double(totalInches) * 2.54
            updatedUserData.height = heightInCm
        }
        
        if let weightInLbs = Double(weight) {
            let weightInKg = weightInLbs / 2.20462
            updatedUserData.weight = weightInKg
        }
        
        updatedUserData.wakeTime = wakeTime
        updatedUserData.sleepTime = sleepTime
        userData = updatedUserData
    }
}

// Custom Components
struct JournalTextField: View {
    let title: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("PlayfairDisplay-Regular", size: 16))
                .foregroundColor(.black.opacity(0.6))
            TextField("", text: $text)
                .keyboardType(keyboardType)
                .font(.custom("PlayfairDisplay-Regular", size: 18))
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isFocused)
                .padding(.bottom, 8)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.black.opacity(0.2)),
                    alignment: .bottom
                )
        }
    }
}

struct JournalNumberField: View {
    @Binding var text: String
    let unit: String
    let width: CGFloat
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            TextField("0", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: width - 30)
                .font(.custom("PlayfairDisplay-Regular", size: 18))
                .focused($isFocused)
            Text(unit)
                .font(.custom("PlayfairDisplay-Regular", size: 16))
                .foregroundColor(.black.opacity(0.6))
        }
        .padding(.bottom, 8)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.black.opacity(0.2)),
            alignment: .bottom
        )
    }
}

struct JournalTimePicker: View {
    let title: String
    @Binding var selection: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("PlayfairDisplay-Regular", size: 16))
                .foregroundColor(.black.opacity(0.6))
            
            DatePicker("", selection: $selection, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(.bottom, 8)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.black.opacity(0.2)),
                    alignment: .bottom
                )
        }
    }
}

struct PersonalDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        PersonalDetailsView(userData: .constant(UserData()))
    }
} 
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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("Personal Details")
                    .font(.custom("PlayfairDisplay-Regular", size: 28))
                    .foregroundColor(.black)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                
                // Main Content
                Group {
                    // Personal Information Section
                    SectionView(title: "") {
                        VStack(spacing: 16) {
                            // Name and Age in one row
                            HStack(spacing: 12) {
                                CompactTextField(title: "Name", text: $name, keyboardType: .default)
                                CompactTextField(title: "Age", text: $age, keyboardType: .numberPad)
                                    .frame(width: 100)
                            }
                            
                            // Height and Weight in one row
                            HStack(spacing: 12) {
                                // Height Fields
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Height")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 8) {
                                        CompactNumberField(text: $heightFeet, unit: "ft", width: 70)
                                        CompactNumberField(text: $heightInches, unit: "in", width: 70)
                                    }
                                }
                                
                                Spacer()
                                
                                // Weight Field
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Weight")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    CompactNumberField(text: $weight, unit: "lbs", width: 100)
                                }
                            }
                        }
                    }
                    
                    // Daily Schedule Section
                    SectionView(title: "Daily Schedule") {
                        VStack(spacing: 16) {
                            CompactTimePicker(title: "Wake Time", selection: $wakeTime)
                            CompactTimePicker(title: "Sleep Time", selection: $sleepTime)
                        }
                    }
                    
                    // Current Goals Section
                    SectionView(title: "Current Goals") {
                        VStack(spacing: 12) {
                            ForEach(userData.goals) { goal in
                                Button(action: {
                                    selectedGoal = goal
                                    showingGoalEditor = true
                                }) {
                                    HStack(spacing: 12) {
                                        Text(goal.emoji)
                                            .font(.system(size: 22))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(goal.title)
                                                .font(.system(size: 17, weight: .medium))
                                                .foregroundColor(.primary)
                                            Text("\(goal.subPlans.count) steps")
                                                .font(.system(size: 13))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.green)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 14)
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                    
                    // Save Button
                    ModernButton(title: "Save Changes") {
                        saveChanges()
                        dismiss()
                    }
                    .padding(.top, 20)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 20)
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

// MARK: - Custom Components

struct SectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            content
        }
    }
}

struct CompactTextField: View {
    let title: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("", text: $text)
                .keyboardType(keyboardType)
                .padding(10)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
        }
    }
}

struct CompactNumberField: View {
    @Binding var text: String
    let unit: String
    let width: CGFloat
    
    var body: some View {
        HStack(spacing: 4) {
            TextField("0", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: width - 30)
            Text(unit)
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
        .padding(10)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
    }
}

struct CompactTimePicker: View {
    let title: String
    @Binding var selection: Date
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            DatePicker("", selection: $selection, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
        }
        .padding(10)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
    }
}

struct PersonalDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        PersonalDetailsView(userData: .constant(UserData()))
    }
} 
import SwiftUI
import UIKit

struct PersonalInfoView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var sex: String = ""
    @State private var age: String = ""
    @State private var weight: Double = 134 // Default value
    @State private var heightFeet: Double = 5 // Default value
    @State private var heightInches: Double = 8 // Default value
    @FocusState private var isAgeFocused: Bool
    
    private let sexOptions = ["Male", "Female", "Other"]
    
    // Add these constants
    private let weightRange: ClosedRange<Double> = 50...300
    private let feetRange: ClosedRange<Double> = 4...7
    private let inchesRange: ClosedRange<Double> = 0...11
    
    // Add haptic feedback manager
    private let haptics = UIImpactFeedbackGenerator(style: .light)
    
    // Custom slider style to hide the default thumb
    private struct CustomSlider: View {
        @Binding var value: Double
        let range: ClosedRange<Double>
        let step: Double
        let showScale: Bool
        let scaleStep: Int
        let unit: String
        let isHeight: Bool
        @State private var isDragging = false
        
        private func formatLabel(_ value: Double) -> String {
            if isHeight {
                let feet = Int(value) / 12
                let inches = Int(value) % 12
                return "\(feet)'\(inches)\""
            } else {
                return "\(Int(value)) \(unit)"
            }
        }
        
        var body: some View {
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background with tick marks
                        HStack(spacing: geometry.size.width / CGFloat(range.upperBound - range.lowerBound) * CGFloat(scaleStep - 1)) {
                            ForEach(Array(stride(from: range.lowerBound, through: range.upperBound, by: Double(scaleStep))), id: \.self) { index in
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 1, height: 12)
                            }
                        }
                        
                        // Highlighted section
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: (geometry.size.width) * (value - range.lowerBound) / (range.upperBound - range.lowerBound))
                            .frame(height: 28)
                        
                        // Green line indicator
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: 2, height: 28)
                            .offset(x: (geometry.size.width) * (value - range.lowerBound) / (range.upperBound - range.lowerBound))
                        
                        // Gesture area
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: geometry.size.width, height: 28)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { gesture in
                                        isDragging = true
                                        let width = geometry.size.width
                                        let xLocation = min(max(0, gesture.location.x), width)
                                        let percentage = xLocation / width
                                        let rangeDistance = range.upperBound - range.lowerBound
                                        let newValue = range.lowerBound + (rangeDistance * percentage)
                                        self.value = min(range.upperBound, max(range.lowerBound, round(newValue / step) * step))
                                    }
                                    .onEnded { _ in
                                        isDragging = false
                                    }
                            )
                    }
                }
                .frame(height: 28)
                
                // Scale labels
                if showScale {
                    HStack {
                        Text(formatLabel(range.lowerBound))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text(formatLabel(range.upperBound))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .frame(height: 20)
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            // Add tap gesture to dismiss keyboard
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    isAgeFocused = false
                }
            
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tell us about yourself")
                        .font(.custom("Baskerville-Bold", size: 34))
                        .foregroundColor(.appText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 40)
                    
                    Text("This helps us personalize your plan. All fields are optional.")
                        .font(.system(size: 17))
                        .foregroundColor(.appTextSecondary)
                }
                .padding(.horizontal)
                
                // Main Content
                VStack(spacing: 24) {
                    // Age Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Age")
                            .font(.custom("Baskerville-Bold", size: 20))
                            .foregroundColor(.appText)
                        
                        HStack {
                            TextField("", text: $age)
                                .font(.system(size: 17))
                                .keyboardType(.numberPad)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .padding(.horizontal, 16)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                                .focused($isAgeFocused)
                                .overlay(
                                    Text(age.isEmpty ? "69" : "")
                                        .font(.system(size: 17))
                                        .foregroundColor(.appTextSecondary.opacity(0.7))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 16)
                                        .allowsHitTesting(false)
                                )
                        }
                    }
                    
                    // Sex Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sex")
                            .font(.custom("Baskerville-Bold", size: 20))
                            .foregroundColor(.appText)
                        
                        HStack(spacing: 12) {
                            ForEach(sexOptions, id: \.self) { option in
                                Button(action: {
                                    haptics.impactOccurred()
                                    sex = option
                                }) {
                                    HStack {
                                        Text(option)
                                            .font(.system(size: 17))
                                            .foregroundColor(.appText)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(sex == option ? Color.appAccent : Color.clear, lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    
                    // Weight Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Weight")
                            .font(.custom("Baskerville-Bold", size: 20))
                            .foregroundColor(.appText)
                        
                        VStack(spacing: 16) {
                            Text("\(Int(weight)) lbs")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.appText)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            CustomSlider(
                                value: $weight,
                                range: weightRange,
                                step: 1,
                                showScale: true,
                                scaleStep: 10,
                                unit: "",
                                isHeight: false
                            )
                        }
                    }
                    
                    // Height Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Height")
                            .font(.custom("Baskerville-Bold", size: 20))
                            .foregroundColor(.appText)
                        
                        VStack(spacing: 16) {
                            Text("\(Int(heightFeet))'\(Int(heightInches))\"")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.appText)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            CustomSlider(
                                value: Binding(
                                    get: { heightFeet * 12 + heightInches },
                                    set: { totalInches in
                                        heightFeet = Double(Int(totalInches) / 12)
                                        heightInches = Double(Int(totalInches) % 12)
                                    }
                                ),
                                range: (feetRange.lowerBound * 12)...(feetRange.upperBound * 12 + 11),
                                step: 1,
                                showScale: true,
                                scaleStep: 12,
                                unit: "",
                                isHeight: true
                            )
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Next Button
                Button(action: {
                    haptics.impactOccurred()
                    savePersonalInfo()
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
        .ignoresSafeArea(.keyboard) // Prevent view from being pushed up
    }
    
    private func savePersonalInfo() {
        if !sex.isEmpty {
            viewModel.userData.sex = sex
        }
        if let ageInt = Int(age) {
            viewModel.userData.age = ageInt
        }
        
        // Convert feet and inches to centimeters
        let totalInches = (heightFeet * 12.0) + heightInches
        let centimeters = totalInches * 2.54
        viewModel.userData.height = centimeters
        
        // Convert pounds to kilograms
        let kilograms = weight * 0.453592
        viewModel.userData.weight = kilograms
    }
} 
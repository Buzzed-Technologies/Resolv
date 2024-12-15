import SwiftUI
import CoreText

struct WelcomeView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var isAnimating = false
    
    private let accentGreen = Color(red: 76/255, green: 175/255, blue: 80/255)
    private let textPrimary = Color.black
    private let textSecondary = Color(UIColor.systemGray)
    
    var body: some View {
        VStack {
            Spacer()
            
            // Logo and App Name Section
            VStack(spacing: 24) {
                // Animated Gradient Circle
                AnimatedGradientCircle(
                    size: 180,
                    primaryColor: accentGreen
                )
                
                Text("Resolv")
                    .font(.custom("PlayfairDisplay-Regular", size: 56))
                    .foregroundColor(textPrimary)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
                
                Text("Build better habits, one day at a time")
                    .font(.custom("PlayfairDisplay-Regular", size: 17))
                    .foregroundColor(textSecondary)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 10)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
            
            ModernButton(title: "Get Started") {
                viewModel.moveToNextScreen()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
            .opacity(isAnimating ? 1 : 0)
            .offset(y: isAnimating ? 0 : 20)
        }
        .background(Color.white)
        .environment(\.colorScheme, .light)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
        }
    }
} 
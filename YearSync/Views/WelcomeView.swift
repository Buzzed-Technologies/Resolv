import SwiftUI
import CoreText

struct WelcomeView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var isAnimating = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.3
    
    private let accentGreen = Color(red: 76/255, green: 175/255, blue: 80/255) // Material Design Green
    private let textPrimary = Color.black
    private let textSecondary = Color(UIColor.systemGray)
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo and App Name Section
            VStack(spacing: 20) {
                // Animated Logo
                ZStack {
                    Circle()
                        .fill(accentGreen.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .shadow(color: accentGreen.opacity(0.3), radius: 20, x: 0, y: 0)
                }
                .padding(.top, 60)
                .onAppear {
                    withAnimation(
                        Animation.easeInOut(duration: 1.2)
                            .repeatForever(autoreverses: true)
                    ) {
                        logoScale = 1.0
                        logoOpacity = 0.6
                    }
                }
                
                Text("Resolv")
                    .font(.custom("Baskerville-Bold", size: 56))
                    .foregroundColor(textPrimary)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
                
                Text("Build better habits, one day at a time")
                    .font(.system(size: 17))
                    .foregroundColor(textSecondary)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 10)
                    .padding(.bottom, 40)
            }
            
            // Features Section
            VStack(spacing: 20) {
                ForEach(Array(zip(features.indices, features)), id: \.0) { index, feature in
                    FeatureRow(
                        icon: feature.icon,
                        title: feature.title,
                        description: feature.description,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        accentGreen: accentGreen
                    )
                    .opacity(isAnimating ? 1 : 0)
                    .offset(x: isAnimating ? 0 : -30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)
                        .delay(Double(index) * 0.2), value: isAnimating)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Get Started Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation {
                    viewModel.moveToNextScreen()
                }
            }) {
                Text("Get Started")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 29)
                            .fill(textPrimary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 29)
                                    .stroke(accentGreen.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .shadow(color: accentGreen.opacity(0.2), radius: 8, x: 0, y: 4)
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
    
    // Feature data
    private let features = [
        (icon: "brain.head.profile", title: "AI-Powered Planning", description: "Smart schedules that adapt to your goals"),
        (icon: "chart.line.uptrend.xyaxis", title: "Progress Tracking", description: "Monitor your journey with insights"),
        (icon: "sparkles", title: "Daily Motivation", description: "Stay inspired and focused")
    ]
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let textPrimary: Color
    let textSecondary: Color
    let accentGreen: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(accentGreen)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(Color(UIColor.systemGray6))
                        .overlay(
                            Circle()
                                .stroke(accentGreen.opacity(0.3), lineWidth: 1)
                        )
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Baskerville-Bold", size: 17))
                    .foregroundColor(textPrimary)
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(accentGreen.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: accentGreen.opacity(0.05), radius: 8, x: 0, y: 2)
    }
} 
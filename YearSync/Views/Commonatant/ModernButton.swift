// ModernButton.swift
import SwiftUI

struct ModernButton: View {
    let title: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isPressed = false
                    action()
                }
            }
        }) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    ZStack {
                        // Deep layer (darkest)
                        Capsule()
                            .fill(Color.black.opacity(0.8))
                            .offset(y: 6)
                        
                        // Middle layer
                        Capsule()
                            .fill(Color.black.opacity(0.9))
                            .offset(y: 3)
                        
                        // Top layer
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(white: 0.3),
                                        Color.black
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        // Glossy overlay
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.25),
                                        Color.clear
                                    ]),
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .padding(2)
                    }
                )
        }
        .scaleEffect(isPressed ? 0.95 : 1)
        .offset(y: isPressed ? 6 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}

// Preview Provider
#Preview {
    VStack {
        ModernButton(title: "Get Started") {
            print("Button tapped")
        }
        .padding()
    }
}
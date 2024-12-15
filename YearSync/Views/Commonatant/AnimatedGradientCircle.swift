// AnimatedGradientCircle.swift
import SwiftUI

struct AnimatedGradientCircle: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.3
    
    var size: CGFloat = 180
    var primaryColor: Color = Color(red: 76/255, green: 175/255, blue: 80/255)
    
    var body: some View {
        ZStack {
            // Outer blurred circle for fade effect
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            primaryColor.opacity(0.2),
                            primaryColor.opacity(0)
                        ]),
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size * 1.5, height: size * 1.5)
                .blur(radius: 20)
            
            // Main gradient circle
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            primaryColor.opacity(0.7),
                            primaryColor.opacity(0.3),
                            primaryColor.opacity(0.1)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)
                .scaleEffect(scale)
                .opacity(opacity)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .white.opacity(0.5),
                                    .clear
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .scaleEffect(0.98)
                        .blur(radius: 1)
                )
        }
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
            ) {
                scale = 1.0
                opacity = 0.6
            }
        }
    }
}

#Preview {
    ZStack {
        Color.white
        AnimatedGradientCircle()
    }
}
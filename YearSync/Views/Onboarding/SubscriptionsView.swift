import SwiftUI
import StoreKit

struct SubscriptionsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @StateObject private var storeManager = StoreKitManager.shared
    @State private var selectedPlan: SubscriptionPlan?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Centered Header
                VStack(alignment: .center, spacing: 8) {
                    Text("Choose Your Plan")
                        .font(.custom("PlayfairDisplay-Regular", size: 34))
                        .foregroundColor(.appText)
                        .multilineTextAlignment(.center)
                    
                    Text("Start your journey to better habits")
                        .font(.custom("PlayfairDisplay-Regular", size: 17))
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                // Enhanced 3D Bouncing App Icon
                Image("AppLogo")
                    .resizable()
                    .frame(width: 140, height: 140)
                    .cornerRadius(32)
                    .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 8)
                    .rotation3DEffect(
                        .degrees(10),
                        axis: (x: 1, y: 0, z: 0)
                    )
                    .modifier(BouncingAnimation())
                    .padding(.bottom, 20)
                
                // Subscription Plans
                VStack(spacing: 16) {
                    // Yearly Plan
                    PlanCard(
                        plan: .trial,
                        isSelected: selectedPlan == .trial,
                        onSelect: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            selectedPlan = .trial
                        }
                    )
                    
                    // Monthly Plan
                    PlanCard(
                        plan: .monthly,
                        isSelected: selectedPlan == .monthly,
                        onSelect: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            selectedPlan = .monthly
                        }
                    )
                }
                .padding(.horizontal, 24)
                
                if let error = storeManager.lastPurchaseError {
                    Text(error)
                        .font(.custom("PlayfairDisplay-Regular", size: 14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                Spacer()
                
                // Continue Button
                ModernButton(title: storeManager.isPurchasing ? "Processing..." : "Continue") {
                    guard let plan = selectedPlan else { return }
                    Task {
                        do {
                            if let product = storeManager.product(for: plan) {
                                try await storeManager.purchase(product)
                                
                                // Only proceed if we're actually subscribed
                                if storeManager.isSubscribed {
                                    viewModel.userData.planStartDate = Date()
                                    withAnimation {
                                        viewModel.moveToNextScreen()
                                    }
                                } else {
                                    showError = true
                                    errorMessage = "Subscription verification failed. Please try again."
                                }
                            } else {
                                showError = true
                                errorMessage = "Selected subscription is not available"
                            }
                        } catch {
                            showError = true
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .disabled(selectedPlan == nil || storeManager.isPurchasing)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Color.appBackground)
        .preferredColorScheme(.light)
        .alert("Subscription Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Verify subscription status on appear
            Task {
                await storeManager.updateSubscriptionStatus()
            }
        }
    }
}

// Enhanced bouncing animation
struct BouncingAnimation: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .offset(y: isAnimating ? -15 : 0)
            .animation(
                Animation.easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// Updated PlanCard
private struct PlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if plan == .trial {
                            Text("🌟 MOST POPULAR")
                                .font(.custom("PlayfairDisplay-Regular", size: 12))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        Text(plan == .trial ? "Annual Plan" : "Monthly Plan")
                            .font(.custom("PlayfairDisplay-Regular", size: 20))
                            .foregroundColor(.appText)
                    }
                    
                    Spacer()
                    
                    Text(plan == .trial ? "$29.99/year" : "$4.99/month")
                        .font(.custom("PlayfairDisplay-Regular", size: 20))
                        .foregroundColor(.appText)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    if plan == .trial {
                        BenefitRow(text: "Save 50% vs monthly plan", icon: "dollarsign.circle.fill")
                        BenefitRow(text: "3-day free trial included", icon: "gift.fill")
                        BenefitRow(text: "Cancel anytime", icon: "checkmark.shield.fill")
                    } else {
                        BenefitRow(text: "Flexible monthly billing", icon: "calendar")
                        BenefitRow(text: "Cancel anytime", icon: "checkmark.shield.fill")
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.green : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )
            )
            .shadow(color: isSelected ? Color.green.opacity(0.1) : Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Add this helper view for consistent benefit rows
struct BenefitRow: View {
    let text: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(text)
                .font(.custom("PlayfairDisplay-Regular", size: 15))
                .foregroundColor(.appTextSecondary)
        }
    }
}

#Preview {
    SubscriptionsView()
        .environmentObject(AppViewModel())
} 
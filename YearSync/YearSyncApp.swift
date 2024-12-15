//
//  YearSyncApp.swift
//  YearSync
//
//  Created by Jack on 12/14/24.
//

import SwiftUI

@main
struct YearSyncApp: App {
    init() {
        CustomFont.registerFonts()
    }
    
    @StateObject private var viewModel = AppViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    
    var body: some View {
        Group {
            switch viewModel.currentScreen {
            case .welcome:
                WelcomeView()
            case .goalSelection:
                GoalSelectionView()
            case .durationSelection:
                DurationSelectionView()
            case .subscriptions:
                SubscriptionsView()
            case .planCreation:
                PlanCreationView()
            case .dailyChecklist:
                DailyChecklistView()
            }
        }
        .animation(.easeInOut, value: viewModel.currentScreen)
        .transition(.slide)
    }
}

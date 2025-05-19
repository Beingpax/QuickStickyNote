import SwiftUI

struct ContentView: View {
    @StateObject private var notesManager = NotesManager.shared
    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var isShowingOnboarding = false
    
    var body: some View {
        Group {
            if !notesManager.isDirectoryConfigured || !onboardingManager.hasCompletedOnboarding {
                OnboardingView()
            } else {
                HomeView()
            }
        }
        .onChange(of: notesManager.isDirectoryConfigured) { isConfigured in
            if isConfigured {
                onboardingManager.completeOnboarding()
            }
        }
    }
} 
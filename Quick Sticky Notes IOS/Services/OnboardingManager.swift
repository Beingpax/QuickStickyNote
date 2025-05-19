import Foundation

@MainActor
class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()
    
    private let defaults = UserDefaults.standard
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    
    @Published private(set) var hasCompletedOnboarding: Bool
    
    private init() {
        self.hasCompletedOnboarding = defaults.bool(forKey: hasCompletedOnboardingKey)
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: hasCompletedOnboardingKey)
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
        defaults.set(false, forKey: hasCompletedOnboardingKey)
    }
} 
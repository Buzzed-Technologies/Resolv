import Foundation

class UserDefaultsHelper {
    static let shared = UserDefaultsHelper()
    
    private let userDataKey = "userData"
    private let goalsKey = "userGoals"
    private let challengeDaysKey = "challengeDays"
    private let userDetailsKey = "userDetails"
    
    private init() {}
    
    // Save complete UserData
    func saveUserData(_ userData: UserData) {
        if let encoded = try? JSONEncoder().encode(userData) {
            UserDefaults.standard.set(encoded, forKey: userDataKey)
        }
    }
    
    // Load complete UserData
    func loadUserData() -> UserData? {
        guard let data = UserDefaults.standard.data(forKey: userDataKey),
              let userData = try? JSONDecoder().decode(UserData.self, from: data) else {
            return nil
        }
        return userData
    }
    
    // Check if plan is active and not expired
    func hasActivePlan() -> Bool {
        guard let userData = loadUserData(),
              let startDate = userData.planStartDate else {
            return false
        }
        
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: userData.planDuration, to: startDate)!
        return Date() <= endDate
    }
    
    // Legacy methods
    func saveGoals(_ goals: [String]) {
        UserDefaults.standard.set(goals, forKey: goalsKey)
    }
    
    func getGoals() -> [String] {
        return UserDefaults.standard.stringArray(forKey: goalsKey) ?? []
    }
    
    func saveChallengeDays(_ days: Int) {
        UserDefaults.standard.set(days, forKey: challengeDaysKey)
    }
    
    func getChallengeDays() -> Int {
        return UserDefaults.standard.integer(forKey: challengeDaysKey)
    }
    
    func saveUserDetails(_ details: [String: String]) {
        UserDefaults.standard.set(details, forKey: userDetailsKey)
    }
    
    func getUserDetails() -> [String: String] {
        return UserDefaults.standard.dictionary(forKey: userDetailsKey) as? [String: String] ?? [:]
    }
    
    // Clear all data
    func clearAllData() {
        UserDefaults.standard.removeObject(forKey: userDataKey)
        UserDefaults.standard.removeObject(forKey: goalsKey)
        UserDefaults.standard.removeObject(forKey: challengeDaysKey)
        UserDefaults.standard.removeObject(forKey: userDetailsKey)
    }
} 
import Foundation

class UserDefaultsHelper {
    static let shared = UserDefaultsHelper()
    
    private let goalsKey = "userGoals"
    private let challengeDaysKey = "challengeDays"
    private let userDetailsKey = "userDetails"
    
    private init() {}
    
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
} 
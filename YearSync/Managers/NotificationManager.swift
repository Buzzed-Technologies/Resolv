import UserNotifications
import SwiftUI

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private override init() {
        super.init()
        notificationCenter.delegate = self
    }
    
    func requestAuthorization() async throws -> Bool {
        try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
    }
    
    func scheduleNotifications(for preference: NotificationPreference, userData: UserData) async {
        // Remove all pending notifications first
        await notificationCenter.removeAllPendingNotificationRequests()
        
        guard preference != .never else { return }
        
        // Get wake and sleep times
        guard let wakeTime = userData.wakeTime,
              let sleepTime = userData.sleepTime else { return }
        
        let calendar = Calendar.current
        
        // Schedule morning notification (30 minutes after wake time)
        let morningTime = calendar.date(byAdding: .minute, value: 30, to: wakeTime)!
        await scheduleDailyNotification(
            at: morningTime,
            title: "Good Morning, \(userData.name ?? "")!",
            body: "You're on Day \(userData.currentDay ?? 1) of your \(userData.planDuration) day journey. Let's make today count! 💪",
            identifier: "morning"
        )
        
        // Schedule afternoon check-in (2 PM)
        let afternoonComponents = calendar.dateComponents([.hour, .minute], from: wakeTime)
        var afternoonTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!
        if afternoonTime < wakeTime {
            afternoonTime = calendar.date(byAdding: .day, value: 1, to: afternoonTime)!
        }
        await scheduleDailyNotification(
            at: afternoonTime,
            title: "Afternoon Check-in",
            body: "How's your day going? Don't forget to log your progress! 📝",
            identifier: "afternoon"
        )
        
        // Schedule evening reflection (2 hours before sleep time)
        let eveningTime = calendar.date(byAdding: .hour, value: -2, to: sleepTime)!
        await scheduleDailyNotification(
            at: eveningTime,
            title: "Evening Reflection",
            body: "Time to reflect on your day. What went well? What could be improved? 🌙",
            identifier: "evening"
        )
        
        // For "often" preference, also schedule task-specific notifications
        if preference == .often {
            await scheduleTaskNotifications(userData: userData)
        }
    }
    
    private func scheduleTaskNotifications(userData: UserData) async {
        // Get current tasks
        let currentTasks = userData.dailyTaskHistory.last?.tasks ?? []
        
        for task in currentTasks {
            let content = UNMutableNotificationContent()
            content.title = "New Task Available"
            content.body = "It's time for: \(task.emoji) \(task.task)"
            content.sound = .default
            
            let components = Calendar.current.dateComponents([.hour, .minute], from: task.scheduledTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            
            let request = UNNotificationRequest(
                identifier: "task-\(task.id)",
                content: content,
                trigger: trigger
            )
            
            do {
                try await notificationCenter.add(request)
            } catch {
                print("Error scheduling task notification: \(error)")
            }
        }
    }
    
    private func scheduleDailyNotification(at date: Date, title: String, body: String, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Error scheduling notification: \(error)")
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
} 
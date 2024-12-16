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
        
        let calendar = Calendar.current
        
        switch preference {
        case .never:
            return
            
        case .occasionally:
            // Morning notification (8:00 AM)
            await scheduleProgressNotification(
                hour: 8,
                minute: 0,
                title: "Good Morning, \(userData.name ?? "")!",
                identifier: "morning",
                notificationType: .morning,
                userData: userData
            )
            
            // Afternoon notification (2:00 PM)
            await scheduleProgressNotification(
                hour: 14,
                minute: 0,
                title: "Afternoon Check-in",
                identifier: "afternoon",
                notificationType: .progress,
                userData: userData
            )
            
            // Evening notification (9:45 PM)
            await scheduleProgressNotification(
                hour: 21,
                minute: 45,
                title: "Daily Summary",
                identifier: "evening",
                notificationType: .evening,
                userData: userData
            )
            
        case .often:
            // Five notifications throughout the day
            let notificationTimes = [
                (8, 0, "Morning Start", NotificationType.morning),
                (11, 30, "Late Morning Check", NotificationType.progress),
                (14, 0, "Afternoon Progress", NotificationType.progress),
                (17, 30, "Late Afternoon Update", NotificationType.progress),
                (21, 45, "Daily Summary", NotificationType.evening)
            ]
            
            for (index, (hour, minute, title, type)) in notificationTimes.enumerated() {
                await scheduleProgressNotification(
                    hour: hour,
                    minute: minute,
                    title: title,
                    identifier: "notification-\(index)",
                    notificationType: type,
                    userData: userData
                )
            }
        }
    }
    
    private enum NotificationType {
        case morning
        case progress
        case evening
    }
    
    private func scheduleProgressNotification(hour: Int, minute: Int, title: String, identifier: String, notificationType: NotificationType, userData: UserData) async {
        let content = UNMutableNotificationContent()
        content.title = title
        
        // Get today's tasks by finding the matching day in history
        let calendar = Calendar.current
        let today = Date()
        let currentTasks = userData.dailyTaskHistory
            .first(where: { calendar.isDate($0.date, inSameDayAs: today) })?
            .tasks ?? []
        
        let completedTasks = currentTasks.filter { $0.isCompleted }
        let completedCount = completedTasks.count
        let totalTasks = currentTasks.count
        let completionPercentage = totalTasks > 0 ? (Double(completedCount) / Double(totalTasks)) * 100 : 0
        
        // Create message based on notification type
        let message: String
        switch notificationType {
        case .morning:
            if totalTasks == 0 {
                message = """
                    Welcome to a new day! 🌅
                    No tasks have been set for today yet.
                    Let's get started by planning your day! 📝
                    """
            } else {
                message = """
                    Welcome to a new day! 🌅
                    You have \(totalTasks) tasks planned for today.
                    Let's make it count! 💪
                    """
            }
            
        case .progress:
            if totalTasks == 0 {
                message = """
                    No tasks have been set for today yet.
                    Take a moment to plan your day! 📝
                    """
            } else if completedCount == 0 {
                message = """
                    You haven't made any progress yet today.
                    Time to get started! 💪
                    You have \(totalTasks) tasks waiting.
                    """
            } else {
                message = """
                    Progress Update:
                    ✅ Completed: \(completedCount) tasks
                    📝 Remaining: \(totalTasks - completedCount) tasks
                    Keep the momentum going!
                    """
            }
            
        case .evening:
            if totalTasks == 0 {
                message = """
                    Today was a quiet day with no planned tasks.
                    Tomorrow is a new opportunity to set and achieve your goals! 🌅
                    """
            } else if completionPercentage == 100 {
                message = """
                    🎉 Incredible job today!
                    You completed all \(totalTasks) tasks.
                    Keep up this amazing momentum!
                    """
            } else if completionPercentage >= 75 {
                message = """
                    Great effort today! 
                    You completed \(completedCount) out of \(totalTasks) tasks.
                    Tomorrow, let's aim for that 100%! 💪
                    """
            } else if completionPercentage >= 50 {
                message = """
                    Solid progress today!
                    You completed \(completedCount) out of \(totalTasks) tasks.
                    Let's push a bit harder tomorrow! 💪
                    """
            } else if completionPercentage > 0 {
                message = """
                    You made some progress today.
                    Completed: \(completedCount) out of \(totalTasks) tasks.
                    Remember: every small step counts.
                    Let's aim higher tomorrow! 🎯
                    """
            } else {
                message = """
                    Today was a bit quiet.
                    Tomorrow is a new opportunity to crush your goals!
                    Get some rest and start fresh tomorrow. 🌅
                    """
            }
        }
        
        content.body = message
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
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
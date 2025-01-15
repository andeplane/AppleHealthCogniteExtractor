// ./BackgroundSyncManager.swift

import Foundation
import BackgroundTasks

extension BGTaskScheduler {
    func simulateLaunch(taskIdentifier: String) {
        let selector = NSSelectorFromString("_simulateLaunchForTaskWithIdentifier:")
        if self.responds(to: selector) {
            self.perform(selector, with: taskIdentifier)
        } else {
            print("Simulation method not available. Ensure this is for debugging only.")
        }
    }
}

class BackgroundSyncManager {
    static let shared = BackgroundSyncManager()
    
    private init() {}
    
    /// Schedules the background sync task to run every 3 hours.
    func scheduleSync() {
        print("Scheduling sync task...")

        let request = BGAppRefreshTaskRequest(identifier: "com.cognite.sync")
//        request.earliestBeginDate = Date(timeIntervalSinceNow: 3 * 60 * 60) // 3 hours
        // Run every minute now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background sync scheduled to run in 60 minutes.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                BGTaskScheduler.shared.getPendingTaskRequests { tasks in
                    print("Pending tasks:")
                    for task in tasks {
                        print("Task identifier: \(task.identifier), earliest begin date: \(String(describing: task.earliestBeginDate))")
                    }
                }
                
//                print("Simulating background task launch...")
//                BGTaskScheduler.shared.simulateLaunch(taskIdentifier: "com.yourapp.sync")
            }
            
        } catch {
            print("Could not schedule background sync: \(error)")
        }
    }
    
    /// Cancels any pending background sync tasks.
    func cancelSync() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.cognite.sync")
        print("Background sync canceled.")
    }
}

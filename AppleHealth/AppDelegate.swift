// ./AppDelegate.swift

import UIKit
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    var viewModel: AppViewModel?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("Registering background task handler")
        // Register the background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.cognite.sync", using: nil) { task in
            self.handleAppSync(task: task as! BGAppRefreshTask)
        }
        return true
    }

    /// Handles the execution of the background sync task.
    /// - Parameter task: The background task to handle.
    func handleAppSync(task: BGAppRefreshTask) {
        print("Handling the app sync")
        // Schedule the next sync
        if UserDefaults.standard.bool(forKey: "enableAutoSync") {
            BackgroundSyncManager.shared.scheduleSync()
        }

        // Ensure the viewModel is set
        guard let viewModel = self.viewModel else {
            task.setTaskCompleted(success: false)
            return
        }

        // Create an operation that performs the background sync
        let operation = BackgroundSyncOperation(viewModel: viewModel)

        // Provide an expiration handler
        task.expirationHandler = {
            // Cancel the operation if the task expires
            operation.cancel()
        }

        // When the operation completes, set the task as complete
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }

        // Start the operation
        OperationQueue().addOperation(operation)
    }
}

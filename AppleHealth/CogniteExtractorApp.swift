// ./CogniteExtractorApp.swift

import SwiftUI
import BackgroundTasks

@main
struct CogniteExtractorApp: App {
    // Initialize AppViewModel
    @StateObject private var viewModel = AppViewModel()

    // Integrate AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    // Assign the viewModel to AppDelegate
                    appDelegate.viewModel = viewModel

                    // Schedule the background sync if enabled
                    if UserDefaults.standard.bool(forKey: "enableAutoSync") {
                        BackgroundSyncManager.shared.scheduleSync()
                    }
                }
        }
    }
}

// ./BackgroundSyncOperation.swift

import Foundation
import BackgroundTasks

class BackgroundSyncOperation: Operation {
    private let viewModel: AppViewModel

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    override func main() {
        if self.isCancelled {
            return
        }

        let semaphore = DispatchSemaphore(value: 0)

        Task {
            await viewModel.syncLast24Hours()
            semaphore.signal()
        }

        // Wait for the task to finish or timeout after 25 seconds
        _ = semaphore.wait(timeout: .now() + 25)

        if self.isCancelled {
            return
        }
    }
}

import Foundation
import Combine

@MainActor
class DebouncedSave: ObservableObject {
    private var task: Task<Void, Never>?
    private let delay: TimeInterval
    
    init(delay: TimeInterval = 1.0) {
        self.delay = delay
    }
    
    func trigger(_ action: @escaping () async -> Void) {
        // Cancel any existing task
        task?.cancel()
        
        // Create a new task with delay
        task = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            // Check if task was cancelled
            if !Task.isCancelled {
                await action()
            }
        }
    }
    
    deinit {
        task?.cancel()
    }
} 
import Foundation

nonisolated enum DataLoadState<Value> {
    case initial
    case loading
    case success(Value)
    case error(Error)

    var value: Value? {
        if case .success(let value) = self { return value }
        return nil
    }
}

nonisolated enum VoidDataLoadState {
    case initial
    case loading
    case success
    case error(Error)
}

nonisolated func isCancellation(_ error: Error) -> Bool {
    error is CancellationError || (error as? URLError)?.code == .cancelled
}

nonisolated enum BrowserError: LocalizedError {
    case http(Int)
    case invalidResponse
    case invalidPortrait
    case unavailableProfile
    case persistence

    var errorDescription: String? {
        switch self {
        case .http(let status): "The service returned an error (\(status)). Please try again."
        case .invalidResponse: "The service returned data we couldn’t read. Please try again."
        case .invalidPortrait: "This portrait couldn’t be displayed."
        case .unavailableProfile: "Profile unavailable offline. Connect to the internet and try again."
        case .persistence: "This content couldn’t be saved for offline use. Please try again."
        }
    }
}

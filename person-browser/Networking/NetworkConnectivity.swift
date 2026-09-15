import Foundation
import Network

nonisolated enum ConnectivityStatus: Sendable {
    case online
    case offline
}

nonisolated protocol ConnectivityMonitoring: Sendable {
    func updates() -> AsyncStream<ConnectivityStatus>
}

nonisolated struct NetworkConnectivity: ConnectivityMonitoring {
    func updates() -> AsyncStream<ConnectivityStatus> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                // A usable path does not guarantee that the server will respond.
                continuation.yield(path.status == .unsatisfied ? .offline : .online)
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "person-browser.connectivity"))
        }
    }
}

nonisolated struct RefreshFailureMessage {
    let title: String
    let detail: String
    let symbol: String

    init(error: Error) {
        switch (error as? URLError)?.code {
        case .notConnectedToInternet:
            title = "You’re offline"
            detail = "Showing saved content. We’ll try again when connectivity returns."
            symbol = "wifi.slash"
        case .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .networkConnectionLost:
            title = "Couldn’t reach the server"
            detail = "Showing saved content. Please try again."
            symbol = "exclamationmark.triangle"
        default:
            title = "Couldn’t update saved content"
            detail = error.localizedDescription
            symbol = "exclamationmark.triangle"
        }
    }
}

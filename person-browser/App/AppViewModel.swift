import Foundation
import Observation

@MainActor
@Observable
final class AppViewModel {
    private(set) var state: DataLoadState<AppServices> = .initial
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    func load() {
        guard state.value == nil else { return }
        loadTask?.cancel()
        loadTask = Task { await performLoad() }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        if state.value == nil { state = .initial }
    }

    private func performLoad() async {
        guard Task.isNotCancelled else { return }
        state = .loading
        do {
            let services = try await AppServices.make()
            try Task.checkCancellation()
            state = .success(services)
        } catch {
            // This guard prevents a cancelled task from overwriting state after a new load or explicit cancellation.
            guard Task.isNotCancelled else { return }
            state = isCancellation(error) ? .initial : .error(error)
        }
    }
}

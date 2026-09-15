import Foundation
import Observation

@MainActor
@Observable
final class PeopleViewModel {
    private(set) var state: DataLoadState<[Person]> = .initial
    private(set) var refreshState: VoidDataLoadState = .initial
    private let repository: any PeopleRepository
    private let connectivity: any ConnectivityMonitoring
    @ObservationIgnored private var connectivityTask: Task<Void, Never>?
    @ObservationIgnored private var connectivityStatus: ConnectivityStatus?
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    init(repository: any PeopleRepository, connectivity: any ConnectivityMonitoring = NetworkConnectivity()) {
        self.repository = repository
        self.connectivity = connectivity
    }

    func load() {
        observeConnectivity()
        loadTask?.cancel()
        loadTask = Task { await performLoad() }
    }

    func refresh() async {
        load()
        await loadTask?.value
    }

    func cancel() {
        connectivityTask?.cancel()
        connectivityTask = nil
        connectivityStatus = nil
        loadTask?.cancel()
        loadTask = nil
        if state.value == nil { state = .initial }
        refreshState = .initial
    }

    private func observeConnectivity() {
        guard connectivityTask == nil else { return }
        let updates = connectivity.updates()
        connectivityTask = Task { [weak self] in
            for await status in updates {
                guard Task.isNotCancelled else { return }
                self?.connectivityChanged(status)
            }
        }
    }

    private func connectivityChanged(_ status: ConnectivityStatus) {
        let previous = connectivityStatus
        connectivityStatus = status
        guard previous != status else { return }
        if status == .offline || previous == .offline {
            // Replace an in-flight request on disconnect; reload saved data before reporting offline.
            load()
        }
    }

    private func performLoad() async {
        guard Task.isNotCancelled else { return }
        do {
            if state.value == nil {
                state = .loading
                let saved = try await repository.savedPeople()
                try Task.checkCancellation()
                if let saved { state = .success(saved) }
            }
            guard connectivityStatus != .offline else { throw URLError(.notConnectedToInternet) }
            if state.value != nil { refreshState = .loading }
            let people = try await repository.refreshPeople()
            try Task.checkCancellation()
            state = .success(people)
            refreshState = .success
        } catch {
            // This guard prevents a cancelled task from overwriting state after a new load or explicit cancellation.
            guard Task.isNotCancelled else { return }
            if isCancellation(error) {
                if state.value == nil { state = .initial }
                refreshState = .initial
            } else if state.value != nil {
                refreshState = .error(error)
            } else {
                state = .error(error)
                refreshState = .initial
            }
        }
    }
}

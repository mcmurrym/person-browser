import Foundation
import Observation

@MainActor
@Observable
final class PeopleViewModel {
    private(set) var state: DataLoadState<[Person]> = .initial
    private(set) var refreshState: VoidDataLoadState = .initial
    private let repository: any PeopleRepository
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    init(repository: any PeopleRepository) { self.repository = repository }

    func load() {
        loadTask?.cancel()
        loadTask = Task { await performLoad() }
    }

    func refresh() async {
        load()
        await loadTask?.value
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        if state.value == nil { state = .initial }
        refreshState = .initial
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

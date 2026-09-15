import Foundation
import Observation

@MainActor
@Observable
final class PersonProfileViewModel {
    private(set) var state: DataLoadState<Person> = .initial
    private(set) var refreshState: VoidDataLoadState = .initial
    private let id: String
    private let repository: any PeopleRepository
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    init(id: String, repository: any PeopleRepository) {
        self.id = id
        self.repository = repository
    }

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
                let person = try await repository.savedPerson(id: id)
                try Task.checkCancellation()
                if let person { state = .success(person) }
            }
            if state.value != nil { refreshState = .loading }
            let person = try await repository.refreshPerson(id: id)
            try Task.checkCancellation()
            state = .success(person)
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

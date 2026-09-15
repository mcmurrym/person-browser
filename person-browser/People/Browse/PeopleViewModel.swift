import Foundation
import Observation

@MainActor
@Observable
final class PeopleViewModel {
    private(set) var state: DataLoadState<[Person]> = .initial
    private(set) var refreshState: VoidDataLoadState = .initial
    private let repository: any PeopleRepository
    private var isRunning = false

    init(repository: any PeopleRepository) { self.repository = repository }

    func load() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        do {
            if state.value == nil {
                state = .loading
                if let saved = try await repository.savedPeople() {
                    try Task.checkCancellation()
                    state = .success(saved)
                }
            }
            if state.value != nil { refreshState = .loading }
            let people = try await repository.refreshPeople()
            try Task.checkCancellation()
            state = .success(people)
            refreshState = .success
        } catch {
            if isCancellation(error) || Task.isCancelled {
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

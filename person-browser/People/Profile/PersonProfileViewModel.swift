import Foundation
import Observation

@MainActor
@Observable
final class PersonProfileViewModel {
    private(set) var state: DataLoadState<Person> = .initial
    private(set) var refreshState: VoidDataLoadState = .initial
    private let id: String
    private let repository: any PeopleRepository
    private var isRunning = false

    init(id: String, repository: any PeopleRepository) {
        self.id = id
        self.repository = repository
    }

    func load() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        do {
            if state.value == nil {
                state = .loading
                if let person = try await repository.savedPerson(id: id) {
                    try Task.checkCancellation()
                    state = .success(person)
                }
            }
            if state.value != nil { refreshState = .loading }
            let person = try await repository.refreshPerson(id: id)
            try Task.checkCancellation()
            state = .success(person)
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

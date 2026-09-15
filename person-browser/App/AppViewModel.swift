import Foundation
import Observation

@MainActor
@Observable
final class AppViewModel {
    private(set) var state: DataLoadState<AppServices> = .initial
    func load() async {
        guard state.value == nil else { return }
        state = .loading
        do {
            let services = try await AppServices.make()
            try Task.checkCancellation()
            state = .success(services)
        } catch {
            state = isCancellation(error) ? .initial : .error(error)
        }
    }
}

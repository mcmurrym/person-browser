import Foundation
import Observation

nonisolated struct PortraitRequest: Equatable {
    let url: URL
    let pixels: Int
}

@MainActor
@Observable
final class PortraitViewModel {
    private(set) var state: DataLoadState<PreparedPortrait> = .initial
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    private let loader: any PortraitLoading

    init(loader: any PortraitLoading) { self.loader = loader }

    func load(_ request: PortraitRequest) {
        loadTask?.cancel()
        loadTask = Task { await performLoad(request) }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        if state.value == nil { state = .initial }
    }

    private func performLoad(_ request: PortraitRequest) async {
        guard !Task.isCancelled else { return }
        state = .loading
        do {
            let image = try await loader.image(url: request.url, pixels: request.pixels)
            try Task.checkCancellation()
            state = .success(image)
        } catch {
            guard !Task.isCancelled else { return }
            if isCancellation(error) { state = .initial }
            else { state = .error(error) }
        }
    }
}

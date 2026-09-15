import Foundation
import Observation

@MainActor
@Observable
final class PortraitViewModel {
    private(set) var state: DataLoadState<PreparedPortrait> = .initial
    private var generation = 0
    private let loader: any PortraitLoading
    init(loader: any PortraitLoading) { self.loader = loader }

    func load(url: URL, pixels: Int) async {
        generation += 1
        let request = generation
        state = .loading
        do {
            let image = try await loader.image(url: url, pixels: pixels)
            try Task.checkCancellation()
            guard request == generation else { return }
            state = .success(image)
        } catch {
            guard request == generation else { return }
            if isCancellation(error) || Task.isCancelled { state = .initial }
            else { state = .error(error) }
        }
    }
}

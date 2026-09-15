import Foundation
import ImageIO

// CGImage is immutable; the wrapper lets the actor return a prepared image safely.
nonisolated final class PreparedPortrait: NSObject, @unchecked Sendable {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}

nonisolated protocol PortraitLoading: Sendable {
    func image(url: URL, pixels: Int) async throws -> PreparedPortrait
}

actor PortraitLoader: PortraitLoading {
    private let client: any HTTPClient
    private let store: any PeopleStore
    private let memory = NSCache<NSString, PreparedPortrait>()

    init(client: any HTTPClient, store: any PeopleStore) {
        self.client = client
        self.store = store
        memory.totalCostLimit = 24 * 1024 * 1024
    }

    func image(url: URL, pixels: Int) async throws -> PreparedPortrait {
        let key = "\(url.absoluteString)#\(pixels)" as NSString
        if let image = memory.object(forKey: key) { return image }
        let prepared: PreparedPortrait
        if let data = try await store.portrait(url: url) {
            prepared = try prepare(data, pixels: pixels)
        } else {
            let data = try await client.data(from: url)
            prepared = try prepare(data, pixels: pixels)
            try Task.checkCancellation()
            try await store.savePortrait(data, url: url)
        }
        try Task.checkCancellation()
        memory.setObject(prepared, forKey: key, cost: prepared.image.bytesPerRow * prepared.image.height)
        return prepared
    }

    private func prepare(_ data: Data, pixels: Int) throws -> PreparedPortrait {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(1, pixels),
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw BrowserError.invalidPortrait }
        return PreparedPortrait(image)
    }
}

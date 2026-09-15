import Foundation

nonisolated protocol HTTPClient: Sendable {
    func data(from url: URL) async throws -> Data
}

actor URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw BrowserError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw BrowserError.http(response.statusCode) }
        return data
    }
}

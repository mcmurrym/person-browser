import Foundation

nonisolated struct AppServices: Sendable {
    let people: any PeopleRepository
    let portraits: any PortraitLoading

    static func make() async throws -> AppServices {
        var storeURL: URL?
        var client: any HTTPClient = URLSessionHTTPClient()
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing") {
            // UI tests use an isolated directory and never remove the user's store.
            let directory = URL.applicationSupportDirectory.appending(path: "UITestRecords")
            if arguments.contains("--reset-test-store"), FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            storeURL = directory.appending(path: "people.store")
            if arguments.contains("--offline") { client = OfflineHTTPClient() }
        }
        #endif
        let store = try await SwiftDataPeopleStore.make(url: storeURL)
        return AppServices(people: RecordsRepository(client: client, store: store), portraits: PortraitLoader(client: client, store: store))
    }
}


#if DEBUG
private actor OfflineHTTPClient: HTTPClient {
    func data(from url: URL) throws -> Data { throw URLError(.notConnectedToInternet) }
}
#endif

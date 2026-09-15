import Foundation

nonisolated struct AppServices: Sendable {
    let people: any PeopleRepository
    let portraits: any PortraitLoading

    static func make() async throws -> AppServices {
        let client = URLSessionHTTPClient()
        let store = try await SwiftDataPeopleStore.make()
        return AppServices(people: RecordsRepository(client: client, store: store), portraits: PortraitLoader(client: client, store: store))
    }
}

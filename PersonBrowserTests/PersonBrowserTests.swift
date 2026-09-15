import Foundation
import Testing
import UIKit
@testable import person_browser

private final class FixtureBundle: NSObject {}

private func fixture(_ name: String, extension ext: String = "json") throws -> Data {
    let url = try #require(Bundle(for: FixtureBundle.self).url(forResource: name, withExtension: ext, subdirectory: "Fixtures") ?? Bundle(for: FixtureBundle.self).url(forResource: name, withExtension: ext))
    return try Data(contentsOf: url)
}

private func profile() throws -> Person {
    try JSONDecoder().decode(PersonResponse.self, from: fixture("profile"))
        .person(baseURL: RecordsRepository.serviceURL, fullProfile: true)
}

private func people() throws -> [Person] {
    try JSONDecoder().decode(PeopleResponse.self, from: fixture("persons")).persons.map {
        try $0.person(baseURL: RecordsRepository.serviceURL, fullProfile: false)
    }
}

private func temporaryStoreURL() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appending(path: "people.store")
}

private actor StubHTTPClient: HTTPClient {
    var response: Result<Data, Error>
    private(set) var requestCount = 0
    init(_ response: Result<Data, Error>) { self.response = response }
    func data(from url: URL) async throws -> Data {
        requestCount += 1
        return try response.get()
    }
}

private actor StubRepository: PeopleRepository {
    let saved: [Person]?
    var result: Result<[Person], Error>
    var delays = false
    init(saved: [Person]? = nil, result: Result<[Person], Error>) {
        self.saved = saved
        self.result = result
    }
    func configure(result: Result<[Person], Error>, delays: Bool = false) {
        self.result = result
        self.delays = delays
    }
    func savedPeople() -> [Person]? { saved }
    func savedPerson(id: String) -> Person? { saved?.first { $0.id == id } }
    func refreshPeople() async throws -> [Person] {
        if delays { try await Task.sleep(for: .seconds(30)) }
        return try result.get()
    }
    func refreshPerson(id: String) async throws -> Person {
        let values = try await refreshPeople()
        guard let person = values.first(where: { $0.id == id }) else { throw BrowserError.invalidResponse }
        return person
    }
}

private actor FailingStore: PeopleStore {
    func savedPeople() -> [Person]? { nil }
    func person(id: String) -> Person? { nil }
    func saveList(_ people: [Person]) throws { throw BrowserError.persistence }
    func saveProfile(_ person: Person) throws { throw BrowserError.persistence }
    func portrait(url: URL) -> Data? { nil }
    func savePortrait(_ data: Data, url: URL) throws { throw BrowserError.persistence }
}

struct PersonBrowserTests {
    @Test func decodesNullableFieldsAndPreservesDisplayDates() throws {
        let values = try people()
        #expect(values.count == 16)
        let living = try #require(values.first { $0.living })
        #expect(living.death == nil)
        #expect(living.lifespan == "1931–Living")
        #expect(values.first?.birth.date == "about 1814")
        #expect(values.first?.portraitURL.absoluteString == "https://fs-records-sample.vercel.app/portraits/R9PJ-5MX.jpg")
        var object = try #require(JSONSerialization.jsonObject(with: fixture("profile")) as? [String: Any])
        object["occupation"] = NSNull()
        let decoded = try JSONDecoder().decode(PersonResponse.self, from: JSONSerialization.data(withJSONObject: object))
        let value = try decoded.person(baseURL: RecordsRepository.serviceURL, fullProfile: true)
        #expect(value.details?.occupation == nil)
        #expect(value.details?.relatives.first?.relationship == "father")
    }

    @Test func rejectsSummaryAsFullProfile() throws {
        let response = try JSONDecoder().decode(PeopleResponse.self, from: fixture("persons"))
        #expect(throws: (any Error).self) {
            try response.persons[0].person(baseURL: RecordsRepository.serviceURL, fullProfile: true)
        }
    }

    @Test func malformedRefreshPreservesSavedRecords() async throws {
        let store = try await SwiftDataPeopleStore.make(url: temporaryStoreURL())
        let original = try people()
        try await store.saveList(original)
        let client = StubHTTPClient(.success(Data("{ broken".utf8)))
        let repository = RecordsRepository(client: client, store: store)
        await #expect(throws: (any Error).self) { try await repository.refreshPeople() }
        let saved = try await store.savedPeople()
        #expect(saved == original)
    }

    @Test func summaryRefreshPreservesFullProfileAndLookup() async throws {
        let store = try await SwiftDataPeopleStore.make(url: temporaryStoreURL())
        let full = try profile()
        try await store.saveProfile(full)
        try await store.saveList(people())
        let saved = try await store.person(id: full.id)
        #expect(saved == full)
        #expect(try await store.person(id: "missing") == nil)
        #expect(try await store.savedPeople()?.map(\.id) == people().map(\.id))
    }

    @Test func reopenedStoreRetainsProfilesRelativesAndPortraitsWithoutNetwork() async throws {
        let url = try temporaryStoreURL()
        let full = try profile()
        let jpeg = try fixture("portrait", extension: "jpg")
        var first: SwiftDataPeopleStore? = try await SwiftDataPeopleStore.make(url: url)
        try await first?.saveList(people())
        try await first?.saveProfile(full)
        try await first?.savePortrait(jpeg, url: full.portraitURL)
        first = nil
        let reopened = try await SwiftDataPeopleStore.make(url: url)
        let offline = StubHTTPClient(.failure(URLError(.notConnectedToInternet)))
        let repository = RecordsRepository(client: offline, store: reopened)
        #expect(try await repository.savedPeople()?.count == 16)
        #expect(try await repository.savedPerson(id: full.id) == full)
        #expect(try await reopened.portrait(url: full.portraitURL) == jpeg)
        let loader = PortraitLoader(client: offline, store: reopened)
        let prepared = try await loader.image(url: full.portraitURL, pixels: 180)
        #expect(max(prepared.image.width, prepared.image.height) <= 180)
        #expect(await offline.requestCount == 0)
    }

    @Test func emptyListIsDurablyDifferentFromNoList() async throws {
        let url = try temporaryStoreURL()
        let store = try await SwiftDataPeopleStore.make(url: url)
        #expect(try await store.savedPeople() == nil)
        try await store.saveList([])
        let reopened = try await SwiftDataPeopleStore.make(url: url)
        #expect(try await reopened.savedPeople() == [])
    }

    @Test @MainActor func initialFailureCanRetryToEmptySuccess() async {
        let repository = StubRepository(result: .failure(URLError(.notConnectedToInternet)))
        let model = PeopleViewModel(repository: repository)
        guard case .initial = model.state else { Issue.record("Expected initial"); return }
        await model.load()
        guard case .error = model.state else { Issue.record("Expected first-launch error"); return }
        await repository.configure(result: .success([]))
        await model.load()
        #expect(model.state.value == [])
    }

    @Test @MainActor func offlineRefreshKeepsSavedContent() async throws {
        let saved = try people()
        let repository = StubRepository(saved: saved, result: .failure(URLError(.notConnectedToInternet)))
        let model = PeopleViewModel(repository: repository)
        await model.load()
        #expect(model.state.value == saved)
        guard case .error = model.refreshState else { Issue.record("Expected refresh error"); return }
    }

    @Test @MainActor func cachedProfileAndPartialSummarySurviveOfflineFailure() async throws {
        let full = try profile()
        let repository = StubRepository(saved: [full], result: .failure(URLError(.notConnectedToInternet)))
        let model = PersonProfileViewModel(id: full.id, repository: repository)
        await model.load()
        #expect(model.state.value?.details == full.details)
        let summary = try #require(people().first)
        let partial = PersonProfileViewModel(id: summary.id, repository: StubRepository(saved: [summary], result: .failure(URLError(.notConnectedToInternet))))
        await partial.load()
        #expect(partial.state.value == summary)
        guard case .error = partial.refreshState else { Issue.record("Expected incomplete profile refresh error"); return }
    }

    @Test @MainActor func cancellationDoesNotBecomeFailureAndRemainsRetryable() async {
        let repository = StubRepository(result: .success([]))
        await repository.configure(result: .success([]), delays: true)
        let model = PeopleViewModel(repository: repository)
        let task = Task { await model.load() }
        while case .initial = model.state { await Task.yield() }
        task.cancel()
        await task.value
        guard case .initial = model.state else { Issue.record("Cancellation should restore initial"); return }
        await repository.configure(result: .success([]))
        await model.load()
        #expect(model.state.value == [])
    }

    @Test func repositorySurfacesSaveFailure() async throws {
        let repository = RecordsRepository(client: StubHTTPClient(.success(try fixture("persons"))), store: FailingStore())
        await #expect(throws: BrowserError.self) { try await repository.refreshPeople() }
    }

    @Test func portraitMustBeSavedBeforeSuccess() async throws {
        let loader = PortraitLoader(client: StubHTTPClient(.success(try fixture("portrait", extension: "jpg"))), store: FailingStore())
        await #expect(throws: BrowserError.self) { try await loader.image(url: profile().portraitURL, pixels: 56) }
    }

    @Test func rejectsInvalidPortraitBytes() async throws {
        let store = try await SwiftDataPeopleStore.make(url: temporaryStoreURL())
        let loader = PortraitLoader(client: StubHTTPClient(.success(Data("not an image".utf8))), store: store)
        let url = try profile().portraitURL
        await #expect(throws: BrowserError.self) { try await loader.image(url: url, pixels: 56) }
        #expect(try await store.portrait(url: url) == nil)
    }

    @Test func validatesHTTPStatus() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ErrorURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = URLSessionHTTPClient(session: session)
        await #expect(throws: BrowserError.self) {
            try await client.data(from: URL(string: "https://example.com/503")!)
        }
    }
}

private final class ErrorURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

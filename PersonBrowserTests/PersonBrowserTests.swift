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
    private(set) var refreshCount = 0
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
        refreshCount += 1
        if delays { try await Task.sleep(for: .seconds(30)) }
        return try result.get()
    }
    func refreshPerson(id: String) async throws -> Person {
        let values = try await refreshPeople()
        guard let person = values.first(where: { $0.id == id }) else { throw BrowserError.invalidResponse }
        return person
    }
}

// Intentionally ignores cancellation so the view model must reject an obsolete result.
private actor ControlledRepository: PeopleRepository {
    private var requests: [Int: CheckedContinuation<[Person], Error>] = [:]
    private var count = 0
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func savedPeople() -> [Person]? { nil }
    func savedPerson(id: String) -> Person? { nil }
    func refreshPeople() async throws -> [Person] {
        let index = count
        count += 1
        return try await withCheckedThrowingContinuation { continuation in
            requests[index] = continuation
            let ready = waiters.filter { $0.0 <= count }
            waiters.removeAll { $0.0 <= count }
            for (_, waiter) in ready { waiter.resume() }
        }
    }
    func refreshPerson(id: String) async throws -> Person {
        let values = try await refreshPeople()
        guard let person = values.first else { throw BrowserError.invalidResponse }
        return person
    }
    func waitForRequests(_ expected: Int) async {
        if count >= expected { return }
        await withCheckedContinuation { waiters.append((expected, $0)) }
    }
    func resolve(_ index: Int, result: Result<[Person], Error>) {
        requests.removeValue(forKey: index)?.resume(with: result)
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
    @Test func mapsPeopleToDisplayValuesAndResolvesPortraitURL() throws {
        let values = try people()
        let living = try #require(values.first { $0.living })
        let historical = try #require(values.first { $0.id == "R9PJ-5MX" })

        #expect(living.lifespan == "1931–Living")
        #expect(historical.lifespan == "1814–1888")
        #expect(historical.birth.date == "about 1814")
        #expect(historical.portraitURL.absoluteString == "https://fs-records-sample.vercel.app/portraits/R9PJ-5MX.jpg")
    }

    @Test func networkFailurePreservesSavedRecords() async throws {
        let store = try await SwiftDataPeopleStore.make(url: temporaryStoreURL())
        let original = try people()
        try await store.saveList(original)
        let client = StubHTTPClient(.failure(URLError(.timedOut)))
        let repository = RecordsRepository(client: client, store: store)

        await #expect {
            try await repository.refreshPeople()
        } throws: { error in
            (error as? URLError)?.code == .timedOut
        }
        #expect(try await store.savedPeople() == original)
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
        let original = try people()
        var first: SwiftDataPeopleStore? = try await SwiftDataPeopleStore.make(url: url)
        try await first?.saveList(original)
        try await first?.saveProfile(full)
        try await first?.savePortrait(jpeg, url: full.portraitURL)
        first = nil
        let reopened = try await SwiftDataPeopleStore.make(url: url)
        let offline = StubHTTPClient(.failure(URLError(.notConnectedToInternet)))
        let repository = RecordsRepository(client: offline, store: reopened)
        #expect(try await repository.savedPeople()?.map(\.id) == original.map(\.id))
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
        let model = PeopleViewModel(repository: repository, connectivity: SilentConnectivity())
        guard case .initial = model.state else { Issue.record("Expected initial"); return }
        await model.refresh()
        guard case .error = model.state else { Issue.record("Expected first-launch error"); return }
        await repository.configure(result: .success([]))
        await model.refresh()
        #expect(model.state.value == [])
    }

    @Test @MainActor func offlineRefreshKeepsSavedContent() async throws {
        let saved = try people()
        let repository = StubRepository(saved: saved, result: .failure(URLError(.notConnectedToInternet)))
        let model = PeopleViewModel(repository: repository, connectivity: SilentConnectivity())
        await model.refresh()
        #expect(model.state.value == saved)
        guard case .error = model.refreshState else { Issue.record("Expected refresh error"); return }
    }

    @Test @MainActor func cachedProfileAndPartialSummarySurviveOfflineFailure() async throws {
        let full = try profile()
        let repository = StubRepository(saved: [full], result: .failure(URLError(.notConnectedToInternet)))
        let model = PersonProfileViewModel(id: full.id, repository: repository, connectivity: SilentConnectivity())
        await model.refresh()
        #expect(model.state.value?.details == full.details)
        let summary = try #require(people().first)
        let partial = PersonProfileViewModel(id: summary.id, repository: StubRepository(saved: [summary], result: .failure(URLError(.notConnectedToInternet))), connectivity: SilentConnectivity())
        await partial.refresh()
        #expect(partial.state.value == summary)
        guard case .error = partial.refreshState else { Issue.record("Expected incomplete profile refresh error"); return }
    }

    @Test @MainActor func cancellationDoesNotBecomeFailureAndRemainsRetryable() async {
        let repository = StubRepository(result: .success([]))
        await repository.configure(result: .success([]), delays: true)
        let model = PeopleViewModel(repository: repository, connectivity: SilentConnectivity())
        model.load()
        while case .initial = model.state { await Task.yield() }
        model.cancel()
        guard case .initial = model.state else { Issue.record("Cancellation should restore initial"); return }
        await repository.configure(result: .success([]))
        await model.refresh()
        #expect(model.state.value == [])
    }

    @Test @MainActor func obsoleteRetryCannotReplaceNewerSuccess() async throws {
        let repository = ControlledRepository()
        let model = PeopleViewModel(repository: repository, connectivity: SilentConnectivity())
        let first = Task { await model.refresh() }
        await repository.waitForRequests(1)
        let second = Task { await model.refresh() }
        await repository.waitForRequests(2)
        let current = try people()
        await repository.resolve(1, result: .success(current))
        await second.value
        #expect(model.state.value == current)
        await repository.resolve(0, result: .failure(URLError(.timedOut)))
        await first.value
        #expect(model.state.value == current)
        guard case .success = model.refreshState else {
            Issue.record("An obsolete failure must not change the current refresh state")
            return
        }
    }

    @Test func repositorySurfacesSaveFailure() async throws {
        let repository = RecordsRepository(client: StubHTTPClient(.success(try fixture("persons"))), store: FailingStore())
        await #expect {
            try await repository.refreshPeople()
        } throws: { error in
            guard case BrowserError.persistence = error else { return false }
            return true
        }
    }

    @Test func portraitMustBeSavedBeforeSuccess() async throws {
        let loader = PortraitLoader(client: StubHTTPClient(.success(try fixture("portrait", extension: "jpg"))), store: FailingStore())
        let url = try profile().portraitURL
        // A failed save must not populate the memory cache and make Retry appear successful.
        for _ in 0..<2 {
            await #expect {
                try await loader.image(url: url, pixels: 56)
            } throws: { error in
                guard case BrowserError.persistence = error else { return false }
                return true
            }
        }
    }

    @Test func portraitNetworkFailureDoesNotCreateSavedImage() async throws {
        let store = try await SwiftDataPeopleStore.make(url: temporaryStoreURL())
        let client = StubHTTPClient(.failure(URLError(.notConnectedToInternet)))
        let loader = PortraitLoader(client: client, store: store)
        let url = try profile().portraitURL

        await #expect {
            try await loader.image(url: url, pixels: 56)
        } throws: { error in
            (error as? URLError)?.code == .notConnectedToInternet
        }
        #expect(try await store.portrait(url: url) == nil)
    }

    @Test func mapsHTTPFailureToServiceError() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ErrorURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = URLSessionHTTPClient(session: session)
        await #expect {
            try await client.data(from: URL(string: "https://example.com/503")!)
        } throws: { error in
            guard case BrowserError.http(503) = error else { return false }
            return true
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

private struct SilentConnectivity: ConnectivityMonitoring {
    func updates() -> AsyncStream<ConnectivityStatus> { AsyncStream { $0.finish() } }
}

private struct ControlledConnectivity: ConnectivityMonitoring {
    let stream: AsyncStream<ConnectivityStatus>
    let continuation: AsyncStream<ConnectivityStatus>.Continuation

    init() {
        (stream, continuation) = AsyncStream.makeStream()
    }
    func updates() -> AsyncStream<ConnectivityStatus> { stream }
}

@MainActor
private func waitUntil(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(3)
    while !condition(), ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(condition())
}

extension PersonBrowserTests {
    @Test @MainActor func disconnectKeepsSavedPeopleAndReconnectRefreshes() async throws {
        let saved = try people()
        let repository = StubRepository(saved: saved, result: .success(saved))
        let connectivity = ControlledConnectivity()
        let model = PeopleViewModel(repository: repository, connectivity: connectivity)
        defer { model.cancel(); connectivity.continuation.finish() }
        await model.refresh()
        await repository.configure(result: .success([]), delays: true)
        model.load()
        connectivity.continuation.yield(.offline)
        try await waitUntil {
            if case .error(let error) = model.refreshState {
                return (error as? URLError)?.code == .notConnectedToInternet
            }
            return false
        }
        #expect(model.state.value == saved)
        let count = await repository.refreshCount
        await model.refresh()
        #expect(await repository.refreshCount == count)
        await repository.configure(result: .success([]))
        connectivity.continuation.yield(.online)
        try await waitUntil { model.state.value == [] }
    }

    @Test @MainActor func profileReconnectRefreshesAndCancellationStopsMonitoring() async throws {
        let full = try profile()
        let repository = StubRepository(saved: [full], result: .failure(URLError(.timedOut)))
        let connectivity = ControlledConnectivity()
        let model = PersonProfileViewModel(id: full.id, repository: repository, connectivity: connectivity)
        defer { model.cancel(); connectivity.continuation.finish() }
        await model.refresh()
        #expect(model.state.value == full)
        connectivity.continuation.yield(.offline)
        try await waitUntil {
            if case .error(let error) = model.refreshState {
                return (error as? URLError)?.code == .notConnectedToInternet
            }
            return false
        }
        await repository.configure(result: .success([full]))
        connectivity.continuation.yield(.online)
        try await waitUntil {
            if case .success = model.refreshState { return true }
            return false
        }
        model.cancel()
        let count = await repository.refreshCount
        connectivity.continuation.yield(.offline)
        connectivity.continuation.yield(.online)
        try await Task.sleep(for: .milliseconds(50))
        #expect(await repository.refreshCount == count)
    }
}

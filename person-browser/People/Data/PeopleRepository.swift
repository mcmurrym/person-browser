import Foundation

nonisolated protocol PeopleRepository: Sendable {
    func savedPeople() async throws -> [Person]?
    func savedPerson(id: String) async throws -> Person?
    func refreshPeople() async throws -> [Person]
    func refreshPerson(id: String) async throws -> Person
}

actor RecordsRepository: PeopleRepository {
    static let serviceURL = URL(string: "https://fs-records-sample.vercel.app/")!
    private let client: any HTTPClient
    private let store: any PeopleStore
    private let baseURL: URL

    init(client: any HTTPClient, store: any PeopleStore, baseURL: URL = serviceURL) {
        self.client = client
        self.store = store
        self.baseURL = baseURL
    }

    func savedPeople() async throws -> [Person]? { try await store.savedPeople() }
    func savedPerson(id: String) async throws -> Person? { try await store.person(id: id) }

    func refreshPeople() async throws -> [Person] {
        let data = try await client.data(from: baseURL.appending(path: "persons.json"))
        let response = try JSONDecoder().decode(PeopleResponse.self, from: data)
        let people = try response.persons.map { try $0.person(baseURL: baseURL, fullProfile: false) }
        guard response.count == people.count, Set(people.map(\.id)).count == people.count else { throw BrowserError.invalidResponse }
        try Task.checkCancellation()
        try await store.saveList(people)
        return try await store.savedPeople() ?? []
    }

    func refreshPerson(id: String) async throws -> Person {
        let data = try await client.data(from: baseURL.appending(path: "persons").appending(component: id + ".json"))
        let response = try JSONDecoder().decode(PersonResponse.self, from: data)
        let person = try response.person(baseURL: baseURL, fullProfile: true)
        guard person.id == id else { throw BrowserError.invalidResponse }
        try Task.checkCancellation()
        try await store.saveProfile(person)
        return person
    }
}

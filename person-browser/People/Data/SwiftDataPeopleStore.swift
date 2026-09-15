import Foundation
import SwiftData

@ModelActor
actor SwiftDataPeopleStore: PeopleStore {
    static func make(url: URL? = nil) async throws -> SwiftDataPeopleStore {
        try await Task.detached {
            let schema = Schema([StoredPerson.self, StoredList.self, StoredPortrait.self])
            let configuration: ModelConfiguration
            if let url {
                configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            } else {
                configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            }
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let store = SwiftDataPeopleStore(modelContainer: container)
            return store
        }.value
    }

    func savedPeople() throws -> [Person]? {
        guard try modelContext.fetchCount(FetchDescriptor<StoredList>()) > 0 else { return nil }
        let query = FetchDescriptor<StoredPerson>(predicate: #Predicate { $0.listOrder != nil }, sortBy: [SortDescriptor(\.listOrder)])
        return try modelContext.fetch(query).map { try $0.value() }
    }

    func person(id: String) throws -> Person? { try record(id: id)?.value() }

    private func record(id: String) throws -> StoredPerson? {
        var query = FetchDescriptor<StoredPerson>(predicate: #Predicate { $0.id == id })
        query.fetchLimit = 1
        return try modelContext.fetch(query).first
    }

    func saveList(_ people: [Person]) throws {
        try write {
            for record in try modelContext.fetch(FetchDescriptor<StoredPerson>(predicate: #Predicate { $0.listOrder != nil })) {
                record.listOrder = nil
            }
            for (index, person) in people.enumerated() {
                let stored = try upsert(person)
                stored.listOrder = index
            }
            if try modelContext.fetchCount(FetchDescriptor<StoredList>()) == 0 { modelContext.insert(StoredList()) }
        }
    }

    func saveProfile(_ person: Person) throws {
        try write { _ = try upsert(person) }
    }

    private func upsert(_ person: Person) throws -> StoredPerson {
        let stored: StoredPerson
        if let existing = try record(id: person.id) { stored = existing }
        else {
            stored = StoredPerson(person)
            modelContext.insert(stored)
        }
        try stored.update(person)
        return stored
    }

    func portrait(url: URL) throws -> Data? {
        let key = url.absoluteString
        var query = FetchDescriptor<StoredPortrait>(predicate: #Predicate { $0.url == key })
        query.fetchLimit = 1
        return try modelContext.fetch(query).first?.data
    }

    func savePortrait(_ data: Data, url: URL) throws {
        try write {
            let key = url.absoluteString
            var query = FetchDescriptor<StoredPortrait>(predicate: #Predicate { $0.url == key })
            query.fetchLimit = 1
            if let record = try modelContext.fetch(query).first { record.data = data }
            else { modelContext.insert(StoredPortrait(url: url, data: data)) }
        }
    }

    private func write(_ operation: () throws -> Void) throws {
        do {
            modelContext.autosaveEnabled = false
            try operation()
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw BrowserError.persistence
        }
    }
}

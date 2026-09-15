import Foundation

nonisolated protocol PeopleStore: Sendable {
    func savedPeople() async throws -> [Person]?
    func person(id: String) async throws -> Person?
    func saveList(_ people: [Person]) async throws
    func saveProfile(_ person: Person) async throws
    func portrait(url: URL) async throws -> Data?
    func savePortrait(_ data: Data, url: URL) async throws
}

import Foundation

nonisolated struct LifeEvent: Codable, Sendable, Equatable {
    let date: String
    let year: Int
    let place: String
}

nonisolated struct Relative: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let relationship: String
    let name: String
    let birthYear: Int
    let deathYear: Int?

    var lifespan: String { "\(birthYear)–\(deathYear.map(String.init) ?? "Living")" }
}

nonisolated struct Source: Codable, Sendable, Equatable {
    let title: String
    let citation: String
}

nonisolated struct ProfileDetails: Codable, Sendable, Equatable {
    let occupation: String?
    let biography: String
    let relatives: [Relative]
    let sources: [Source]
    let lastModified: String
}

nonisolated struct Person: Sendable, Identifiable, Equatable {
    let id: String
    let givenName: String
    let surname: String
    let living: Bool
    let birth: LifeEvent
    let death: LifeEvent?
    let portraitURL: URL
    let details: ProfileDetails?

    var name: String { "\(givenName) \(surname)" }
    var lifespan: String { "\(birth.year)–\(living ? "Living" : death.map { String($0.year) } ?? "Unknown")" }
}

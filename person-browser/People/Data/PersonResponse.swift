import Foundation

nonisolated struct PeopleResponse: Decodable, Sendable {
    let updated: String
    let count: Int
    let persons: [PersonResponse]
}

nonisolated struct PersonResponse: Decodable, Sendable {
    struct Name: Decodable, Sendable {
        let given: String
        let surname: String
    }
    struct Event: Decodable, Sendable {
        let date: String
        let year: Int
        let place: String
        var value: LifeEvent { LifeEvent(date: date, year: year, place: place) }
    }
    struct FamilyMember: Decodable, Sendable {
        let id: String
        let relationship: String
        let name: Name
        let birthYear: Int
        let deathYear: Int?
        var value: Relative {
            Relative(id: id, relationship: relationship, name: "\(name.given) \(name.surname)", birthYear: birthYear, deathYear: deathYear)
        }
    }
    struct Citation: Decodable, Sendable {
        let title: String
        let citation: String
        var value: Source { Source(title: title, citation: citation) }
    }
    let id: String
    let name: Name
    let living: Bool
    let birth: Event
    let death: Event?
    let portraitUrl: String
    let occupation: String?
    let biography: String?
    let relatives: [FamilyMember]?
    let sources: [Citation]?
    let lastModified: String?

    func person(baseURL: URL, fullProfile: Bool) throws -> Person {
        guard id.isNotEmpty,
              let url = URL(string: portraitUrl, relativeTo: baseURL)?.absoluteURL,
              url.scheme == "https", url.host == baseURL.host else { throw BrowserError.invalidResponse }
        var details: ProfileDetails?
        if fullProfile {
            guard let biography, let relatives, let sources, let lastModified else { throw BrowserError.invalidResponse }
            details = ProfileDetails(occupation: occupation, biography: biography, relatives: relatives.map(\.value), sources: sources.map(\.value), lastModified: lastModified)
        }
        return Person(id: id, givenName: name.given, surname: name.surname, living: living, birth: birth.value, death: death?.value, portraitURL: url, details: details)
    }
}

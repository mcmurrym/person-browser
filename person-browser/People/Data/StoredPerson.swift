import Foundation
import SwiftData

@Model
nonisolated final class StoredPerson {
    @Attribute(.unique) var id: String
    var givenName: String
    var surname: String
    var living: Bool
    var birthDate: String
    var birthYear: Int
    var birthPlace: String
    var deathDate: String?
    var deathYear: Int?
    var deathPlace: String?
    var portraitURL: String
    var listOrder: Int?
    var profileLoaded: Bool
    var profileData: Data?

    init(_ person: Person) {
        id = person.id
        givenName = person.givenName
        surname = person.surname
        living = person.living
        birthDate = person.birth.date
        birthYear = person.birth.year
        birthPlace = person.birth.place
        deathDate = person.death?.date
        deathYear = person.death?.year
        deathPlace = person.death?.place
        portraitURL = person.portraitURL.absoluteString
        profileLoaded = false
    }

    func update(_ person: Person) throws {
        givenName = person.givenName
        surname = person.surname
        living = person.living
        birthDate = person.birth.date
        birthYear = person.birth.year
        birthPlace = person.birth.place
        deathDate = person.death?.date
        deathYear = person.death?.year
        deathPlace = person.death?.place
        portraitURL = person.portraitURL.absoluteString
        if let details = person.details {
            profileData = try JSONEncoder().encode(details)
            profileLoaded = true
        }
    }

    func value() throws -> Person {
        guard let url = URL(string: portraitURL) else { throw BrowserError.persistence }
        var death: LifeEvent?
        if let deathDate, let deathYear, let deathPlace {
            death = LifeEvent(date: deathDate, year: deathYear, place: deathPlace)
        }
        let details = try profileData.map { try JSONDecoder().decode(ProfileDetails.self, from: $0) }
        guard !profileLoaded || details != nil else { throw BrowserError.persistence }
        return Person(id: id, givenName: givenName, surname: surname, living: living,
                      birth: LifeEvent(date: birthDate, year: birthYear, place: birthPlace),
                      death: death, portraitURL: url, details: details)
    }
}

@Model
nonisolated final class StoredList {
    @Attribute(.unique) var key: String
    init() { key = "people" }
}

@Model
nonisolated final class StoredPortrait {
    @Attribute(.unique) var url: String
    @Attribute(.externalStorage) var data: Data
    init(url: URL, data: Data) {
        self.url = url.absoluteString
        self.data = data
    }
}

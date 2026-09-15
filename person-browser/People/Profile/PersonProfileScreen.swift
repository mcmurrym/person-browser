import SwiftUI

struct PersonProfileScreen: View {
    private let portraits: any PortraitLoading
    @State private var model: PersonProfileViewModel
    @State private var retry = 0

    init(id: String, repository: any PeopleRepository, portraits: any PortraitLoading) {
        self.portraits = portraits
        _model = State(initialValue: PersonProfileViewModel(id: id, repository: repository))
    }

    var body: some View {
        Group {
            switch model.state {
            case .initial, .loading:
                ProgressView("Loading profile…")
            case .error(let error):
                LoadFailureView(title: "Couldn’t load profile", error: error) { retry += 1 }
            case .success(let person):
                profile(person)
                    .refreshable { await model.load() }
            }
        }
        .navigationTitle(model.state.value?.name ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: retry) { await model.load() }
    }

    private func profile(_ person: Person) -> some View {
        List {
            Section {
                VStack(alignment: .center, spacing: 12) {
                    PortraitView(url: person.portraitURL, name: person.name, size: 180, loader: portraits)
                    Text(person.name).font(.title2.bold()).multilineTextAlignment(.center)
                    Text(person.lifespan).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            Section("Birth") {
                Text(person.birth.date)
                Text(person.birth.place).foregroundStyle(.secondary)
            }
            if let death = person.death {
                Section("Death") {
                    Text(death.date)
                    Text(death.place).foregroundStyle(.secondary)
                }
            }
            if let details = person.details {
                if let occupation = details.occupation, !occupation.isEmpty {
                    Section("Occupation") { Text(occupation) }
                }
                Section("Biography") {
                    Text(details.biography.isEmpty ? "No biography available." : details.biography)
                }
                Section("Relatives") {
                    if details.relatives.isEmpty { Text("No relatives listed.").foregroundStyle(.secondary) }
                    ForEach(Array(details.relatives.enumerated()), id: \.offset) { _, relative in
                        NavigationLink(value: relative.id) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(relative.name).font(.headline)
                                Text(relative.relationship.capitalized)
                                Text(relative.lifespan).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if !details.sources.isEmpty {
                    Section("Sources") {
                        ForEach(Array(details.sources.enumerated()), id: \.offset) { _, source in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(source.title)
                                Text(source.citation).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section { RefreshStatusView(state: model.refreshState) { retry += 1 } }
            } else {
                Section {
                    switch model.refreshState {
                    case .error(let error):
                        LoadFailureView(title: "Profile details unavailable", error: offlineError(error)) { retry += 1 }
                    default:
                        ProgressView("Loading profile details…")
                    }
                }
            }
        }
    }

    private func offlineError(_ error: Error) -> Error {
        if let urlError = error as? URLError,
           [.notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .timedOut].contains(urlError.code) {
            return BrowserError.unavailableProfile
        }
        return error
    }
}

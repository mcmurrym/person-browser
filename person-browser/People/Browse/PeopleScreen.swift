import SwiftUI

struct PeopleScreen: View {
    private let repository: any PeopleRepository
    private let portraits: any PortraitLoading
    @State private var model: PeopleViewModel
    @State private var retry = 0

    init(repository: any PeopleRepository, portraits: any PortraitLoading) {
        self.repository = repository
        self.portraits = portraits
        _model = State(initialValue: PeopleViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .initial, .loading:
                    ProgressView("Loading people…")
                case .error(let error):
                    LoadFailureView(title: "Couldn’t load people", error: error) { retry += 1 }
                case .success(let people):
                    List {
                        RefreshStatusView(state: model.refreshState) { retry += 1 }
                        if people.isEmpty {
                            ContentUnavailableView("No people", systemImage: "person.2", description: Text("There are no people to display."))
                        }
                        ForEach(people) { person in
                            NavigationLink(value: person.id) {
                                PersonRowView(person: person, portraits: portraits)
                            }
                        }
                    }
                    .refreshable { await model.load() }
                }
            }
            .navigationTitle("People")
            .navigationDestination(for: String.self) { id in
                PersonProfileScreen(id: id, repository: repository, portraits: portraits)
            }
            .task(id: retry) { await model.load() }
        }
    }
}

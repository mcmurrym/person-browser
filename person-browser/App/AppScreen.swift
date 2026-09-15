import SwiftUI

struct AppScreen: View {
    @State private var model = AppViewModel()
    @State private var retry = 0
    var body: some View {
        Group {
            switch model.state {
            case .initial, .loading:
                ProgressView("Opening saved records…")
            case .success(let services):
                PeopleScreen(repository: services.people, portraits: services.portraits)
            case .error(let error):
                LoadFailureView(title: "Couldn’t open saved records", error: error) { retry += 1 }
            }
        }
        .task(id: retry) { await model.load() }
    }
}

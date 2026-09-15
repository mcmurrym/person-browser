import SwiftUI

struct AppScreen: View {
    @State private var model = AppViewModel()
    var body: some View {
        ZStack {
            switch model.state {
            case .initial, .loading:
                ProgressView("Opening saved records…")
            case .success(let services):
                PeopleScreen(repository: services.people, portraits: services.portraits)
            case .error(let error):
                LoadFailureView(title: "Couldn’t open saved records", error: error) { model.load() }
            }
        }
        .task { model.load() }
        .onDisappear { model.cancel() }
    }
}

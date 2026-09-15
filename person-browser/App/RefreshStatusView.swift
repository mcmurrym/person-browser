import SwiftUI

struct RefreshStatusView: View {
    let state: VoidDataLoadState
    let retry: () -> Void

    var body: some View {
        switch state {
        case .initial, .success:
            EmptyView()
        case .loading:
            HStack { ProgressView(); Text("Updating…").foregroundStyle(.secondary) }
        case .error(let error):
            VStack(alignment: .leading, spacing: 8) {
                Label("Couldn’t update saved content", systemImage: "exclamationmark.triangle")
                Text(error.localizedDescription).font(.footnote).foregroundStyle(.secondary)
                Button("Retry", action: retry)
            }
        }
    }
}

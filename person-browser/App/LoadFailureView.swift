import SwiftUI

struct LoadFailureView: View {
    let title: String
    let error: Error
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Retry", action: retry)
        }
    }
}


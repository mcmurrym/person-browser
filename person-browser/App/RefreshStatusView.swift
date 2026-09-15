import SwiftUI

struct RefreshStatusView: View {
    @Environment(\.colorScheme) private var colorScheme

    let state: VoidDataLoadState
    let retry: () -> Void

    var body: some View {
        switch state {
        case .initial, .success:
            EmptyView()
        case .loading:
            panel {
                HStack { ProgressView(); Text("Updating…").foregroundStyle(.secondary) }
            }
        case .error(let error):
            let message = RefreshFailureMessage(error: error)
            panel(isWarning: true) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(message.title, systemImage: message.symbol)
                        .font(.headline)
                    Text(message.detail)
                        .font(.subheadline)
                        .foregroundStyle(.black.opacity(0.75))
                    Button(action: retry) {
                        Text("Retry")
                            .frame(maxWidth: .infinity)
                    }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        .controlSize(.regular)
                        .tint(.black)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .foregroundStyle(.black)
            }
        }
    }

    private func panel<Content: View>(isWarning: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background {
                if isWarning {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark
                              ? Color(red: 0.90, green: 0.75, blue: 0.30)
                              : Color(red: 0.98, green: 0.87, blue: 0.48))
                } else {
                    RoundedRectangle(cornerRadius: 16).fill(.regularMaterial)
                }
            }
            .textCase(nil)
            .padding(.bottom, 8)
    }
}

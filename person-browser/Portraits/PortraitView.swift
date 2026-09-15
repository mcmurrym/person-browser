import SwiftUI

struct PortraitView: View {
    let url: URL
    let name: String
    let size: CGFloat
    @Environment(\.displayScale) private var displayScale
    @State private var model: PortraitViewModel
    @State private var retry = 0
    @State private var showsError = false

    init(url: URL, name: String, size: CGFloat, loader: any PortraitLoading) {
        self.url = url
        self.name = name
        self.size = size
        _model = State(initialValue: PortraitViewModel(loader: loader))
    }

    var body: some View {
        Group {
            switch model.state {
            case .initial, .loading:
                ProgressView().accessibilityLabel("Loading portrait of \(name)")
            case .success(let portrait):
                Image(decorative: portrait.image, scale: displayScale)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel("Portrait of \(name)")
                    .accessibilityIdentifier("portrait.\(url.lastPathComponent)")
            case .error:
                Button { showsError = true } label: {
                    Image(systemName: "person.crop.square.badge.exclamationmark")
                        .font(.title2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Portrait of \(name) unavailable. Show details and retry.")
            }
        }
        .frame(width: size, height: size)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: "\(url.absoluteString)-\(size)-\(displayScale)-\(retry)") {
            await model.load(url: url, pixels: Int(size * displayScale))
        }
        .alert("Portrait unavailable", isPresented: $showsError) {
            Button("Retry") { retry += 1 }
            Button("Cancel", role: .cancel) {}
        } message: {
            if case .error(let error) = model.state { Text(error.localizedDescription) }
        }
    }
}

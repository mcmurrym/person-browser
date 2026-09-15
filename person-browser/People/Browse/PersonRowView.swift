import SwiftUI

struct PersonRowView: View {
    let person: Person
    let portraits: any PortraitLoading
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var portraitSize = 56

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            PortraitView(url: person.portraitURL, name: person.name, size: min(portraitSize, 84), loader: portraits)
            VStack(alignment: .leading, spacing: 4) {
                Text(person.name).font(.headline)
                Text(person.lifespan).font(.subheadline)
                Text(person.birth.place).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

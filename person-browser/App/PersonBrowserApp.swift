import SwiftUI

@main
struct PersonBrowserApp: App {
    var body: some Scene {
        WindowGroup {
            AppScreen()
                #if DEBUG
                .preferredColorScheme(
                    ProcessInfo.processInfo.arguments.contains("--ui-testing") &&
                    ProcessInfo.processInfo.arguments.contains("--dark-appearance") ? .dark : nil
                )
                #endif
        }
    }
}

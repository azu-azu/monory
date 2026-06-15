import SwiftUI

@main
struct MonoryApp: App {
    @State private var appContainer = AppContainer()

    init() {
        HapticManager.prepare()
    }

    var body: some Scene {
        WindowGroup {
            MovieLogListView()
        }
        .modelContainer(appContainer.modelContainer)
    }
}

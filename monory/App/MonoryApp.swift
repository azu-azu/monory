import SwiftUI

@main
struct MonoryApp: App {
    @State private var appContainer = AppContainer()
    @State private var streamingStore = StreamingServiceStore()

    init() {
        HapticManager.prepare()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(streamingStore)
        }
        .modelContainer(appContainer.modelContainer)
    }
}

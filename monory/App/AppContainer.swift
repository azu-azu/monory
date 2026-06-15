import SwiftData

@MainActor
final class AppContainer {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([MovieLog.self, TicketImage.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}

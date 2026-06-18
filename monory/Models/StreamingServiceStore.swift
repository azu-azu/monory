import Foundation
import Observation

@Observable
final class StreamingServiceStore {
    static let defaultServices: [String] = [
        "Netflix", "Prime Video", "Disney+", "Apple TV+",
        "YouTube", "U-NEXT", "Hulu", "dアニメストア", "ABEMA",
    ]
    static let otherOption = "その他"
    private static let userDefaultsKey = "streamingServiceOrder"

    var services: [String] {
        didSet { Self.persist(services) }
    }

    init() {
        services = Self.loadServices()
    }

    /// init() のような非 async/non-environment コンテキストから直接読む用
    static func loadServices() -> [String] {
        guard
            let data = UserDefaults.standard.data(forKey: userDefaultsKey),
            let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return defaultServices }
        return decoded
    }

    private static func persist(_ services: [String]) {
        let data = try? JSONEncoder().encode(services)
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}

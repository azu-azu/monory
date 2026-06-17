import SwiftData
import Foundation

@Model
final class ViewingDate {
    var id: UUID = UUID()
    var date: Date = Date()
    var movieLog: MovieLog?

    init(date: Date = Date()) {
        self.date = date
    }
}

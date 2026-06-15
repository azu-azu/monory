import SwiftData
import Foundation

@Model
final class TicketImage {
    var id: UUID = UUID()

    @Attribute(.externalStorage)
    var imageData: Data

    var createdAt: Date = Date()
    var ocrRawText: String?

    var movieLog: MovieLog?

    init(imageData: Data, movieLog: MovieLog? = nil) {
        self.imageData = imageData
        self.movieLog = movieLog
    }
}

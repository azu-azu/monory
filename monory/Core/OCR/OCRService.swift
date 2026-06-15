import Vision
import UIKit

enum OCRService {
    /// Vision framework でテキスト認識。バックグラウンドスレッドで実行する。
    static func recognizeText(from imageData: Data) async -> String? {
        await Task.detached(priority: .userInitiated) {
            guard let cgImage = UIImage(data: imageData)?.cgImage else { return nil }
            return await withCheckedContinuation { continuation in
                let request = VNRecognizeTextRequest { req, _ in
                    let text = (req.results as? [VNRecognizedTextObservation] ?? [])
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")
                    continuation.resume(returning: text.isEmpty ? nil : text)
                }
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["ja", "en"]
                request.usesLanguageCorrection = true
                try? VNImageRequestHandler(cgImage: cgImage).perform([request])
            }
        }.value
    }
}

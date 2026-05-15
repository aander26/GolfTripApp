import Foundation
import Vision
import UIKit
import CoreGraphics

/// A single recognized text fragment from Vision, normalized to image-pixel coordinates.
struct OCRObservation: Hashable {
    /// Recognized text (top candidate).
    let text: String
    /// Bounding box in image pixel coordinates, origin top-left.
    let boundingBox: CGRect
    /// Vision's confidence in `text`, 0.0–1.0.
    let confidence: Float
}

enum ScorecardOCRError: Error, LocalizedError {
    case noImageData
    case cgImageUnavailable
    case requestFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noImageData: return "No image was provided."
        case .cgImageUnavailable: return "The selected image could not be read."
        case .requestFailed(let err): return "Text recognition failed: \(err.localizedDescription)"
        }
    }
}

/// Wraps `VNRecognizeTextRequest` and returns a flat list of recognized fragments
/// with absolute (top-left origin, image-pixel) bounding boxes.
enum ScorecardOCRService {
    static func recognize(in image: UIImage) async throws -> [OCRObservation] {
        guard let cg = image.cgImage else { throw ScorecardOCRError.cgImageUnavailable }
        let pixelSize = CGSize(width: cg.width, height: cg.height)
        let orientation = cgImageOrientation(from: image.imageOrientation)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: ScorecardOCRError.requestFailed(error))
                    return
                }
                let results = (request.results as? [VNRecognizedTextObservation]) ?? []
                let observations: [OCRObservation] = results.compactMap { obs in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    let rect = denormalize(obs.boundingBox, imageSize: pixelSize)
                    return OCRObservation(
                        text: candidate.string,
                        boundingBox: rect,
                        confidence: candidate.confidence
                    )
                }
                continuation.resume(returning: observations)
            }
            // Numbers + short labels — accurate mode handles handwritten digits noticeably better.
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            // English covers "OUT", "IN", "TOT", "HCP", player names.
            request.recognitionLanguages = ["en-US"]
            // Score numerals are small relative to the card — lower the floor.
            request.minimumTextHeight = 0.012

            let handler = VNImageRequestHandler(
                cgImage: cg,
                orientation: orientation,
                options: [:]
            )
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: ScorecardOCRError.requestFailed(error))
                }
            }
        }
    }

    /// Vision returns bounding boxes in normalized [0,1] coords with origin at bottom-left.
    /// Convert to absolute image pixels with origin at top-left for easier downstream math.
    private static func denormalize(_ normalized: CGRect, imageSize: CGSize) -> CGRect {
        let x = normalized.minX * imageSize.width
        let width = normalized.width * imageSize.width
        let height = normalized.height * imageSize.height
        let y = (1.0 - normalized.maxY) * imageSize.height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func cgImageOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

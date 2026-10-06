import Foundation
@preconcurrency import Vision
import UIKit
import CoreImage

enum ReceiptScanner {
    static func suggestedCrop(for image: UIImage) async -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }
        return try? await ReceiptImagePreprocessor.suggestedCrop(in: cgImage)
    }

    static func recognize(_ image: UIImage, cropRect: CGRect? = nil) async throws -> ReceiptScanResult {
        guard let cgImage = image.cgImage else { throw ScannerError.invalidImage }
        let preparation = try await ReceiptImagePreprocessor.prepare(cgImage, cropRect: cropRect)
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error { continuation.resume(throwing: error); return }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let text = ReceiptTextLayout.visionOrderWithAttachedMeasurements(from: observations)
                continuation.resume(returning: ReceiptScanResult(lines: ReceiptParser.parse(text: text), quality: preparation.quality, wasAutoCropped: preparation.wasAutoCropped))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["fr-FR", "en-US"]
            DispatchQueue.global(qos: .userInitiated).async {
                do { try VNImageRequestHandler(cgImage: preparation.image, options: [:]).perform([request]) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}

/// Keep Vision's native reading order, which is more reliable on skewed or creased
/// receipts. Geometry is used only to attach an isolated weight to the closest
/// description on its right, such as `100G` + `EMMENTAL RAPE`.
private enum ReceiptTextLayout {
    private struct Fragment {
        let text: String
        let box: CGRect
    }

    static func visionOrderWithAttachedMeasurements(from observations: [VNRecognizedTextObservation]) -> String {
        let fragments = observations.compactMap { observation -> Fragment? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return Fragment(text: text, box: observation.boundingBox)
        }
        guard !fragments.isEmpty else { return "" }

        let measurements = fragments.filter { isMeasurementOnly($0.text) }
        return fragments
            .map { fragment in
                guard hasLetters(fragment.text), !containsMeasurement(fragment.text),
                      let measurement = closestMeasurement(to: fragment, in: measurements) else {
                    return fragment.text
                }
                return "\(measurement.text) \(fragment.text)"
            }
            .joined(separator: "\n")
    }

    private static func closestMeasurement(to fragment: Fragment, in measurements: [Fragment]) -> Fragment? {
        measurements
            // A quantity is printed before the product description, not in the price column.
            .filter { $0.box.maxX <= fragment.box.minX + 0.015 }
            .filter { abs($0.box.midY - fragment.box.midY) <= max(fragment.box.height, $0.box.height) * 1.35 + 0.004 }
            .min { (fragment.box.minX - $0.box.maxX) < (fragment.box.minX - $1.box.maxX) }
    }

    private static func hasLetters(_ text: String) -> Bool {
        text.rangeOfCharacter(from: .letters) != nil
    }

    private static func containsMeasurement(_ text: String) -> Bool {
        measurementExpression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func isMeasurementOnly(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = measurementOnlyExpression.firstMatch(in: text, range: range) else { return false }
        return match.range == range
    }

    private static let measurementExpression = try! NSRegularExpression(
        pattern: "(?:\\d+\\s*[x×]\\s*)?\\d+(?:[,.]\\d+)?\\s*(?:kg|g|cl|ml|l)\\b",
        options: [.caseInsensitive]
    )
    private static let measurementOnlyExpression = try! NSRegularExpression(
        pattern: "^\\s*\\*?\\s*(?:\\d+\\s*[x×]\\s*)?\\d+(?:[,.]\\d+)?\\s*(?:kg|g|cl|ml|l)\\s*$",
        options: [.caseInsensitive]
    )
}

struct ReceiptScanResult {
    let lines: [ParsedReceiptLine]
    let quality: ReceiptImageQuality
    let wasAutoCropped: Bool
}

enum ReceiptImageQuality: Equatable {
    case good
    case lowResolution
    case blurry
    var warning: String? {
        switch self {
        case .good: nil
        case .lowResolution: "Image trop petite : rapprochez-vous du ticket pour une lecture plus fiable."
        case .blurry: "Image possiblement floue : posez le ticket à plat et maintenez le téléphone immobile."
        }
    }
}

private enum ReceiptImagePreprocessor {
    private static let context = CIContext(options: nil)

    static func prepare(_ original: CGImage, cropRect: CGRect?) async throws -> (image: CGImage, quality: ReceiptImageQuality, wasAutoCropped: Bool) {
        let cropped = cropRect.flatMap { crop(original, to: $0) }
        let source = cropped ?? original
        // Keep every source pixel in the chosen crop. This alters colour only, never dimensions.
        return (ocrContrastImage(from: source), evaluate(source), cropped != nil)
    }

    static func suggestedCrop(in image: CGImage) async throws -> CGRect? {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let rectangleRequest = VNDetectRectanglesRequest()
                rectangleRequest.maximumObservations = 8
                rectangleRequest.minimumSize = 0.12
                rectangleRequest.quadratureTolerance = 25

                // On glossy, creased tickets the paper edge can be ambiguous. Text
                // boxes provide a second, often more reliable, local crop proposal.
                let textRequest = VNRecognizeTextRequest()
                textRequest.recognitionLevel = .fast
                textRequest.usesLanguageCorrection = false
                textRequest.recognitionLanguages = ["fr-FR", "en-US"]

                do {
                    try VNImageRequestHandler(cgImage: image, options: [:]).perform([rectangleRequest, textRequest])
                    let rectangles = (rectangleRequest.results as? [VNRectangleObservation]) ?? []
                    let textBoxes = (textRequest.results as? [VNRecognizedTextObservation])?
                        .filter { $0.topCandidates(1).first?.string.count ?? 0 >= 2 }
                        .map(\.boundingBox) ?? []
                    continuation.resume(returning: bestCrop(rectangles: rectangles, textBoxes: textBoxes))
                }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    private static func bestCrop(rectangles: [VNRectangleObservation], textBoxes: [CGRect]) -> CGRect? {
        let textBounds = textBoxes.reduce(nil as CGRect?) { partial, box in
            guard let partial else { return box }
            return partial.union(box)
        }.map(expandTextBounds)

        let bestRectangle = rectangles
            .map(\.boundingBox)
            // A shopping receipt photographed in portrait is tall. Small, flat
            // rectangles are normally text bands, reflections, or table edges.
            .filter { $0.width >= 0.12 && $0.height >= 0.55 && $0.height / max($0.width, 0.01) >= 1.20 }
            .filter { rectangle in
                guard let textBounds else { return rectangle.width * rectangle.height >= 0.20 }
                let overlap = rectangle.intersection(textBounds).area
                return overlap / max(textBounds.area, 0.0001) >= 0.80 && rectangle.area >= textBounds.area * 1.05
            }
            .max { rectangleScore($0, textBounds: textBounds) < rectangleScore($1, textBounds: textBounds) }

        // Prefer a credible paper outline. When edge detection is uncertain, crop to
        // the recognised text rather than displaying an arbitrary central rectangle.
        let selected = bestRectangle ?? textBounds.map(tallReceiptFallback)
        guard let selected else { return nil }
        return CGRect(x: selected.minX, y: 1 - selected.maxY, width: selected.width, height: selected.height)
    }

    private static func rectangleScore(_ rectangle: CGRect, textBounds: CGRect?) -> CGFloat {
        let area = rectangle.area
        let longSide = max(rectangle.width, rectangle.height)
        let shortSide = max(min(rectangle.width, rectangle.height), 0.01)
        let receiptShapeBonus = min(longSide / shortSide, 4) * 0.06
        guard let textBounds else { return area + receiptShapeBonus }
        let coverage = rectangle.intersection(textBounds).area / max(textBounds.area, 0.0001)
        return area + receiptShapeBonus + coverage * 0.4
    }

    private static func expandTextBounds(_ bounds: CGRect) -> CGRect {
        bounds
            .insetBy(dx: -0.035, dy: -0.02)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    private static func tallReceiptFallback(from textBounds: CGRect) -> CGRect {
        let width = min(max(textBounds.width + 0.08, 0.28), 0.92)
        // When edge detection cannot see the paper, favour a generous portrait
        // frame. It is safer to retain a little background than cut off receipt rows.
        let height: CGFloat = 0.92
        return CGRect(x: textBounds.midX - width / 2, y: 0.04, width: width, height: height)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    static func crop(_ image: CGImage, to normalizedRect: CGRect) -> CGImage? {
        let clamped = normalizedRect.standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard clamped.width > 0.08, clamped.height > 0.08 else { return nil }
        let pixelRect = CGRect(
            x: clamped.minX * CGFloat(image.width),
            y: clamped.minY * CGFloat(image.height),
            width: clamped.width * CGFloat(image.width),
            height: clamped.height * CGFloat(image.height)
        ).integral
        return image.cropping(to: pixelRect)
    }

    static func ocrContrastImage(from image: CGImage) -> CGImage {
        guard let filter = CIFilter(name: "CIColorControls") else { return image }
        filter.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
        filter.setValue(0, forKey: kCIInputSaturationKey)
        filter.setValue(1.65, forKey: kCIInputContrastKey)
        filter.setValue(0.02, forKey: kCIInputBrightnessKey)
        guard let output = filter.outputImage else { return image }
        return context.createCGImage(output, from: output.extent) ?? image
    }

    static func evaluate(_ image: CGImage) -> ReceiptImageQuality {
        guard image.width >= 900, image.height >= 900 else { return .lowResolution }
        guard let provider = image.dataProvider, let data = provider.data, let bytes = CFDataGetBytePtr(data) else { return .good }
        let bytesPerPixel = max(image.bitsPerPixel / 8, 1)
        let rowStride = max(image.bytesPerRow, 1)
        let sampleStep = max(min(image.width, image.height) / 160, 4)
        var contrast = 0.0
        var samples = 0
        for y in Swift.stride(from: sampleStep, to: image.height - sampleStep, by: sampleStep) {
            for x in Swift.stride(from: sampleStep, to: image.width - sampleStep, by: sampleStep) {
                let offset = y * rowStride + x * bytesPerPixel
                let next = y * rowStride + (x + sampleStep) * bytesPerPixel
                contrast += abs(Double(bytes[offset]) - Double(bytes[next]))
                samples += 1
            }
        }
        return samples > 0 && contrast / Double(samples) < 7 ? .blurry : .good
    }
}

private extension CGRect {
    var area: CGFloat { max(width, 0) * max(height, 0) }
}

enum ScannerError: LocalizedError {
    case invalidImage
    var errorDescription: String? { "Cette image ne peut pas être analysée." }
}

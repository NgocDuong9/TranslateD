import AppKit
import CoreGraphics
@preconcurrency import Vision

final class OCRService {
    enum OCRError: LocalizedError {
        case screenCaptureFailed
        case screenRecordingPermissionRequired
        case noTextFound

        var errorDescription: String? {
            switch self {
            case .screenCaptureFailed:
                return "Could not capture the screen. Grant Screen Recording permission if macOS asks."
            case .screenRecordingPermissionRequired:
                return "Screen Recording permission is required. Enable it in System Settings, then restart the app."
            case .noTextFound:
                return "No text was found on the screen."
            }
        }
    }

    func recognizeScreenText(language: OCRLanguage) async throws -> String {
        try ensureScreenCapturePermission()

        guard let image = CGDisplayCreateImage(CGMainDisplayID()) else {
            throw OCRError.screenCaptureFailed
        }

        return try await recognizeText(in: image, language: language)
    }

    func recognizeScreenText(in rect: CGRect, screen: NSScreen, language: OCRLanguage) async throws -> String {
        try ensureScreenCapturePermission()

        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
        guard let image = CGDisplayCreateImage(displayID) else {
            throw OCRError.screenCaptureFailed
        }

        let screenFrame = screen.frame
        let scaleX = CGFloat(image.width) / screenFrame.width
        let scaleY = CGFloat(image.height) / screenFrame.height
        let cropRect = CGRect(
            x: (rect.minX - screenFrame.minX) * scaleX,
            y: (screenFrame.maxY - rect.maxY) * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        ).integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))

        guard cropRect.width > 0, cropRect.height > 0,
              let croppedImage = image.cropping(to: cropRect) else {
            throw OCRError.screenCaptureFailed
        }

        return try await recognizeText(in: scaledForOCR(croppedImage), language: language)
    }

    private func recognizeText(in image: CGImage, language: OCRLanguage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: text)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = language.recognitionLanguageCodes
            request.minimumTextHeight = 0.005

            let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func ensureScreenCapturePermission() throws {
        if CGPreflightScreenCaptureAccess() {
            return
        }

        _ = CGRequestScreenCaptureAccess()
        throw OCRError.screenRecordingPermissionRequired
    }

    private func scaledForOCR(_ image: CGImage) -> CGImage {
        let scale: CGFloat = 2
        let width = Int(CGFloat(image.width) * scale)
        let height = Int(CGFloat(image.height) * scale)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.interpolationQuality = .high
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
}

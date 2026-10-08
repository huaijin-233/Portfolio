#if os(macOS)
//
//  ScreenshotCaptureService.swift
//  Ink
//
//  Created by Codex on 3/13/26.
//

import Foundation

enum ScreenshotCaptureService {
    static func captureSelection() async throws -> URL? {
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Write-Screenshot-\(UUID().uuidString)")
            .appendingPathExtension("png")

        let executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["-isx", "-t", "png", destinationURL.path]

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                if process.terminationStatus == 0,
                   FileManager.default.fileExists(atPath: destinationURL.path) {
                    continuation.resume(returning: destinationURL)
                    return
                }

                try? FileManager.default.removeItem(at: destinationURL)

                if process.terminationStatus == 1 {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(throwing: ScreenshotCaptureError.captureFailed(status: process.terminationStatus))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
enum ScreenshotCaptureError: LocalizedError {
    case captureFailed(status: Int32)

    var errorDescription: String? {
        switch self {
        case .captureFailed(let status):
            return "Screenshot capture failed with status \(status)."
        }
    }
}
#endif

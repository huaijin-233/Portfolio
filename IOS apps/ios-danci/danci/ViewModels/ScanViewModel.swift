import Combine
import Foundation
import Translation
import UIKit

struct MarkedSelectionDraft: Identifiable {
    let id = UUID()
    let images: [UIImage]
    let source: ScanImageSource
}

@MainActor
final class ScanViewModel: ObservableObject {
    struct AlertState: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private struct PendingScanImport {
        let id: UUID
        let mode: ScanMode
        let imageCount: Int
        let detection: ScanDetectionResult
        let wordsToTranslate: [String]
        let prefetchedNotes: [String: String]
        let usesDetailedTranslation: Bool
    }

    @Published var selectedMode: ScanMode = .normal
    @Published var detailedTranslationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(detailedTranslationEnabled, forKey: Self.detailedTranslationEnabledKey)
        }
    }
    @Published var isPresentingDocumentScanner = false
    @Published var isPresentingPhotoPicker = false
    @Published var isPresentingSourceDialog = false
    @Published var isProcessing = false
    @Published var lastSummary: ScanSummary?
    @Published var alertState: AlertState?
    @Published var translationRequestID: UUID?
    @Published var markedSelectionDraft: MarkedSelectionDraft?

    private let cameraService = CameraService()
    private let scannerService = VisionScannerService()
    private let translationService = WordTranslationService()
    private var pendingScanImport: PendingScanImport?
    private var activeTranslationID: UUID?
    private var translationWatchdogTask: Task<Void, Never>?
    private static let detailedTranslationEnabledKey = "scan.detailedTranslationEnabled"

    init() {
        self.detailedTranslationEnabled = UserDefaults.standard.bool(forKey: Self.detailedTranslationEnabledKey)
    }

    var canUseDocumentScanner: Bool {
        cameraService.supportsDocumentScanner
    }

    func startScan() {
        guard !isProcessing, markedSelectionDraft == nil else { return }

        if canUseDocumentScanner {
            isPresentingSourceDialog = true
        } else {
            if cameraService.isRunningInSimulator {
                alertState = AlertState(
                    title: "已切换为照片导入",
                    message: cameraService.fallbackMessage
                )
            }

            isPresentingPhotoPicker = true
        }
    }

    func startDocumentScan() {
        guard !isProcessing, markedSelectionDraft == nil else { return }

        guard canUseDocumentScanner else {
            alertState = AlertState(
                title: "当前设备不支持文稿扫描",
                message: cameraService.fallbackMessage
            )
            return
        }

        isPresentingDocumentScanner = true
    }

    func startPhotoImport() {
        guard !isProcessing, markedSelectionDraft == nil else { return }

        isPresentingPhotoPicker = true
    }

    func handleDocumentCancellation() {
        isPresentingDocumentScanner = false
    }

    func handleDocumentError(_ error: Error) {
        isPresentingDocumentScanner = false
        alertState = AlertState(
            title: "扫描失败",
            message: "\(error.localizedDescription)\n\n你也可以改用“从照片导入”继续识别英文单词。"
        )
    }

    func presentPhotoImportFailure() {
        alertState = AlertState(
            title: "照片读取失败",
            message: "这张照片暂时无法读取，请换一张清晰一点的英文内容试试。"
        )
    }

    func handleImportedPhoto(_ image: UIImage?, wordStore: WordStore) {
        guard let image else {
            presentPhotoImportFailure()
            return
        }

        process(images: [image], source: .photoImport, wordStore: wordStore)
    }

    func processScannedImages(_ images: [UIImage], wordStore: WordStore) {
        isPresentingDocumentScanner = false
        process(images: images, source: .photoImport, wordStore: wordStore)
    }

    private func process(images: [UIImage], source: ScanImageSource, wordStore: WordStore) {
        guard !isProcessing else { return }

        guard !images.isEmpty else {
            alertState = AlertState(
                title: "没有可识别的页面",
                message: "请重新拍摄或重新选择一张英文内容清晰的图片。"
            )
            return
        }

        let scanImages = images.map { $0.preparedForScanInput() }

        if selectedMode == .marked {
            markedSelectionDraft = MarkedSelectionDraft(images: scanImages, source: source)
            return
        }

        isProcessing = true
        let mode = selectedMode
        let usesDetailedTranslation = detailedTranslationEnabled
        let service = scannerService
        let translationService = self.translationService

        Task.detached(priority: .userInitiated) {
            let result: Result<ScanDetectionResult, Error>

            do {
                let detection = try service.scan(images: scanImages, mode: mode, source: source)
                result = .success(detection)
            } catch {
                result = .failure(error)
            }

            let prefetchedNotes: [String: String]
            if case .success(let detection) = result, detection.detectedCount > 0 {
                if usesDetailedTranslation {
                    prefetchedNotes = await translationService.cachedDetailedTranslations(for: detection.words)
                } else {
                    prefetchedNotes = await translationService.cachedTranslations(for: detection.words)
                }
            } else {
                prefetchedNotes = [:]
            }

            await MainActor.run {
                self.handleScanResult(
                    result,
                    mode: mode,
                    imageCount: scanImages.count,
                    prefetchedNotes: prefetchedNotes,
                    usesDetailedTranslation: usesDetailedTranslation,
                    wordStore: wordStore
                )
            }
        }
    }

    func cancelMarkedSelection() {
        markedSelectionDraft = nil
    }

    func completeMarkedSelection(
        _ selections: [MarkedScanSelection],
        source: ScanImageSource,
        totalPageCount: Int,
        wordStore: WordStore
    ) {
        markedSelectionDraft = nil

        guard !selections.isEmpty else {
            alertState = AlertState(
                title: "还没有选中单词",
                message: "请先用选区笔划过要识别的英文单词，再点击完成。"
            )
            return
        }

        processMarkedSelections(selections, source: source, imageCount: totalPageCount, wordStore: wordStore)
    }

    private func processMarkedSelections(
        _ selections: [MarkedScanSelection],
        source: ScanImageSource,
        imageCount: Int,
        wordStore: WordStore
    ) {
        guard !isProcessing else { return }

        isProcessing = true
        let usesDetailedTranslation = detailedTranslationEnabled
        let translationService = self.translationService
        let service = scannerService

        Task.detached(priority: .userInitiated) {
            let result: Result<ScanDetectionResult, Error>

            do {
                let detection = try service.scanMarkedSelections(selections, source: source)
                result = .success(detection)
            } catch {
                result = .failure(error)
            }

            let prefetchedNotes: [String: String]
            if case .success(let detection) = result, detection.detectedCount > 0 {
                if usesDetailedTranslation {
                    prefetchedNotes = await translationService.cachedDetailedTranslations(for: detection.words)
                } else {
                    prefetchedNotes = await translationService.cachedTranslations(for: detection.words)
                }
            } else {
                prefetchedNotes = [:]
            }

            await MainActor.run {
                self.handleScanResult(
                    result,
                    mode: .marked,
                    imageCount: imageCount,
                    prefetchedNotes: prefetchedNotes,
                    usesDetailedTranslation: usesDetailedTranslation,
                    wordStore: wordStore
                )
            }
        }
    }

    private func handleScanResult(
        _ result: Result<ScanDetectionResult, Error>,
        mode: ScanMode,
        imageCount: Int,
        prefetchedNotes: [String: String],
        usesDetailedTranslation: Bool,
        wordStore: WordStore
    ) {
        switch result {
        case .success(let detection):
            if detection.detectedCount == 0 {
                isProcessing = false
                lastSummary = ScanSummary(
                    mode: mode,
                    pageCount: imageCount,
                    detectedCount: detection.detectedCount,
                    addedCount: 0,
                    createdBookTitle: nil,
                    previewWords: []
                )
                alertState = AlertState(
                    title: "没有识别到英文单词",
                    message: mode == .marked
                        ? "请先用选区笔划过想要识别的英文单词，再试一次。"
                        : "请确认图片中有清晰的英文内容，再扫描一次。"
                )
                return
            }

            let existingNotes = usesDetailedTranslation ? [:] : wordStore.existingNotes(for: detection.words)
            let mergedNotes = prefetchedNotes.merging(existingNotes) { current, _ in current }
            let wordsToTranslate = detection.words.filter {
                guard let normalizedWord = EnglishWordSanitizer.normalize($0, minimumLength: 2) else {
                    return false
                }

                return usesDetailedTranslation || mergedNotes[normalizedWord] == nil
            }

            if wordsToTranslate.isEmpty {
                cancelTranslationWatchdog()
                completeImport(
                    mode: mode,
                    imageCount: imageCount,
                    detection: detection,
                    translatedNotes: mergedNotes,
                    wordStore: wordStore
                )
                return
            }

            let request = PendingScanImport(
                id: UUID(),
                mode: mode,
                imageCount: imageCount,
                detection: detection,
                wordsToTranslate: wordsToTranslate,
                prefetchedNotes: mergedNotes,
                usesDetailedTranslation: usesDetailedTranslation
            )
            pendingScanImport = request
            activeTranslationID = nil
            translationRequestID = request.id
            startTranslationWatchdog(for: request, wordStore: wordStore)

        case .failure(let error):
            cancelTranslationWatchdog()
            isProcessing = false
            alertState = AlertState(
                title: "识别失败",
                message: error.localizedDescription
            )
        }
    }

    @available(iOS 18.0, *)
    func performPendingTranslation(using session: TranslationSession, wordStore: WordStore) async {
        guard let pendingScanImport else { return }
        guard activeTranslationID != pendingScanImport.id else { return }

        activeTranslationID = pendingScanImport.id
        cancelTranslationWatchdog()
        let newlyTranslatedNotes: [String: String]
        if pendingScanImport.usesDetailedTranslation {
            newlyTranslatedNotes = await translationService.translateDetailed(
                words: pendingScanImport.wordsToTranslate,
                using: session
            )
        } else {
            newlyTranslatedNotes = await translationService.translate(
                words: pendingScanImport.wordsToTranslate,
                using: session
            )
        }
        let translatedNotes = pendingScanImport.prefetchedNotes.merging(newlyTranslatedNotes) { current, new in
            pendingScanImport.usesDetailedTranslation ? new : current
        }

        await MainActor.run {
            finalizePendingImport(translatedNotes: translatedNotes, wordStore: wordStore)
        }
    }

    private func finalizePendingImport(translatedNotes: [String: String], wordStore: WordStore) {
        guard let pendingScanImport else {
            cancelTranslationWatchdog()
            isProcessing = false
            translationRequestID = nil
            activeTranslationID = nil
            return
        }

        completeImport(
            mode: pendingScanImport.mode,
            imageCount: pendingScanImport.imageCount,
            detection: pendingScanImport.detection,
            translatedNotes: translatedNotes,
            wordStore: wordStore
        )
    }

    private func completeImport(
        mode: ScanMode,
        imageCount: Int,
        detection: ScanDetectionResult,
        translatedNotes: [String: String],
        wordStore: WordStore
    ) {
        cancelTranslationWatchdog()
        let importResult = wordStore.importScannedWords(
            detection.words,
            translatedNotes: translatedNotes,
            source: mode.source
        )

        lastSummary = ScanSummary(
            mode: mode,
            pageCount: imageCount,
            detectedCount: detection.detectedCount,
            addedCount: importResult.addedEntries.count,
            createdBookTitle: importResult.createdBook?.title,
            previewWords: Array(importResult.addedEntries.prefix(8).map(\.word))
        )

        if importResult.addedEntries.isEmpty {
            alertState = AlertState(
                title: "没有生成新的单词本",
                message: "这次识别到了 \(detection.detectedCount) 个英文词，但没有整理出可收录的新内容。"
            )
        } else if translatedNotes.isEmpty {
            alertState = AlertState(
                title: "已保存英文单词",
                message: "单词已经收进书架，但当前设备的系统翻译暂时没有返回结果。请确认系统翻译资源已就绪后再试。"
            )
        }

        translationRequestID = nil
        pendingScanImport = nil
        activeTranslationID = nil
        isProcessing = false
    }

    private func startTranslationWatchdog(for request: PendingScanImport, wordStore: WordStore) {
        cancelTranslationWatchdog()

        translationWatchdogTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 35_000_000_000)
            guard !Task.isCancelled else { return }
            guard let self, self.pendingScanImport?.id == request.id else { return }

            self.finalizePendingImport(
                translatedNotes: request.prefetchedNotes,
                wordStore: wordStore
            )
        }
    }

    private func cancelTranslationWatchdog() {
        translationWatchdogTask?.cancel()
        translationWatchdogTask = nil
    }
}

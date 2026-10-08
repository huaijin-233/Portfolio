import CoreImage
import CryptoKit
import Foundation
import UIKit
import Vision

struct ScanDetectionResult {
    let words: [String]
    let detectedCount: Int
}

struct MarkedScanSelection {
    let image: UIImage
    let selectionMask: UIImage
    let normalizedRegions: [CGRect]
}

enum ScanImageSource {
    case documentScanner
    case photoImport
}

enum VisionScannerError: LocalizedError {
    case unreadableImage
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "图片暂时无法处理，请换一张更清晰的英文页面。"
        case .recognitionFailed:
            return "文字识别没有成功完成，请稍后再试。"
        }
    }
}

private final class VisionScanCache: @unchecked Sendable {
    nonisolated static let shared = VisionScanCache()

    private let lock = NSLock()
    nonisolated(unsafe) private var results: [String: ScanDetectionResult] = [:]
    nonisolated(unsafe) private var keysInOrder: [String] = []
    private let maxEntries = 24

    nonisolated func result(for key: String) -> ScanDetectionResult? {
        lock.lock()
        defer { lock.unlock() }
        return results[key]
    }

    nonisolated func store(_ result: ScanDetectionResult, for key: String) {
        lock.lock()
        defer { lock.unlock() }

        if results[key] == nil {
            keysInOrder.append(key)
        }

        results[key] = result

        while keysInOrder.count > maxEntries {
            let removedKey = keysInOrder.removeFirst()
            results.removeValue(forKey: removedKey)
        }
    }
}

private enum VisionScanCacheKeyFactory {
    nonisolated static func normal(images: [UIImage], mode: ScanMode, source: ScanImageSource) -> String? {
        let fingerprints = images.compactMap(imageFingerprint)
        guard fingerprints.count == images.count else { return nil }
        return "normal|\(mode.cacheKey)|\(source.cacheKey)|\(fingerprints.joined(separator: "|"))"
    }

    nonisolated static func marked(selections: [MarkedScanSelection], source: ScanImageSource) -> String? {
        let fingerprints = selections.compactMap { selection -> String? in
            guard let imageDigest = imageFingerprint(selection.image),
                  let maskDigest = imageFingerprint(selection.selectionMask) else {
                return nil
            }

            return "\(imageDigest)#\(maskDigest)"
        }

        guard fingerprints.count == selections.count else { return nil }
        return "marked|\(source.cacheKey)|\(fingerprints.joined(separator: "|"))"
    }

    nonisolated private static func imageFingerprint(_ image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }

        let sampleWidth = 16
        let sampleHeight = 16
        let bytesPerPixel = 4
        let bytesPerRow = sampleWidth * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: sampleWidth * sampleHeight * bytesPerPixel)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        var hasher = SHA256()
        hasher.update(data: Data(pixels))
        hasher.update(data: Data("\(cgImage.width)x\(cgImage.height)|\(image.scale)|\(image.imageOrientation.rawValue)".utf8))

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private extension ScanMode {
    nonisolated var cacheKey: String {
        switch self {
        case .normal:
            return "normal"
        case .marked:
            return "marked"
        }
    }
}

private extension ScanImageSource {
    nonisolated var cacheKey: String {
        switch self {
        case .documentScanner:
            return "document"
        case .photoImport:
            return "photo"
        }
    }
}

struct VisionScannerService {
    nonisolated func scan(
        images: [UIImage],
        mode: ScanMode,
        source: ScanImageSource
    ) throws -> ScanDetectionResult {
        let cacheKey = VisionScanCacheKeyFactory.normal(images: images, mode: mode, source: source)
        if let cacheKey, let cachedResult = VisionScanCache.shared.result(for: cacheKey) {
            return cachedResult
        }

        let ciContext = CIContext(options: nil)
        var filteredWords: [String] = []
        var filteredCount = 0
        var hasReadablePage = false

        for image in images {
            guard let preparedPage = preparePage(
                from: image,
                ciContext: ciContext,
                source: source
            ) else {
                continue
            }

            hasReadablePage = true

            let recognizedTokens = try recognizeConsensusWords(on: preparedPage)
            let pageTokens: [RecognizedToken]

            if mode == .marked {
                let markAnalyzer = MarkAnalyzer(markLayers: preparedPage.markLayers)
                let regionMatchedTokens = (try? recognizeMarkedRegionWords(on: preparedPage, using: markAnalyzer)) ?? []
                if regionMatchedTokens.isEmpty {
                    pageTokens = selectMarkedTokens(
                        from: recognizedTokens,
                        using: markAnalyzer,
                        allowsLocalFallback: false
                    )
                } else {
                    pageTokens = regionMatchedTokens
                }
            } else {
                pageTokens = recognizedTokens
            }

            filteredWords.append(contentsOf: pageTokens.map(\.normalizedWord))
            filteredCount += pageTokens.count
        }

        guard hasReadablePage else {
            throw VisionScannerError.unreadableImage
        }

        let result = ScanDetectionResult(
            words: uniqueWordsPreservingOrder(filteredWords),
            detectedCount: filteredCount
        )

        if let cacheKey {
            VisionScanCache.shared.store(result, for: cacheKey)
        }

        return result
    }

    nonisolated func scanMarkedSelections(
        _ selections: [MarkedScanSelection],
        source: ScanImageSource
    ) throws -> ScanDetectionResult {
        let cacheKey = VisionScanCacheKeyFactory.marked(selections: selections, source: source)
        if let cacheKey, let cachedResult = VisionScanCache.shared.result(for: cacheKey) {
            return cachedResult
        }

        let ciContext = CIContext(options: nil)
        var filteredWords: [String] = []
        var filteredCount = 0
        var hasReadablePage = false

        for selection in selections {
            guard let preparedPage = preparePage(
                from: selection.image,
                ciContext: ciContext,
                source: source,
                appliesPerspectiveCorrection: false
            ) else {
                continue
            }

            hasReadablePage = true

            let selectionAnalyzer = UserSelectionAnalyzer(
                maskImage: selection.selectionMask,
                targetWidth: preparedPage.markLayers.width,
                targetHeight: preparedPage.markLayers.height,
                preferredNormalizedRegions: selection.normalizedRegions
            )

            guard selectionAnalyzer.hasSelection else { continue }

            let pageTokens = try recognizeConsensusWords(on: preparedPage)
            var strictlySelected: [RecognizedToken] = []

            for region in selectionAnalyzer.selectionRegions {
                let matches = selectionAnalyzer.strictlySelectedTokens(from: pageTokens, for: region)
                strictlySelected = combineMarkedTokens(primary: strictlySelected, fallback: matches)
            }

            let rescuedTokens = try recognizeSelectedRegionWords(on: preparedPage, using: selectionAnalyzer)
            let resolvedTokens = combineMarkedTokens(primary: strictlySelected, fallback: rescuedTokens)

            filteredWords.append(contentsOf: resolvedTokens.map(\.normalizedWord))
            filteredCount += resolvedTokens.count
        }

        guard hasReadablePage else {
            throw VisionScannerError.unreadableImage
        }

        let result = ScanDetectionResult(
            words: uniqueWordsPreservingOrder(filteredWords),
            detectedCount: filteredCount
        )

        if let cacheKey {
            VisionScanCache.shared.store(result, for: cacheKey)
        }

        return result
    }

    nonisolated private func preparePage(
        from image: UIImage,
        ciContext: CIContext,
        source: ScanImageSource,
        appliesPerspectiveCorrection: Bool = true
    ) -> PreparedPage? {
        let normalizedImage = image.preparedForScanInput(maxDimension: 2400)
        let baseImage: UIImage

        switch source {
        case .photoImport where appliesPerspectiveCorrection:
            baseImage = normalizedImage.perspectiveCorrectedImage(ciContext: ciContext) ?? normalizedImage
        case .photoImport, .documentScanner:
            baseImage = normalizedImage
        }

        guard let primaryImage = baseImage.resizedForAnalysis(maxDimension: 2200) else {
            return nil
        }

        let documentImage: UIImage
        switch source {
        case .documentScanner:
            documentImage = primaryImage
        case .photoImport:
            documentImage = primaryImage.documentScannedImage(ciContext: ciContext) ?? primaryImage
        }

        guard let baseCGImage = documentImage.cgImage,
              let layeredPage = ImageLayerBuilder.build(from: primaryImage, textSourceImage: documentImage) else {
            return nil
        }

        var ocrPasses = [
            OCRPass(
                cgImage: layeredPage.textLayerCGImage,
                weight: 1.0,
                usesLanguageCorrection: true,
                minimumTextHeight: 0.007,
                sourceWidth: baseCGImage.width,
                sourceHeight: baseCGImage.height
            )
        ]

        if let contrastImage = layeredPage.textLayerImage.makeOCRVariant(style: .contrast, ciContext: ciContext),
           let contrastCGImage = contrastImage.cgImage {
            ocrPasses.append(
                OCRPass(
                    cgImage: contrastCGImage,
                    weight: 1.18,
                    usesLanguageCorrection: true,
                    minimumTextHeight: 0.006,
                    sourceWidth: baseCGImage.width,
                    sourceHeight: baseCGImage.height
                )
            )
        }

        if let sharpenedImage = layeredPage.textLayerImage.makeOCRVariant(style: .sharpened, ciContext: ciContext),
           let sharpenedCGImage = sharpenedImage.cgImage {
            ocrPasses.append(
                OCRPass(
                    cgImage: sharpenedCGImage,
                    weight: 1.08,
                    usesLanguageCorrection: false,
                    minimumTextHeight: 0.006,
                    sourceWidth: baseCGImage.width,
                    sourceHeight: baseCGImage.height
                )
            )
        }

        if let thresholdedImage = layeredPage.textLayerImage.makeOCRVariant(style: .thresholded, ciContext: ciContext),
           let thresholdedCGImage = thresholdedImage.cgImage {
            ocrPasses.append(
                OCRPass(
                    cgImage: thresholdedCGImage,
                    weight: 1.12,
                    usesLanguageCorrection: false,
                    minimumTextHeight: 0.005,
                    sourceWidth: baseCGImage.width,
                    sourceHeight: baseCGImage.height
                )
            )
        }

        ocrPasses.append(
            OCRPass(
                cgImage: baseCGImage,
                weight: 0.82,
                usesLanguageCorrection: true,
                minimumTextHeight: 0.007,
                sourceWidth: baseCGImage.width,
                sourceHeight: baseCGImage.height
            )
        )

        return PreparedPage(
            baseCGImage: baseCGImage,
            textLayerCGImage: layeredPage.textLayerCGImage,
            ocrPasses: ocrPasses,
            markLayers: layeredPage.markLayers
        )
    }

    nonisolated private func recognizeConsensusWords(on page: PreparedPage) throws -> [RecognizedToken] {
        var tokens: [OCRCandidateToken] = []
        var succeededPasses = 0

        for (passIndex, pass) in page.ocrPasses.enumerated() {
            do {
                tokens.append(contentsOf: try recognizeWords(in: pass, passID: passIndex))
                succeededPasses += 1
            } catch {
                continue
            }
        }

        guard succeededPasses > 0 else {
            throw VisionScannerError.recognitionFailed
        }

        return buildConsensusTokens(from: tokens)
    }

    nonisolated private func recognizeWords(in pass: OCRPass, passID: Int) throws -> [OCRCandidateToken] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US", "en-GB"]
        request.usesLanguageCorrection = pass.usesLanguageCorrection
        request.minimumTextHeight = pass.minimumTextHeight

        let handler = VNImageRequestHandler(cgImage: pass.cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw VisionScannerError.recognitionFailed
        }

        var tokens: [OCRCandidateToken] = []

        for observation in request.results ?? [] {
            for (candidateIndex, candidate) in observation.topCandidates(3).enumerated() {
                let text = candidate.string
                let candidateConfidence = Double(candidate.confidence)
                let candidateWeightMultiplier = max(0.42, 1.0 - Double(candidateIndex) * 0.22)

                for match in EnglishWordSanitizer.matches(in: text) {
                    guard let range = Range(match.range, in: text) else { continue }
                    let originalWord = String(text[range])
                    guard let normalizedWord = EnglishWordSanitizer.normalize(originalWord, minimumLength: 2) else {
                        continue
                    }

                    let localBoundingBox =
                        (try? candidate.boundingBox(for: range))?.boundingBox
                        ?? approximateBoundingBox(
                            for: match.range,
                            in: text,
                            observationBoundingBox: observation.boundingBox
                        )
                        ?? observation.boundingBox
                    let boundingBox = mapBoundingBox(localBoundingBox, in: pass)

                    tokens.append(
                        OCRCandidateToken(
                            originalWord: originalWord,
                            normalizedWord: normalizedWord,
                            boundingBox: boundingBox,
                            confidence: candidateConfidence,
                            weight: pass.weight * candidateWeightMultiplier,
                            passID: passID
                        )
                    )
                }
            }
        }

        return tokens
    }

    nonisolated private func buildConsensusTokens(from tokens: [OCRCandidateToken]) -> [RecognizedToken] {
        guard !tokens.isEmpty else { return [] }

        let sortedTokens = tokens.sorted { lhs, rhs in
            if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > 0.025 {
                return lhs.boundingBox.midY > rhs.boundingBox.midY
            }

            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }

        var clusters: [TokenCluster] = []

        for token in sortedTokens {
            if let clusterIndex = clusters.firstIndex(where: { $0.canInclude(token) }) {
                clusters[clusterIndex].append(token)
            } else {
                clusters.append(TokenCluster(seed: token))
            }
        }

        var plausibilityCache: [String: Double] = [:]

        func plausibilityBoost(for word: String) -> Double {
            if let cached = plausibilityCache[word] {
                return cached
            }

            let vowels = CharacterSet(charactersIn: "aeiouy")
            let scalars = Array(word.unicodeScalars)
            let vowelCount = scalars.reduce(into: 0) { count, scalar in
                if vowels.contains(scalar) {
                    count += 1
                }
            }
            let uniqueCharacters = Set(word).count
            let longestRepeatedRun = word.reduce(into: (last: Optional<Character>.none, run: 0, maxRun: 0)) { state, character in
                if state.last == character {
                    state.run += 1
                } else {
                    state.last = character
                    state.run = 1
                }
                state.maxRun = max(state.maxRun, state.run)
            }.maxRun

            let boost =
                (vowelCount > 0 ? 0.08 : 0)
                + (uniqueCharacters >= min(4, word.count - 1) ? 0.06 : 0)
                + (longestRepeatedRun <= 2 ? 0.06 : 0)

            plausibilityCache[word] = boost
            return boost
        }

        return clusters.compactMap { cluster in
            cluster.bestToken(dictionaryBoost: plausibilityBoost(for:))
        }
    }

    nonisolated private func selectMarkedTokens(
        from tokens: [RecognizedToken],
        using analyzer: MarkAnalyzer,
        allowsLocalFallback: Bool = true
    ) -> [RecognizedToken] {
        guard !tokens.isEmpty else { return [] }

        let regionMatchedIndices = analyzer.selectRegionMatchedTokenIndices(from: tokens)
        if !regionMatchedIndices.isEmpty {
            return tokens.enumerated().compactMap { index, token in
                regionMatchedIndices.contains(index) ? token : nil
            }
        }

        guard allowsLocalFallback else { return [] }

        var keptIndices: Set<Int> = []
        let localCandidates = tokens.enumerated().compactMap { index, token -> ScoredRecognizedToken? in
            let evaluation = analyzer.evaluateLocalMark(for: token.boundingBox)
            guard evaluation.isStrongFallbackMatch else {
                return nil
            }

            return ScoredRecognizedToken(index: index, token: token, evaluation: evaluation)
        }

        let groups = groupNearbyCandidates(localCandidates)

        for group in groups {
            let sortedByScore = group.sorted { lhs, rhs in
                if lhs.evaluation.total == rhs.evaluation.total {
                    return lhs.index < rhs.index
                }

                return lhs.evaluation.total > rhs.evaluation.total
            }

            guard let strongest = sortedByScore.first else { continue }
            let secondBestScore = sortedByScore.dropFirst().first?.evaluation.total ?? 0
            let hasClearWinner = strongest.evaluation.total > secondBestScore * 1.18
                || strongest.evaluation.total - secondBestScore > 0.08

            if hasClearWinner {
                keptIndices.insert(strongest.index)
                for candidate in sortedByScore.dropFirst()
                where candidate.evaluation.total >= strongest.evaluation.total * 0.82
                    && candidate.evaluation.isLikelyMarked {
                    keptIndices.insert(candidate.index)
                }
            }
        }

        return tokens.enumerated().compactMap { index, token in
            keptIndices.contains(index) ? token : nil
        }
    }

    nonisolated private func groupNearbyCandidates(_ candidates: [ScoredRecognizedToken]) -> [[ScoredRecognizedToken]] {
        let sorted = candidates.sorted { lhs, rhs in
            if abs(lhs.token.midY - rhs.token.midY) > 0.03 {
                return lhs.token.midY > rhs.token.midY
            }

            return lhs.token.boundingBox.minX < rhs.token.boundingBox.minX
        }

        var groups: [[ScoredRecognizedToken]] = []

        for candidate in sorted {
            if let lastGroupIndex = groups.indices.last,
               let tail = groups[lastGroupIndex].last,
               candidate.token.isNear(tail.token) {
                groups[lastGroupIndex].append(candidate)
            } else {
                groups.append([candidate])
            }
        }

        return groups
    }

    nonisolated private func uniqueWordsPreservingOrder(_ words: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for word in words where !seen.contains(word) {
            seen.insert(word)
            result.append(word)
        }

        return result
    }

    nonisolated private func recognizeMarkedRegionWords(
        on page: PreparedPage,
        using analyzer: MarkAnalyzer
    ) throws -> [RecognizedToken] {
        let rescuePasses = buildMarkedRegionPasses(on: page)
        guard !rescuePasses.isEmpty else { return [] }

        var resolvedTokens: [RecognizedToken] = []

        for (passIndex, pass) in rescuePasses.enumerated() {
            do {
                let candidates = try recognizeWords(in: pass.pass, passID: 100 + passIndex)
                let consensus = buildConsensusTokens(from: candidates)
                let matches = analyzer.matchingTokens(
                    from: consensus,
                    for: pass.region,
                    kind: pass.kind,
                    minimumScore: pass.minimumScore
                )
                resolvedTokens = combineMarkedTokens(primary: resolvedTokens, fallback: matches)
            } catch {
                continue
            }
        }

        return resolvedTokens
    }

    nonisolated private func recognizeSelectedRegionWords(
        on page: PreparedPage,
        using analyzer: UserSelectionAnalyzer
    ) throws -> [RecognizedToken] {
        let regionPasses = buildSelectedRegionPasses(on: page, using: analyzer)
        guard !regionPasses.isEmpty else { return [] }

        var resolvedTokens: [RecognizedToken] = []

        for (passIndex, pass) in regionPasses.enumerated() {
            do {
                let candidates = try recognizeWords(in: pass.pass, passID: 300 + passIndex)
                let consensus = buildConsensusTokens(from: candidates)
                let matches = analyzer.strictlySelectedTokens(from: consensus, for: pass.region)
                resolvedTokens = combineMarkedTokens(primary: resolvedTokens, fallback: matches)
            } catch {
                continue
            }
        }

        return resolvedTokens
    }

    nonisolated private func buildMarkedRegionPasses(on page: PreparedPage) -> [MarkedRegionPass] {
        let highlightPasses = page.markLayers.highlightRegions.prefix(18).compactMap { region in
            makeMarkedRegionPass(
                for: region,
                kind: .highlight,
                sourceImage: page.textLayerCGImage,
                sourceWidth: page.markLayers.width,
                sourceHeight: page.markLayers.height,
                weight: 1.16,
                usesLanguageCorrection: true,
                minimumScore: 0.18
            )
        }
        let colorStrokePasses = page.markLayers.colorStrokeRegions.prefix(18).compactMap { region in
            makeMarkedRegionPass(
                for: region,
                kind: strokeRegionKind(for: region) ?? .underline,
                sourceImage: page.textLayerCGImage,
                sourceWidth: page.markLayers.width,
                sourceHeight: page.markLayers.height,
                weight: 1.14,
                usesLanguageCorrection: true,
                minimumScore: 0.18
            )
        }
        let darkStrokePasses = page.markLayers.darkStrokeRegions.prefix(10).compactMap { region in
            makeMarkedRegionPass(
                for: region,
                kind: strokeRegionKind(for: region) ?? .underline,
                sourceImage: page.textLayerCGImage,
                sourceWidth: page.markLayers.width,
                sourceHeight: page.markLayers.height,
                weight: 1.06,
                usesLanguageCorrection: true,
                minimumScore: 0.24
            )
        }

        return highlightPasses + colorStrokePasses + darkStrokePasses
    }

    nonisolated private func buildSelectedRegionPasses(
        on page: PreparedPage,
        using analyzer: UserSelectionAnalyzer
    ) -> [SelectedRegionPass] {
        analyzer.selectionRegions.prefix(36).compactMap { region in
            makeSelectedRegionPass(
                for: region,
                using: analyzer,
                sourceImage: page.textLayerCGImage,
                sourceWidth: page.markLayers.width,
                sourceHeight: page.markLayers.height
            )
        }
    }

    nonisolated private func makeMarkedRegionPass(
        for region: MarkRegion,
        kind: StrokeRegionKind,
        sourceImage: CGImage,
        sourceWidth: Int,
        sourceHeight: Int,
        weight: Double,
        usesLanguageCorrection: Bool,
        minimumScore: Double
    ) -> MarkedRegionPass? {
        let cropRect: CGRect

        switch kind {
        case .highlight:
            cropRect = CGRect(
                x: region.rect.minX - region.rect.width * 0.24,
                y: region.rect.minY - region.rect.height * 0.55,
                width: region.rect.width * 1.48,
                height: region.rect.height * 2.0
            )
        case .underline:
            cropRect = CGRect(
                x: region.rect.minX - region.rect.width * 0.2,
                y: region.rect.minY - region.rect.height * 4.2,
                width: region.rect.width * 1.4,
                height: region.rect.height * 6.2
            )
        case .circle:
            cropRect = CGRect(
                x: region.rect.minX - region.rect.width * 0.22,
                y: region.rect.minY - region.rect.height * 0.32,
                width: region.rect.width * 1.44,
                height: region.rect.height * 1.64
            )
        }

        let boundedRect = cropRect
            .intersection(CGRect(x: 0, y: 0, width: sourceWidth, height: sourceHeight))
            .integral

        guard boundedRect.width >= 18, boundedRect.height >= 12,
              let crop = sourceImage.cropping(to: boundedRect) else {
            return nil
        }

        return MarkedRegionPass(
            pass: OCRPass(
                cgImage: crop,
                weight: weight,
                usesLanguageCorrection: usesLanguageCorrection,
                minimumTextHeight: 0.0045,
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
                cropRectInSource: boundedRect
            ),
            region: region,
            kind: kind,
            minimumScore: minimumScore
        )
    }

    nonisolated private func makeSelectedRegionPass(
        for region: UserSelectionRegion,
        using analyzer: UserSelectionAnalyzer,
        sourceImage: CGImage,
        sourceWidth: Int,
        sourceHeight: Int
    ) -> SelectedRegionPass? {
        guard let maskedCrop = analyzer.makeMaskedCrop(
            from: sourceImage,
            for: region,
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight
        ) else {
            return nil
        }

        return SelectedRegionPass(
            pass: OCRPass(
                cgImage: maskedCrop.cgImage,
                weight: 1.22,
                usesLanguageCorrection: true,
                minimumTextHeight: 0.004,
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight,
                cropRectInSource: maskedCrop.cropRect
            ),
            region: region
        )
    }

    nonisolated private func combineMarkedTokens(
        primary: [RecognizedToken],
        fallback: [RecognizedToken]
    ) -> [RecognizedToken] {
        guard !primary.isEmpty else { return fallback }
        guard !fallback.isEmpty else { return primary }

        var merged = primary

        for token in fallback {
            if merged.contains(where: { existing in
                existing.normalizedWord == token.normalizedWord
                    && (existing.boundingBox.intersectionOverUnion(with: token.boundingBox) > 0.14
                        || (abs(existing.boundingBox.midX - token.boundingBox.midX) < max(existing.boundingBox.width, token.boundingBox.width) * 0.42
                            && abs(existing.boundingBox.midY - token.boundingBox.midY) < max(existing.boundingBox.height, token.boundingBox.height) * 0.6))
            }) {
                continue
            }

            merged.append(token)
        }

        return merged.sorted { lhs, rhs in
            if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > 0.025 {
                return lhs.boundingBox.midY > rhs.boundingBox.midY
            }

            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
    }

    nonisolated private func approximateBoundingBox(
        for matchRange: NSRange,
        in text: String,
        observationBoundingBox: CGRect
    ) -> CGRect? {
        let nsText = text as NSString
        let totalLength = max(nsText.length, 1)
        guard matchRange.location != NSNotFound, matchRange.length > 0 else { return nil }

        let leadingRatio = CGFloat(matchRange.location) / CGFloat(totalLength)
        let trailingRatio = CGFloat(matchRange.location + matchRange.length) / CGFloat(totalLength)
        let minX = observationBoundingBox.minX + observationBoundingBox.width * leadingRatio
        let maxX = observationBoundingBox.minX + observationBoundingBox.width * trailingRatio
        let width = max(observationBoundingBox.width * 0.06, maxX - minX)

        return CGRect(
            x: minX,
            y: observationBoundingBox.minY,
            width: min(width, observationBoundingBox.maxX - minX),
            height: observationBoundingBox.height
        )
    }

    nonisolated private func mapBoundingBox(_ localBoundingBox: CGRect, in pass: OCRPass) -> CGRect {
        guard let cropRect = pass.cropRectInSource else {
            return localBoundingBox
        }

        let localPixelRect = topLeftPixelRect(
            fromVisionRect: localBoundingBox,
            imageWidth: pass.cgImage.width,
            imageHeight: pass.cgImage.height
        )
        let fullPixelRect = CGRect(
            x: cropRect.minX + localPixelRect.minX,
            y: cropRect.minY + localPixelRect.minY,
            width: localPixelRect.width,
            height: localPixelRect.height
        )

        return visionRect(
            fromTopLeftPixelRect: fullPixelRect,
            sourceWidth: pass.sourceWidth,
            sourceHeight: pass.sourceHeight
        )
    }
}

private struct PreparedPage {
    let baseCGImage: CGImage
    let textLayerCGImage: CGImage
    let ocrPasses: [OCRPass]
    let markLayers: MarkLayers
}

private struct LayerSeparatedPage {
    let textLayerImage: UIImage
    let textLayerCGImage: CGImage
    let markLayers: MarkLayers
}

private struct MarkLayers {
    let width: Int
    let height: Int
    let highlightMask: [UInt8]
    let colorStrokeMask: [UInt8]
    let darkStrokeMask: [UInt8]
    let strokeMask: [UInt8]
    let highlightRegions: [MarkRegion]
    let colorStrokeRegions: [MarkRegion]
    let darkStrokeRegions: [MarkRegion]
}

private enum ImageLayerBuilder {
    nonisolated static func build(from image: UIImage, textSourceImage: UIImage) -> LayerSeparatedPage? {
        guard let cgImage = image.cgImage,
              let textSourceCGImage = textSourceImage.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        var sourcePixels = Array(repeating: UInt8(0), count: width * height * 4)
        guard let sourceContext = CGContext(
            data: &sourcePixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        sourceContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var textSourcePixels = Array(repeating: UInt8(0), count: width * height * 4)
        guard let textSourceContext = CGContext(
            data: &textSourcePixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        textSourceContext.draw(textSourceCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var textPixels = Array(repeating: UInt8(255), count: width * height * 4)
        var highlightMask = Array(repeating: UInt8(0), count: width * height)
        var colorStrokeMask = Array(repeating: UInt8(0), count: width * height)
        var rawDarkStrokeMask = Array(repeating: UInt8(0), count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let pixelOffset = y * bytesPerRow + x * 4
                let maskOffset = y * width + x
                let pixel = SamplePixel(
                    red: Double(sourcePixels[pixelOffset]) / 255,
                    green: Double(sourcePixels[pixelOffset + 1]) / 255,
                    blue: Double(sourcePixels[pixelOffset + 2]) / 255
                )
                let textPixel = SamplePixel(
                    red: Double(textSourcePixels[pixelOffset]) / 255,
                    green: Double(textSourcePixels[pixelOffset + 1]) / 255,
                    blue: Double(textSourcePixels[pixelOffset + 2]) / 255
                )

                let isHighlight = pixel.isHighlightLike
                let isColorStroke = pixel.isColorStrokeLike
                let isDarkStroke = pixel.isInkLike

                if isHighlight {
                    highlightMask[maskOffset] = 255
                }

                if isColorStroke {
                    colorStrokeMask[maskOffset] = 255
                }

                if isDarkStroke {
                    rawDarkStrokeMask[maskOffset] = 255
                }

                let outputValue: UInt8

                if isHighlight || isColorStroke {
                    outputValue = 250
                } else if isDarkStroke && !textPixel.looksLikePrintedInk {
                    outputValue = 248
                } else if textPixel.looksLikePrintedInk {
                    let adjusted = max(0.0, min(1.0, pow(textPixel.luminance, 1.18) * 0.42))
                    outputValue = UInt8(adjusted * 255)
                } else {
                    let adjusted = max(0.92, min(1.0, 0.94 + textPixel.luminance * 0.08))
                    outputValue = UInt8(adjusted * 255)
                }

                textPixels[pixelOffset] = outputValue
                textPixels[pixelOffset + 1] = outputValue
                textPixels[pixelOffset + 2] = outputValue
                textPixels[pixelOffset + 3] = 255
            }
        }

        guard let textLayerCGImage = makeCGImage(
            from: textPixels,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            colorSpace: colorSpace
        ) else {
            return nil
        }

        let highlightRegions = extractRegions(
            from: highlightMask,
            width: width,
            height: height,
            cellSize: max(3, min(6, max(width, height) / 420)),
            activationThreshold: 0.12,
            minimumCellHits: 2,
            minimumActiveCells: 3,
            minimumWidth: 8,
            minimumHeight: 4
        )
        let colorStrokeRegions = extractRegions(
            from: colorStrokeMask,
            width: width,
            height: height,
            cellSize: max(3, min(6, max(width, height) / 420)),
            activationThreshold: 0.10,
            minimumCellHits: 2,
            minimumActiveCells: 3,
            minimumWidth: 10,
            minimumHeight: 4
        )
        let darkStrokeCandidateRegions = extractRegions(
            from: rawDarkStrokeMask,
            width: width,
            height: height,
            cellSize: max(4, min(7, max(width, height) / 360)),
            activationThreshold: 0.22,
            minimumCellHits: 3,
            minimumActiveCells: 4,
            minimumWidth: 10,
            minimumHeight: 4
        )

        let darkStrokeRegions = darkStrokeCandidateRegions.filter {
            darkStrokeRegionLooksClean($0, rawMask: rawDarkStrokeMask, width: width, height: height)
        }
        let darkStrokeMask = retainMaskPixels(
            from: rawDarkStrokeMask,
            within: darkStrokeRegions,
            width: width,
            height: height
        )
        let strokeMask = unionMask(colorStrokeMask, darkStrokeMask)

        let markLayers = MarkLayers(
            width: width,
            height: height,
            highlightMask: highlightMask,
            colorStrokeMask: colorStrokeMask,
            darkStrokeMask: darkStrokeMask,
            strokeMask: strokeMask,
            highlightRegions: highlightRegions,
            colorStrokeRegions: colorStrokeRegions,
            darkStrokeRegions: darkStrokeRegions
        )

        return LayerSeparatedPage(
            textLayerImage: UIImage(cgImage: textLayerCGImage, scale: image.scale, orientation: .up),
            textLayerCGImage: textLayerCGImage,
            markLayers: markLayers
        )
    }

    nonisolated private static func makeCGImage(
        from pixels: [UInt8],
        width: Int,
        height: Int,
        bytesPerRow: Int,
        colorSpace: CGColorSpace
    ) -> CGImage? {
        var pixels = pixels
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        return context.makeImage()
    }

    nonisolated private static func extractRegions(
        from mask: [UInt8],
        width: Int,
        height: Int,
        cellSize: Int,
        activationThreshold: Double,
        minimumCellHits: Int,
        minimumActiveCells: Int,
        minimumWidth: Int,
        minimumHeight: Int
    ) -> [MarkRegion] {
        let maskWidth = max(1, width / cellSize)
        let maskHeight = max(1, height / cellSize)
        var active = Array(repeating: false, count: maskWidth * maskHeight)
        var densities = Array(repeating: 0.0, count: maskWidth * maskHeight)

        for cellY in 0..<maskHeight {
            for cellX in 0..<maskWidth {
                let startX = cellX * cellSize
                let startY = cellY * cellSize
                let endX = min(width, startX + cellSize)
                let endY = min(height, startY + cellSize)

                var marked = 0
                var total = 0

                for y in startY..<endY {
                    for x in startX..<endX {
                        total += 1
                        if mask[y * width + x] > 0 {
                            marked += 1
                        }
                    }
                }

                let density = total > 0 ? Double(marked) / Double(total) : 0
                let index = cellY * maskWidth + cellX
                densities[index] = density
                active[index] = marked >= minimumCellHits && density >= activationThreshold
            }
        }

        var visited = Array(repeating: false, count: active.count)
        var regions: [MarkRegion] = []

        for startIndex in active.indices where active[startIndex] && !visited[startIndex] {
            var queue = [startIndex]
            visited[startIndex] = true
            var queueIndex = 0
            var minCellX = Int.max
            var minCellY = Int.max
            var maxCellX = 0
            var maxCellY = 0
            var activeCount = 0
            var densityTotal = 0.0

            while queueIndex < queue.count {
                let index = queue[queueIndex]
                queueIndex += 1

                let cellX = index % maskWidth
                let cellY = index / maskWidth
                minCellX = min(minCellX, cellX)
                minCellY = min(minCellY, cellY)
                maxCellX = max(maxCellX, cellX)
                maxCellY = max(maxCellY, cellY)
                activeCount += 1
                densityTotal += densities[index]

                for deltaY in -1...1 {
                    for deltaX in -1...1 where !(deltaX == 0 && deltaY == 0) {
                        let nextX = cellX + deltaX
                        let nextY = cellY + deltaY

                        guard nextX >= 0, nextY >= 0, nextX < maskWidth, nextY < maskHeight else {
                            continue
                        }

                        let nextIndex = nextY * maskWidth + nextX
                        guard active[nextIndex], !visited[nextIndex] else { continue }
                        visited[nextIndex] = true
                        queue.append(nextIndex)
                    }
                }
            }

            guard activeCount >= minimumActiveCells else { continue }

            let rect = CGRect(
                x: minCellX * cellSize,
                y: minCellY * cellSize,
                width: max(cellSize, (maxCellX - minCellX + 1) * cellSize),
                height: max(cellSize, (maxCellY - minCellY + 1) * cellSize)
            ).intersection(CGRect(x: 0, y: 0, width: width, height: height))

            guard rect.width >= CGFloat(minimumWidth), rect.height >= CGFloat(minimumHeight) else {
                continue
            }

            let fillRatio = Double(activeCount * cellSize * cellSize) / max(rect.area, 1)
            let strength = densityTotal / Double(activeCount)
            regions.append(MarkRegion(rect: rect, fillRatio: fillRatio, strength: strength))
        }

        return regions.sorted { lhs, rhs in
            if lhs.rect.minY == rhs.rect.minY {
                return lhs.rect.minX < rhs.rect.minX
            }

            return lhs.rect.minY < rhs.rect.minY
        }
    }
}

private struct OCRPass {
    let cgImage: CGImage
    let weight: Double
    let usesLanguageCorrection: Bool
    let minimumTextHeight: Float
    let sourceWidth: Int
    let sourceHeight: Int
    let cropRectInSource: CGRect?

    nonisolated init(
        cgImage: CGImage,
        weight: Double,
        usesLanguageCorrection: Bool,
        minimumTextHeight: Float,
        sourceWidth: Int,
        sourceHeight: Int,
        cropRectInSource: CGRect? = nil
    ) {
        self.cgImage = cgImage
        self.weight = weight
        self.usesLanguageCorrection = usesLanguageCorrection
        self.minimumTextHeight = minimumTextHeight
        self.sourceWidth = sourceWidth
        self.sourceHeight = sourceHeight
        self.cropRectInSource = cropRectInSource
    }
}

private struct OCRCandidateToken {
    let originalWord: String
    let normalizedWord: String
    let boundingBox: CGRect
    let confidence: Double
    let weight: Double
    let passID: Int
}

private struct MarkedRegionPass {
    let pass: OCRPass
    let region: MarkRegion
    let kind: StrokeRegionKind
    let minimumScore: Double
}

private struct SelectedRegionPass {
    let pass: OCRPass
    let region: UserSelectionRegion
}

private struct RecognizedToken {
    let originalWord: String
    let normalizedWord: String
    let boundingBox: CGRect
    let qualityScore: Double

    nonisolated var midY: CGFloat {
        boundingBox.midY
    }

    nonisolated func isNear(_ other: RecognizedToken) -> Bool {
        let verticalDistance = abs(boundingBox.midY - other.boundingBox.midY)
        let heightTolerance = max(boundingBox.height, other.boundingBox.height) * 0.8
        guard verticalDistance <= heightTolerance else { return false }

        let horizontalGap = max(0, boundingBox.minX - other.boundingBox.maxX, other.boundingBox.minX - boundingBox.maxX)
        let gapTolerance = max(boundingBox.height, other.boundingBox.height) * 0.95
        return horizontalGap <= gapTolerance
    }
}

private struct TokenCluster {
    private(set) var items: [OCRCandidateToken]
    private(set) var representativeBox: CGRect

    nonisolated init(seed: OCRCandidateToken) {
        self.items = [seed]
        self.representativeBox = seed.boundingBox
    }

    nonisolated mutating func append(_ token: OCRCandidateToken) {
        items.append(token)
        representativeBox = averageRect(of: items.map(\.boundingBox))
    }

    nonisolated func canInclude(_ token: OCRCandidateToken) -> Bool {
        let verticalDistance = abs(token.boundingBox.midY - representativeBox.midY)
        let heightTolerance = max(token.boundingBox.height, representativeBox.height) * 0.8
        guard verticalDistance <= heightTolerance else { return false }

        let iou = representativeBox.intersectionOverUnion(with: token.boundingBox)
        if iou > 0.12 {
            return true
        }

        let horizontalDistance = abs(token.boundingBox.midX - representativeBox.midX)
        let widthTolerance = max(token.boundingBox.width, representativeBox.width) * 0.52
        let similarWidth = abs(token.boundingBox.width - representativeBox.width) <= max(token.boundingBox.width, representativeBox.width) * 0.90
        return horizontalDistance <= widthTolerance && similarWidth
    }

    nonisolated func bestToken(dictionaryBoost: (String) -> Double) -> RecognizedToken? {
        var choices: [String: ConsensusChoice] = [:]

        for item in items {
            var choice = choices[item.normalizedWord] ?? ConsensusChoice(word: item.normalizedWord)
            choice.score += item.weight * (0.55 + item.confidence)
            choice.bestConfidence = max(choice.bestConfidence, item.confidence)
            choice.passIDs.insert(item.passID)
            choice.rects.append(item.boundingBox)

            if choice.bestOriginalWord == nil || item.confidence >= choice.bestConfidence {
                choice.bestOriginalWord = item.originalWord
            }

            choices[item.normalizedWord] = choice
        }

        for key in choices.keys {
            var choice = choices[key] ?? ConsensusChoice(word: key)
            choice.score += Double(max(0, choice.passIDs.count - 1)) * 0.28
            choice.score += dictionaryBoost(key)
            choices[key] = choice
        }

        let sortedChoices = choices.values.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.word < rhs.word
            }

            return lhs.score > rhs.score
        }

        guard let bestChoice = sortedChoices.first else { return nil }
        let secondBestScore = sortedChoices.dropFirst().first?.score ?? 0
        let isReliable =
            (bestChoice.score >= 0.90
                && (bestChoice.score - secondBestScore > 0.06
                    || bestChoice.passIDs.count > 1
                    || bestChoice.bestConfidence >= 0.56))
            || (bestChoice.bestConfidence >= 0.76 && bestChoice.score >= 0.74)
            || (bestChoice.passIDs.count >= 2 && bestChoice.score >= 0.82)
            || (items.count == 1 && bestChoice.bestConfidence >= 0.82 && bestChoice.score >= 0.68)

        guard isReliable else { return nil }

        return RecognizedToken(
            originalWord: bestChoice.bestOriginalWord ?? bestChoice.word,
            normalizedWord: bestChoice.word,
            boundingBox: averageRect(of: bestChoice.rects),
            qualityScore: bestChoice.score
        )
    }
}

private struct ConsensusChoice {
    let word: String
    var score: Double = 0
    var bestConfidence: Double = 0
    var passIDs: Set<Int> = []
    var rects: [CGRect] = []
    var bestOriginalWord: String?
}

private struct ScoredRecognizedToken {
    let index: Int
    let token: RecognizedToken
    let evaluation: MarkEvaluation
}

private struct MarkEvaluation {
    let total: Double
    let highlightCore: Double
    let underlineCoverage: Double
    let ringScore: Double

    nonisolated var isLikelyMarked: Bool {
        total > 0.16
            || highlightCore > 0.08
            || underlineCoverage > 0.44
            || ringScore > 0.11
    }

    nonisolated var isStrongFallbackMatch: Bool {
        total > 0.24
            || highlightCore > 0.12
            || underlineCoverage > 0.68
            || ringScore > 0.15
    }
}

private struct MarkRegion {
    let rect: CGRect
    let fillRatio: Double
    let strength: Double
}

private struct UserSelectionRegion {
    let rect: CGRect
    let fillRatio: Double
}

private struct UserSelectionAnalyzer {
    let width: Int
    let height: Int
    let selectionMask: [UInt8]
    let selectionRegions: [UserSelectionRegion]

    fileprivate struct MaskedCrop {
        let cgImage: CGImage
        let cropRect: CGRect
    }

    nonisolated init(maskImage: UIImage, targetWidth: Int, targetHeight: Int) {
        self.init(
            maskImage: maskImage,
            targetWidth: targetWidth,
            targetHeight: targetHeight,
            preferredNormalizedRegions: []
        )
    }

    nonisolated init(
        maskImage: UIImage,
        targetWidth: Int,
        targetHeight: Int,
        preferredNormalizedRegions: [CGRect]
    ) {
        self.width = targetWidth
        self.height = targetHeight
        self.selectionMask = Self.makeMask(from: maskImage, width: targetWidth, height: targetHeight)
        let preferredRegions = Self.makeRegions(
            from: preferredNormalizedRegions,
            width: targetWidth,
            height: targetHeight
        )
        let extractedRegions = extractSelectionRegions(
            from: selectionMask,
            width: targetWidth,
            height: targetHeight
        )
        if !extractedRegions.isEmpty {
            self.selectionRegions = extractedRegions
        } else if !preferredRegions.isEmpty {
            self.selectionRegions = preferredRegions
        } else {
            self.selectionRegions = []
        }
    }

    nonisolated var hasSelection: Bool {
        selectionMask.contains(where: { $0 > 0 })
    }

    nonisolated func strictlySelectedTokens(
        from tokens: [RecognizedToken],
        for region: UserSelectionRegion
    ) -> [RecognizedToken] {
        tokens.enumerated().compactMap { index, token -> (Int, Double)? in
            let tokenRect = imageRect(for: token.boundingBox)
            guard tokenRect.width > 4, tokenRect.height > 4 else { return nil }

            let center = CGPoint(x: tokenRect.midX, y: tokenRect.midY)
            let centerSelected = containsSelection(at: center)

            let innerRect = tokenRect.insetBy(
                dx: max(1, tokenRect.width * 0.18),
                dy: max(1, tokenRect.height * 0.24)
            )
            let overlapRect = innerRect.isNull || innerRect.isEmpty ? tokenRect : innerRect
            let maskCoverage = maskRatio(in: overlapRect, mask: selectionMask, width: width, height: height)
            let regionCoverage = region.rect.intersection(tokenRect).area / max(tokenRect.area, 1)
            let strongCenterMatch = centerSelected && region.rect.contains(center)

            guard strongCenterMatch || maskCoverage >= 0.48 else { return nil }
            guard strongCenterMatch || regionCoverage >= 0.24 else { return nil }

            let score = (strongCenterMatch ? 1.55 : (centerSelected ? 0.7 : 0.0))
                + Double(maskCoverage) * 1.6
                + Double(regionCoverage) * 0.28
            return (index, score)
        }
        .sorted { lhs, rhs in
            if lhs.1 == rhs.1 {
                return tokens[lhs.0].qualityScore > tokens[rhs.0].qualityScore
            }

            return lhs.1 > rhs.1
        }
        .map { tokens[$0.0] }
    }

    nonisolated func selectedTokens(from tokens: [RecognizedToken]) -> [RecognizedToken] {
        tokens.filter { token in
            let tokenRect = imageRect(for: token.boundingBox)
            guard tokenRect.width > 4, tokenRect.height > 4 else { return false }

            let center = CGPoint(x: tokenRect.midX, y: tokenRect.midY)
            if containsSelection(at: center) {
                return true
            }

            let innerRect = tokenRect.insetBy(
                dx: max(1, tokenRect.width * 0.12),
                dy: max(1, tokenRect.height * 0.18)
            )
            let sampleRect = innerRect.isNull || innerRect.isEmpty ? tokenRect : innerRect
            let maskCoverage = maskRatio(in: sampleRect, mask: selectionMask, width: width, height: height)
            return maskCoverage >= 0.18
        }
    }

    nonisolated private func imageRect(for normalizedRect: CGRect) -> CGRect {
        let rect = CGRect(
            x: normalizedRect.minX * CGFloat(width),
            y: (1 - normalizedRect.maxY) * CGFloat(height),
            width: normalizedRect.width * CGFloat(width),
            height: normalizedRect.height * CGFloat(height)
        )

        return rect.intersection(CGRect(x: 0, y: 0, width: width, height: height))
    }

    nonisolated private static func makeMask(from image: UIImage, width: Int, height: Int) -> [UInt8] {
        guard let cgImage = image.cgImage else {
            return Array(repeating: UInt8(0), count: width * height)
        }

        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = Array(repeating: UInt8(0), count: width * height * 4)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return Array(repeating: UInt8(0), count: width * height)
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var mask = Array(repeating: UInt8(0), count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let pixelOffset = y * bytesPerRow + x * 4
                let alpha = Double(pixels[pixelOffset + 3]) / 255
                let maskIndex = y * width + x

                if alpha > 0.12 {
                    mask[maskIndex] = 255
                }
            }
        }

        return dilatedMask(mask, width: width, height: height)
    }

    nonisolated private static func dilatedMask(
        _ mask: [UInt8],
        width: Int,
        height: Int
    ) -> [UInt8] {
        guard width > 0, height > 0 else { return mask }

        let radius = max(1, min(2, max(width, height) / 1400))
        guard radius > 0 else { return mask }

        var dilated = mask

        for y in 0..<height {
            for x in 0..<width {
                guard mask[y * width + x] > 0 else { continue }

                let minX = max(0, x - radius)
                let maxX = min(width - 1, x + radius)
                let minY = max(0, y - radius)
                let maxY = min(height - 1, y + radius)

                for fillY in minY...maxY {
                    for fillX in minX...maxX {
                        dilated[fillY * width + fillX] = 255
                    }
                }
            }
        }

        return dilated
    }

    nonisolated private static func makeRegions(
        from normalizedRects: [CGRect],
        width: Int,
        height: Int
    ) -> [UserSelectionRegion] {
        guard !normalizedRects.isEmpty else { return [] }

        let imageBounds = CGRect(x: 0, y: 0, width: width, height: height)

        let rects = normalizedRects.compactMap { normalizedRect -> CGRect? in
            guard normalizedRect.width > 0, normalizedRect.height > 0 else { return nil }

            let rect = CGRect(
                x: normalizedRect.minX * CGFloat(width),
                y: normalizedRect.minY * CGFloat(height),
                width: normalizedRect.width * CGFloat(width),
                height: normalizedRect.height * CGFloat(height)
            )
            .intersection(imageBounds)
            .integral

            guard rect.width >= 4, rect.height >= 4 else { return nil }
            return rect
        }

        guard !rects.isEmpty else { return [] }

        let merged = mergeNearbySelectionRects(rects)
        return merged.map { UserSelectionRegion(rect: $0, fillRatio: 1) }
    }

    nonisolated private func containsSelection(at point: CGPoint) -> Bool {
        let x = min(max(Int(point.x.rounded(.down)), 0), max(0, width - 1))
        let y = min(max(Int(point.y.rounded(.down)), 0), max(0, height - 1))
        return selectionMask[y * width + x] > 0
    }

    nonisolated fileprivate func makeMaskedCrop(
        from sourceImage: CGImage,
        for region: UserSelectionRegion,
        sourceWidth: Int,
        sourceHeight: Int
    ) -> MaskedCrop? {
        let cropRect = CGRect(
            x: region.rect.minX - max(1, region.rect.width * 0.01),
            y: region.rect.minY - max(2, region.rect.height * 0.02),
            width: region.rect.width + max(2, region.rect.width * 0.02),
            height: region.rect.height + max(4, region.rect.height * 0.04)
        )
        .intersection(CGRect(x: 0, y: 0, width: sourceWidth, height: sourceHeight))
        .integral

        guard cropRect.width >= 12, cropRect.height >= 10,
              let crop = sourceImage.cropping(to: cropRect) else {
            return nil
        }

        let cropWidth = crop.width
        let cropHeight = crop.height
        let bytesPerRow = cropWidth * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = Array(repeating: UInt8(255), count: cropWidth * cropHeight * 4)

        guard let context = CGContext(
            data: &pixels,
            width: cropWidth,
            height: cropHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(crop, in: CGRect(x: 0, y: 0, width: cropWidth, height: cropHeight))

        for y in 0..<cropHeight {
            for x in 0..<cropWidth {
                let globalX = Int(cropRect.minX) + x
                let globalY = Int(cropRect.minY) + y
                let pixelIndex = y * bytesPerRow + x * 4

                guard globalX >= 0, globalY >= 0, globalX < width, globalY < height else {
                    pixels[pixelIndex] = 255
                    pixels[pixelIndex + 1] = 255
                    pixels[pixelIndex + 2] = 255
                    pixels[pixelIndex + 3] = 255
                    continue
                }

                if selectionMask[globalY * width + globalX] == 0 {
                    pixels[pixelIndex] = 255
                    pixels[pixelIndex + 1] = 255
                    pixels[pixelIndex + 2] = 255
                    pixels[pixelIndex + 3] = 255
                }
            }
        }

        guard let cgImage = context.makeImage() else {
            return nil
        }

        return MaskedCrop(cgImage: cgImage, cropRect: cropRect)
    }
}

private struct MarkAnalyzer {
    private let width: Int
    private let height: Int
    private let highlightMask: [UInt8]
    private let colorStrokeMask: [UInt8]
    private let darkStrokeMask: [UInt8]
    private let strokeMask: [UInt8]
    private let highlightRegions: [MarkRegion]
    private let colorStrokeRegions: [MarkRegion]
    private let darkStrokeRegions: [MarkRegion]

    nonisolated init(markLayers: MarkLayers) {
        self.width = markLayers.width
        self.height = markLayers.height
        self.highlightMask = markLayers.highlightMask
        self.colorStrokeMask = markLayers.colorStrokeMask
        self.darkStrokeMask = markLayers.darkStrokeMask
        self.strokeMask = markLayers.strokeMask
        self.highlightRegions = markLayers.highlightRegions
        self.colorStrokeRegions = markLayers.colorStrokeRegions
        self.darkStrokeRegions = markLayers.darkStrokeRegions
    }

    nonisolated func selectRegionMatchedTokenIndices(from tokens: [RecognizedToken]) -> Set<Int> {
        var keptIndices = selectHighlightedTokenIndices(from: tokens)
        keptIndices.formUnion(selectStrokeTokenIndices(from: tokens))
        return keptIndices
    }

    nonisolated func matchingTokens(
        from tokens: [RecognizedToken],
        for region: MarkRegion,
        kind: StrokeRegionKind,
        minimumScore: Double
    ) -> [RecognizedToken] {
        guard !tokens.isEmpty else { return [] }

        let matches = tokens.enumerated().compactMap { index, token -> (Int, Double)? in
            let tokenRect = imageRect(for: token.boundingBox)
            let score: Double

            switch kind {
            case .highlight:
                score = highlightRegionMatchScore(region, tokenRect: tokenRect)
            case .underline:
                score = underlineRegionMatchScore(region, tokenRect: tokenRect)
            case .circle:
                score = circleRegionMatchScore(region, tokenRect: tokenRect)
            }

            guard score >= minimumScore else { return nil }
            return (index, score)
        }.sorted { lhs, rhs in
            if lhs.1 == rhs.1 {
                return tokens[lhs.0].qualityScore > tokens[rhs.0].qualityScore
            }

            return lhs.1 > rhs.1
        }

        guard let best = matches.first else { return [] }
        return [tokens[best.0]]
    }

    nonisolated private func selectHighlightedTokenIndices(from tokens: [RecognizedToken]) -> Set<Int> {
        var keptIndices: Set<Int> = []

        for region in highlightRegions {
            let matches = tokens.enumerated().compactMap { index, token -> (Int, Double)? in
                let score = highlightRegionMatchScore(region, tokenRect: imageRect(for: token.boundingBox))
                guard score > 0.34 else { return nil }
                return (index, score)
            }.sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return tokens[lhs.0].qualityScore > tokens[rhs.0].qualityScore
                }

                return lhs.1 > rhs.1
            }

            guard let bestMatch = matches.first else { continue }
            keptIndices.insert(bestMatch.0)
        }

        return keptIndices
    }

    nonisolated private func selectStrokeTokenIndices(from tokens: [RecognizedToken]) -> Set<Int> {
        var keptIndices: Set<Int> = []
        keptIndices.formUnion(selectStrokeTokenIndices(from: tokens, regions: colorStrokeRegions, minimumScore: 0.26))
        keptIndices.formUnion(selectStrokeTokenIndices(from: tokens, regions: darkStrokeRegions, minimumScore: 0.36))
        return keptIndices
    }

    nonisolated private func selectStrokeTokenIndices(
        from tokens: [RecognizedToken],
        regions: [MarkRegion],
        minimumScore: Double
    ) -> Set<Int> {
        var keptIndices: Set<Int> = []

        for region in regions {
            guard let strokeKind = classifyStrokeRegion(region) else { continue }
            let isUnderlineLike: Bool

            switch strokeKind {
            case .underline:
                isUnderlineLike = true
            case .circle:
                isUnderlineLike = false
            case .highlight:
                isUnderlineLike = false
            }
            let matches = tokens.enumerated().compactMap { index, token -> (Int, Double)? in
                let tokenRect = imageRect(for: token.boundingBox)
                let score = isUnderlineLike
                    ? underlineRegionMatchScore(region, tokenRect: tokenRect)
                    : circleRegionMatchScore(region, tokenRect: tokenRect)
                guard score > minimumScore else { return nil }
                return (index, score)
            }.sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return tokens[lhs.0].qualityScore > tokens[rhs.0].qualityScore
                }

                return lhs.1 > rhs.1
            }

            guard let bestMatch = matches.first else { continue }
            keptIndices.insert(bestMatch.0)
        }

        return keptIndices
    }

    nonisolated private func classifyStrokeRegion(_ region: MarkRegion) -> StrokeRegionKind? {
        strokeRegionKind(for: region)
    }

    nonisolated func hasStrongRegionNear(
        _ normalizedRect: CGRect,
        among tokens: [RecognizedToken],
        keptIndices: Set<Int>
    ) -> Bool {
        let targetRect = imageRect(for: normalizedRect)

        for index in keptIndices {
            let winnerRect = imageRect(for: tokens[index].boundingBox)
            let verticalDistance = abs(targetRect.midY - winnerRect.midY)
            let maxHeight = max(targetRect.height, winnerRect.height)

            if verticalDistance <= maxHeight * 0.95 {
                let horizontalGap = max(0, targetRect.minX - winnerRect.maxX, winnerRect.minX - targetRect.maxX)
                if horizontalGap <= maxHeight * 1.15 {
                    return true
                }
            }
        }

        return false
    }

    nonisolated func evaluateLocalMark(for normalizedRect: CGRect) -> MarkEvaluation {
        let wordRect = imageRect(for: normalizedRect)
        guard wordRect.width > 6, wordRect.height > 6 else {
            return MarkEvaluation(total: 0, highlightCore: 0, underlineCoverage: 0, ringScore: 0)
        }

        let coreRect = wordRect.insetBy(
            dx: -max(1, wordRect.width * 0.03),
            dy: -max(1, wordRect.height * 0.08)
        )
        let haloRect = wordRect.insetBy(
            dx: -max(1.5, wordRect.width * 0.06),
            dy: -max(1.5, wordRect.height * 0.16)
        )
        let underlineRect = CGRect(
            x: wordRect.minX + wordRect.width * 0.12,
            y: wordRect.maxY + 1,
            width: max(4, wordRect.width * 0.76),
            height: max(3, wordRect.height * 0.16)
        )
        let ringRect = wordRect.insetBy(
            dx: -max(2, wordRect.width * 0.12),
            dy: -max(2, wordRect.height * 0.22)
        )

        let highlightCore = maskRatio(in: coreRect, mask: highlightMask)
        let highlightHalo = maskRatio(in: haloRect, mask: highlightMask)
        let underlineCoverage = max(
            horizontalMaskCoverage(in: underlineRect, mask: colorStrokeMask) * 1.08,
            horizontalMaskCoverage(in: underlineRect, mask: darkStrokeMask) * 0.92
        )
        let ringScore = max(
            ringMaskRatio(outerRect: ringRect, innerRect: wordRect.insetBy(dx: -1, dy: -1), mask: colorStrokeMask) * 1.08,
            ringMaskRatio(outerRect: ringRect, innerRect: wordRect.insetBy(dx: -1, dy: -1), mask: darkStrokeMask) * 0.84
        )

        let highlightScore = highlightCore * 1.7 + highlightHalo * 0.28
        let total = max(highlightScore, max(underlineCoverage * 1.1, ringScore * 1.18))

        return MarkEvaluation(
            total: total,
            highlightCore: highlightCore,
            underlineCoverage: underlineCoverage,
            ringScore: ringScore
        )
    }

    nonisolated private func highlightRegionMatchScore(_ region: MarkRegion, tokenRect: CGRect) -> Double {
        let expandedRect = tokenRect.insetBy(
            dx: -max(2, tokenRect.width * 0.12),
            dy: -max(2, tokenRect.height * 0.18)
        )

        let overlap = region.rect.intersection(tokenRect).area / max(tokenRect.area, 1)
        let haloOverlap = region.rect.intersection(expandedRect).area / max(tokenRect.area, 1)

        let diagonal = max(
            hypot(region.rect.width, region.rect.height),
            hypot(tokenRect.width, tokenRect.height),
            1
        )
        let centerDistance = hypot(region.rect.midX - tokenRect.midX, region.rect.midY - tokenRect.midY) / diagonal
        let centerScore = max(0, 1 - centerDistance * 1.7)

        return overlap * 1.65
            + haloOverlap * 0.52
            + region.strength * 0.48
            + centerScore * 0.28
    }

    nonisolated private func underlineRegionMatchScore(_ region: MarkRegion, tokenRect: CGRect) -> Double {
        let horizontalOverlapWidth = horizontalOverlapWidth(between: region.rect, and: tokenRect)
        let overlapToTokenRatio = horizontalOverlapWidth / max(tokenRect.width, 1)
        let horizontalOverlapRatio = horizontalOverlapWidth / max(min(region.rect.width, tokenRect.width), 1)
        guard overlapToTokenRatio > 0.52 || horizontalOverlapRatio > 0.46 else { return 0 }

        let verticalGap = region.rect.minY - tokenRect.maxY
        guard region.rect.midY >= tokenRect.midY else { return 0 }
        guard verticalGap >= -tokenRect.height * 0.18, verticalGap <= tokenRect.height * 0.95 else { return 0 }

        let regionAspect = region.rect.width / max(region.rect.height, 1)
        let thinnessScore = max(0, 1 - region.rect.height / max(tokenRect.height * 0.42, 1))
        let centerDistance = abs(region.rect.midX - tokenRect.midX) / max(tokenRect.width, 1)
        let centerScore = max(0, 1 - centerDistance)
        let gapScore = max(0, 1 - abs(verticalGap) / max(tokenRect.height * 0.9, 1))

        return horizontalOverlapRatio * 1.12
            + overlapToTokenRatio * 0.54
            + gapScore * 0.68
            + min(1, regionAspect / 6.0) * 0.38
            + thinnessScore * 0.32
            + centerScore * 0.24
    }

    nonisolated private func circleRegionMatchScore(_ region: MarkRegion, tokenRect: CGRect) -> Double {
        let expandedTokenRect = tokenRect.insetBy(
            dx: -max(2, tokenRect.width * 0.14),
            dy: -max(2, tokenRect.height * 0.2)
        )
        guard region.rect.intersects(expandedTokenRect) else { return 0 }

        let enclosureScore: Double
        if region.rect.insetBy(dx: -2, dy: -2).contains(tokenRect) {
            enclosureScore = 1
        } else {
            let overlap = region.rect.intersection(expandedTokenRect).area / max(tokenRect.area, 1)
            enclosureScore = min(1, overlap)
        }

        let widthRatio = region.rect.width / max(tokenRect.width, 1)
        let heightRatio = region.rect.height / max(tokenRect.height, 1)
        guard widthRatio > 0.95, heightRatio > 1.0 else { return 0 }

        let diagonal = max(
            hypot(region.rect.width, region.rect.height),
            hypot(tokenRect.width, tokenRect.height),
            1
        )
        let centerDistance = hypot(region.rect.midX - tokenRect.midX, region.rect.midY - tokenRect.midY) / diagonal
        let centerScore = max(0, 1 - centerDistance * 1.45)

        return enclosureScore * 1.05
            + centerScore * 0.36
            + (1 - min(1, abs(region.fillRatio - 0.35))) * 0.22
    }

    nonisolated private func imageRect(for normalizedRect: CGRect) -> CGRect {
        let rect = CGRect(
            x: normalizedRect.minX * CGFloat(width),
            y: (1 - normalizedRect.maxY) * CGFloat(height),
            width: normalizedRect.width * CGFloat(width),
            height: normalizedRect.height * CGFloat(height)
        )

        return rect.intersection(CGRect(x: 0, y: 0, width: width, height: height))
    }

    nonisolated private func maskRatio(in rect: CGRect, mask: [UInt8]) -> Double {
        let sampleRect = normalized(rect)
        guard sampleRect.width >= 1, sampleRect.height >= 1 else { return 0 }

        let minX = Int(sampleRect.minX)
        let maxX = Int(sampleRect.maxX)
        let minY = Int(sampleRect.minY)
        let maxY = Int(sampleRect.maxY)
        var marked = 0
        var total = 0

        for y in minY..<maxY {
            for x in minX..<maxX {
                total += 1
                if mask[y * width + x] > 0 {
                    marked += 1
                }
            }
        }

        guard total > 0 else { return 0 }
        return Double(marked) / Double(total)
    }

    nonisolated private func horizontalMaskCoverage(in rect: CGRect, mask: [UInt8]) -> Double {
        let sampleRect = normalized(rect)
        guard sampleRect.width >= 1, sampleRect.height >= 1 else { return 0 }

        let minX = Int(sampleRect.minX)
        let maxX = Int(sampleRect.maxX)
        let minY = Int(sampleRect.minY)
        let maxY = Int(sampleRect.maxY)

        var hitColumns = 0
        let totalColumns = max(1, maxX - minX)

        for x in minX..<maxX {
            var columnHit = false

            for y in minY..<maxY {
                if mask[y * width + x] > 0 {
                    columnHit = true
                    break
                }
            }

            if columnHit {
                hitColumns += 1
            }
        }

        return Double(hitColumns) / Double(totalColumns)
    }

    nonisolated private func ringMaskRatio(outerRect: CGRect, innerRect: CGRect, mask: [UInt8]) -> Double {
        let outer = normalized(outerRect)
        let inner = normalized(innerRect)
        guard outer.width >= 1, outer.height >= 1 else { return 0 }

        var marked = 0
        var total = 0

        iterateMaskPoints(in: outer) { x, y, point in
            guard !inner.contains(point) else { return }
            total += 1

            if mask[y * width + x] > 0 {
                marked += 1
            }
        }

        guard total > 0 else { return 0 }
        return Double(marked) / Double(total)
    }

    nonisolated private func iterateMaskPoints(in rect: CGRect, _ body: (Int, Int, CGPoint) -> Void) {
        let sampleRect = normalized(rect)
        let minX = Int(sampleRect.minX)
        let maxX = Int(sampleRect.maxX)
        let minY = Int(sampleRect.minY)
        let maxY = Int(sampleRect.maxY)

        for y in minY..<maxY {
            for x in minX..<maxX {
                body(x, y, CGPoint(x: x, y: y))
            }
        }
    }

    nonisolated private func normalized(_ rect: CGRect) -> CGRect {
        rect.intersection(CGRect(x: 0, y: 0, width: width, height: height)).integral
    }

    nonisolated private func horizontalOverlapWidth(between lhs: CGRect, and rhs: CGRect) -> CGFloat {
        max(0, min(lhs.maxX, rhs.maxX) - max(lhs.minX, rhs.minX))
    }
}

private enum StrokeRegionKind {
    case highlight
    case underline
    case circle
}

private struct SamplePixel {
    let red: Double
    let green: Double
    let blue: Double

    nonisolated var luminance: Double {
        0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    nonisolated var brightness: Double {
        (max(red, max(green, blue)) + min(red, min(green, blue))) / 2
    }

    nonisolated var saturation: Double {
        let maxValue = max(red, max(green, blue))
        let minValue = min(red, min(green, blue))

        guard maxValue != minValue else { return 0 }
        let lightness = brightness

        if lightness < 0.5 {
            return (maxValue - minValue) / (maxValue + minValue)
        }

        return (maxValue - minValue) / (2 - maxValue - minValue)
    }

    nonisolated var isColorful: Bool {
        saturation > 0.18 && brightness > 0.30
    }

    nonisolated var isInkLike: Bool {
        brightness < 0.46 || (saturation > 0.26 && brightness > 0.18 && brightness < 0.9)
    }

    nonisolated var isHighlightLike: Bool {
        saturation > 0.16 && brightness > 0.52 && brightness < 0.99
    }

    nonisolated var isColorStrokeLike: Bool {
        saturation > 0.22 && brightness > 0.14 && brightness < 0.88
    }

    nonisolated var looksLikePrintedInk: Bool {
        luminance < 0.52 && saturation < 0.18
    }
}

private enum OCRImageStyle {
    case contrast
    case sharpened
    case thresholded
}

private extension UIImage {
    nonisolated func documentScannedImage(ciContext: CIContext) -> UIImage? {
        guard let cgImage else { return nil }

        let ciImage = CIImage(cgImage: cgImage)

        let controls = CIFilter(name: "CIColorControls")
        controls?.setValue(ciImage, forKey: kCIInputImageKey)
        controls?.setValue(0, forKey: kCIInputSaturationKey)
        controls?.setValue(1.65, forKey: kCIInputContrastKey)
        controls?.setValue(0.03, forKey: kCIInputBrightnessKey)

        let exposure = CIFilter(name: "CIExposureAdjust")
        exposure?.setValue(controls?.outputImage ?? ciImage, forKey: kCIInputImageKey)
        exposure?.setValue(0.28, forKey: kCIInputEVKey)

        let highlights = CIFilter(name: "CIHighlightShadowAdjust")
        highlights?.setValue(exposure?.outputImage ?? controls?.outputImage ?? ciImage, forKey: kCIInputImageKey)
        highlights?.setValue(0.95, forKey: "inputHighlightAmount")
        highlights?.setValue(0.15, forKey: "inputShadowAmount")

        let sharpen = CIFilter(name: "CIUnsharpMask")
        sharpen?.setValue(highlights?.outputImage ?? exposure?.outputImage ?? ciImage, forKey: kCIInputImageKey)
        sharpen?.setValue(1.1, forKey: kCIInputRadiusKey)
        sharpen?.setValue(1.65, forKey: kCIInputIntensityKey)

        let clamp = CIFilter(name: "CIColorClamp")
        clamp?.setValue(sharpen?.outputImage ?? highlights?.outputImage ?? ciImage, forKey: kCIInputImageKey)
        clamp?.setValue(CIVector(x: 0.04, y: 0.04, z: 0.04, w: 1), forKey: "inputMinComponents")
        clamp?.setValue(CIVector(x: 1, y: 1, z: 1, w: 1), forKey: "inputMaxComponents")

        guard let finalImage = clamp?.outputImage ?? sharpen?.outputImage,
              let outputCGImage = ciContext.createCGImage(finalImage, from: finalImage.extent) else {
            return nil
        }

        return UIImage(cgImage: outputCGImage, scale: scale, orientation: .up)
    }

    nonisolated func preparedForAnalysis(maxDimension: CGFloat, ciContext: CIContext) -> UIImage? {
        let normalizedImage = normalizedOrientationImage()
        let correctedImage = normalizedImage.perspectiveCorrectedImage(ciContext: ciContext) ?? normalizedImage
        return correctedImage.resizedForAnalysis(maxDimension: maxDimension)
    }

    nonisolated func makeOCRVariant(style: OCRImageStyle, ciContext: CIContext) -> UIImage? {
        guard let cgImage else { return nil }

        let ciImage = CIImage(cgImage: cgImage)
        let outputImage: CIImage?

        switch style {
        case .contrast:
            let exposure = CIFilter(name: "CIExposureAdjust")
            exposure?.setValue(ciImage, forKey: kCIInputImageKey)
            exposure?.setValue(0.28, forKey: kCIInputEVKey)

            let controls = CIFilter(name: "CIColorControls")
            controls?.setValue(exposure?.outputImage ?? ciImage, forKey: kCIInputImageKey)
            controls?.setValue(0, forKey: kCIInputSaturationKey)
            controls?.setValue(1.42, forKey: kCIInputContrastKey)
            controls?.setValue(0.02, forKey: kCIInputBrightnessKey)
            outputImage = controls?.outputImage

        case .sharpened:
            let controls = CIFilter(name: "CIColorControls")
            controls?.setValue(ciImage, forKey: kCIInputImageKey)
            controls?.setValue(0, forKey: kCIInputSaturationKey)
            controls?.setValue(1.35, forKey: kCIInputContrastKey)
            controls?.setValue(0.01, forKey: kCIInputBrightnessKey)

            let sharpen = CIFilter(name: "CIUnsharpMask")
            sharpen?.setValue(controls?.outputImage ?? ciImage, forKey: kCIInputImageKey)
            sharpen?.setValue(1.3, forKey: kCIInputRadiusKey)
            sharpen?.setValue(1.8, forKey: kCIInputIntensityKey)
            outputImage = sharpen?.outputImage

        case .thresholded:
            let mono = CIFilter(name: "CIColorControls")
            mono?.setValue(ciImage, forKey: kCIInputImageKey)
            mono?.setValue(0, forKey: kCIInputSaturationKey)
            mono?.setValue(1.62, forKey: kCIInputContrastKey)
            mono?.setValue(0.01, forKey: kCIInputBrightnessKey)

            let clamp = CIFilter(name: "CIColorClamp")
            clamp?.setValue(mono?.outputImage ?? ciImage, forKey: kCIInputImageKey)
            clamp?.setValue(CIVector(x: 0.08, y: 0.08, z: 0.08, w: 1), forKey: "inputMinComponents")
            clamp?.setValue(CIVector(x: 1, y: 1, z: 1, w: 1), forKey: "inputMaxComponents")

            let sharpen = CIFilter(name: "CIUnsharpMask")
            sharpen?.setValue(clamp?.outputImage ?? mono?.outputImage ?? ciImage, forKey: kCIInputImageKey)
            sharpen?.setValue(1.0, forKey: kCIInputRadiusKey)
            sharpen?.setValue(1.45, forKey: kCIInputIntensityKey)
            outputImage = sharpen?.outputImage
        }

        guard let finalImage = outputImage,
              let outputCGImage = ciContext.createCGImage(finalImage, from: finalImage.extent) else {
            return nil
        }

        return UIImage(cgImage: outputCGImage, scale: 1, orientation: .up)
    }

    nonisolated func perspectiveCorrectedImage(ciContext: CIContext) -> UIImage? {
        guard let cgImage else { return nil }

        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumConfidence = 0.65
        request.minimumAspectRatio = 0.45
        request.quadratureTolerance = 25

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let rectangle = request.results?.first,
              rectangle.boundingBox.width * rectangle.boundingBox.height > 0.22 else {
            return nil
        }

        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            return nil
        }

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: CGPoint(
            x: rectangle.topLeft.x * ciImage.extent.width,
            y: rectangle.topLeft.y * ciImage.extent.height
        )), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: CGPoint(
            x: rectangle.topRight.x * ciImage.extent.width,
            y: rectangle.topRight.y * ciImage.extent.height
        )), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: CGPoint(
            x: rectangle.bottomLeft.x * ciImage.extent.width,
            y: rectangle.bottomLeft.y * ciImage.extent.height
        )), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: CGPoint(
            x: rectangle.bottomRight.x * ciImage.extent.width,
            y: rectangle.bottomRight.y * ciImage.extent.height
        )), forKey: "inputBottomRight")

        guard let outputImage = filter.outputImage,
              let correctedCGImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }

        return UIImage(cgImage: correctedCGImage, scale: scale, orientation: .up)
    }

    nonisolated func resizedForAnalysis(maxDimension: CGFloat) -> UIImage? {
        let longestSide = max(size.width, size.height)

        guard longestSide > maxDimension else {
            return self
        }

        let scaleRatio = maxDimension / longestSide
        let resizedSize = CGSize(width: size.width * scaleRatio, height: size.height * scaleRatio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: resizedSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: resizedSize))
        }
    }

    nonisolated func normalizedOrientationImage() -> UIImage {
        guard imageOrientation != .up else { return self }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private extension CGRect {
    nonisolated var area: CGFloat {
        max(0, width) * max(0, height)
    }

    nonisolated func intersectionOverUnion(with other: CGRect) -> CGFloat {
        let intersectionArea = intersection(other).area
        guard intersectionArea > 0 else { return 0 }

        let unionArea = area + other.area - intersectionArea
        guard unionArea > 0 else { return 0 }
        return intersectionArea / unionArea
    }
}

nonisolated private func averageRect(of rects: [CGRect]) -> CGRect {
    guard let firstRect = rects.first else { return .zero }

    let totals = rects.reduce((x: 0.0, y: 0.0, width: 0.0, height: 0.0)) { partial, rect in
        (
            partial.x + rect.origin.x,
            partial.y + rect.origin.y,
            partial.width + rect.size.width,
            partial.height + rect.size.height
        )
    }

    let count = CGFloat(rects.count)
    let averageRect = CGRect(
        x: totals.x / count,
        y: totals.y / count,
        width: totals.width / count,
        height: totals.height / count
    )

    if averageRect.width <= 0 || averageRect.height <= 0 {
        return firstRect
    }

    return averageRect
}

nonisolated private func strokeRegionKind(for region: MarkRegion) -> StrokeRegionKind? {
    let aspectRatio = region.rect.width / max(region.rect.height, 1)

    if aspectRatio >= 3.4,
       region.rect.height <= max(10, region.rect.width * 0.22),
       region.fillRatio < 0.92 {
        return .underline
    }

    if aspectRatio >= 0.5,
       aspectRatio <= 2.8,
       region.rect.width >= 10,
       region.rect.height >= 10,
       region.fillRatio <= 0.70 {
        return .circle
    }

    return nil
}

nonisolated private func extractSelectionRegions(
    from mask: [UInt8],
    width: Int,
    height: Int
) -> [UserSelectionRegion] {
    guard !mask.isEmpty else { return [] }

    let cellSize = max(2, min(3, max(width, height) / 700))
    let maskWidth = max(1, width / cellSize)
    let maskHeight = max(1, height / cellSize)
    var active = Array(repeating: false, count: maskWidth * maskHeight)
    var densities = Array(repeating: 0.0, count: maskWidth * maskHeight)

    for cellY in 0..<maskHeight {
        for cellX in 0..<maskWidth {
            let startX = cellX * cellSize
            let startY = cellY * cellSize
            let endX = min(width, startX + cellSize)
            let endY = min(height, startY + cellSize)

            var painted = 0
            var total = 0

            for y in startY..<endY {
                for x in startX..<endX {
                    total += 1
                    if mask[y * width + x] > 0 {
                        painted += 1
                    }
                }
            }

            let density = total > 0 ? Double(painted) / Double(total) : 0
            let index = cellY * maskWidth + cellX
            densities[index] = density
            let minimumPaintedPixels = max(1, cellSize / 3)
            active[index] = painted >= minimumPaintedPixels && density >= 0.02
        }
    }

    var visited = Array(repeating: false, count: active.count)
    var regions: [UserSelectionRegion] = []

    for startIndex in active.indices where active[startIndex] && !visited[startIndex] {
        var queue = [startIndex]
        visited[startIndex] = true
        var queueIndex = 0
        var minCellX = Int.max
        var minCellY = Int.max
        var maxCellX = 0
        var maxCellY = 0
        var activeCount = 0
        var densityTotal = 0.0

        while queueIndex < queue.count {
            let index = queue[queueIndex]
            queueIndex += 1

            let cellX = index % maskWidth
            let cellY = index / maskWidth
            minCellX = min(minCellX, cellX)
            minCellY = min(minCellY, cellY)
            maxCellX = max(maxCellX, cellX)
            maxCellY = max(maxCellY, cellY)
            activeCount += 1
            densityTotal += densities[index]

            for deltaY in -1...1 {
                for deltaX in -1...1 where !(deltaX == 0 && deltaY == 0) {
                    let nextX = cellX + deltaX
                    let nextY = cellY + deltaY

                    guard nextX >= 0, nextY >= 0, nextX < maskWidth, nextY < maskHeight else {
                        continue
                    }

                    let nextIndex = nextY * maskWidth + nextX
                    guard active[nextIndex], !visited[nextIndex] else { continue }
                    visited[nextIndex] = true
                    queue.append(nextIndex)
                }
            }
        }

        let coarseRect = CGRect(
            x: minCellX * cellSize,
            y: minCellY * cellSize,
            width: max(cellSize, (maxCellX - minCellX + 1) * cellSize),
            height: max(cellSize, (maxCellY - minCellY + 1) * cellSize)
        ).intersection(CGRect(x: 0, y: 0, width: width, height: height))

        let rect = tightenSelectionRect(
            coarseRect,
            mask: mask,
            width: width,
            height: height
        )

        guard rect.width >= 4, rect.height >= 4 else { continue }

        let paintedPixels = markedPixelCount(in: rect, mask: mask, width: width, height: height)
        let paintedRatio = maskRatio(in: rect, mask: mask, width: width, height: height)
        let minimumPaintedPixels = max(6, cellSize)

        guard paintedPixels >= minimumPaintedPixels || paintedRatio >= 0.09 else {
            continue
        }

        let fillRatio = Double(activeCount * cellSize * cellSize) / max(rect.area, 1)
        let averageDensity = densityTotal / Double(activeCount)
        let regionFill = max(max(fillRatio, averageDensity), paintedRatio)
        regions.append(UserSelectionRegion(rect: rect, fillRatio: regionFill))
    }

    return regions.sorted { lhs, rhs in
        if lhs.rect.minY == rhs.rect.minY {
            return lhs.rect.minX < rhs.rect.minX
        }

        return lhs.rect.minY < rhs.rect.minY
    }
}

nonisolated private func tightenSelectionRect(
    _ rect: CGRect,
    mask: [UInt8],
    width: Int,
    height: Int
) -> CGRect {
    let bounded = rect
        .intersection(CGRect(x: 0, y: 0, width: width, height: height))
        .integral

    guard !bounded.isNull, !bounded.isEmpty else { return rect }

    let minXBound = max(0, Int(floor(bounded.minX)))
    let maxXBound = min(width - 1, Int(ceil(bounded.maxX)) - 1)
    let minYBound = max(0, Int(floor(bounded.minY)))
    let maxYBound = min(height - 1, Int(ceil(bounded.maxY)) - 1)

    guard minXBound <= maxXBound, minYBound <= maxYBound else { return bounded }

    var minX = Int.max
    var minY = Int.max
    var maxX = Int.min
    var maxY = Int.min

    for y in minYBound...maxYBound {
        for x in minXBound...maxXBound {
            if mask[y * width + x] > 0 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
    }

    guard minX != Int.max, minY != Int.max, maxX != Int.min, maxY != Int.min else {
        return bounded
    }

    return CGRect(
        x: max(0, minX - 1),
        y: max(0, minY - 1),
        width: min(width, maxX + 2) - max(0, minX - 1),
        height: min(height, maxY + 2) - max(0, minY - 1)
    ).integral
}

nonisolated private func mergeNearbySelectionRects(_ rects: [CGRect]) -> [CGRect] {
    var merged: [CGRect] = []

    for rect in rects.sorted(by: { lhs, rhs in
        if lhs.minY == rhs.minY {
            return lhs.minX < rhs.minX
        }
        return lhs.minY < rhs.minY
    }) {
        if let index = merged.firstIndex(where: { existing in
            existing.insetBy(
                dx: -max(6, existing.width * 0.08),
                dy: -max(6, existing.height * 0.14)
            ).intersects(rect)
        }) {
            merged[index] = merged[index].union(rect)
        } else {
            merged.append(rect)
        }
    }

    return merged
}

nonisolated private func markedPixelCount(
    in rect: CGRect,
    mask: [UInt8],
    width: Int,
    height: Int
) -> Int {
    let sampleRect = rect
        .intersection(CGRect(x: 0, y: 0, width: width, height: height))
        .integral

    guard sampleRect.width >= 1, sampleRect.height >= 1 else { return 0 }

    let minX = Int(sampleRect.minX)
    let maxX = Int(sampleRect.maxX)
    let minY = Int(sampleRect.minY)
    let maxY = Int(sampleRect.maxY)
    var marked = 0

    for y in minY..<maxY {
        for x in minX..<maxX where mask[y * width + x] > 0 {
            marked += 1
        }
    }

    return marked
}

nonisolated private func darkStrokeRegionLooksClean(
    _ region: MarkRegion,
    rawMask: [UInt8],
    width: Int,
    height: Int
) -> Bool {
    guard let kind = strokeRegionKind(for: region) else { return false }
    let rect = region.rect
        .intersection(CGRect(x: 0, y: 0, width: width, height: height))
        .integral

    guard rect.width >= 1, rect.height >= 1 else { return false }

    let minX = Int(rect.minX)
    let maxX = Int(rect.maxX)
    let minY = Int(rect.minY)
    let maxY = Int(rect.maxY)
    let regionWidth = max(1, maxX - minX)
    let regionHeight = max(1, maxY - minY)

    var rowCoverages: [Double] = []
    rowCoverages.reserveCapacity(regionHeight)
    var columnCoverages: [Double] = []
    columnCoverages.reserveCapacity(regionWidth)

    for y in minY..<maxY {
        var hits = 0
        for x in minX..<maxX where rawMask[y * width + x] > 0 {
            hits += 1
        }
        rowCoverages.append(Double(hits) / Double(regionWidth))
    }

    for x in minX..<maxX {
        var hits = 0
        for y in minY..<maxY where rawMask[y * width + x] > 0 {
            hits += 1
        }
        columnCoverages.append(Double(hits) / Double(regionHeight))
    }

    let peakRowCoverage = rowCoverages.max() ?? 0
    let averageRowCoverage = rowCoverages.reduce(0, +) / Double(max(rowCoverages.count, 1))
    let peakColumnCoverage = columnCoverages.max() ?? 0

    switch kind {
    case .underline:
        return peakRowCoverage >= 0.46
            && averageRowCoverage <= 0.58
            && rect.height <= max(14, rect.width * 0.20)
            && region.fillRatio <= 0.68
    case .circle:
        let borderRatio = ringOccupancyRatio(
            outerRect: rect,
            innerRect: rect.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.18),
            mask: rawMask,
            width: width
        )
        let innerRatio = maskRatio(
            in: rect.insetBy(dx: rect.width * 0.22, dy: rect.height * 0.22),
            mask: rawMask,
            width: width,
            height: height
        )

        return borderRatio >= max(0.12, innerRatio * 1.4)
            && peakColumnCoverage >= 0.22
            && region.fillRatio <= 0.60
    case .highlight:
        return false
    }
}

nonisolated private func retainMaskPixels(
    from rawMask: [UInt8],
    within regions: [MarkRegion],
    width: Int,
    height: Int
) -> [UInt8] {
    guard !regions.isEmpty else {
        return Array(repeating: UInt8(0), count: rawMask.count)
    }

    var cleanedMask = Array(repeating: UInt8(0), count: rawMask.count)

    for region in regions {
        let rect = region.rect
            .intersection(CGRect(x: 0, y: 0, width: width, height: height))
            .integral

        guard rect.width >= 1, rect.height >= 1 else { continue }

        let minX = Int(rect.minX)
        let maxX = Int(rect.maxX)
        let minY = Int(rect.minY)
        let maxY = Int(rect.maxY)

        for y in minY..<maxY {
            for x in minX..<maxX {
                let index = y * width + x
                if rawMask[index] > 0 {
                    cleanedMask[index] = 255
                }
            }
        }
    }

    return cleanedMask
}

nonisolated private func unionMask(_ lhs: [UInt8], _ rhs: [UInt8]) -> [UInt8] {
    guard lhs.count == rhs.count else { return lhs }
    return zip(lhs, rhs).map { left, right in
        (left > 0 || right > 0) ? 255 : 0
    }
}

nonisolated private func maskRatio(
    in rect: CGRect,
    mask: [UInt8],
    width: Int,
    height: Int
) -> Double {
    let sampleRect = rect
        .intersection(CGRect(x: 0, y: 0, width: width, height: height))
        .integral
    guard sampleRect.width >= 1, sampleRect.height >= 1 else { return 0 }

    let minX = Int(sampleRect.minX)
    let maxX = Int(sampleRect.maxX)
    let minY = Int(sampleRect.minY)
    let maxY = Int(sampleRect.maxY)
    var marked = 0
    var total = 0

    for y in minY..<maxY {
        for x in minX..<maxX {
            total += 1
            if mask[y * width + x] > 0 {
                marked += 1
            }
        }
    }

    guard total > 0 else { return 0 }
    return Double(marked) / Double(total)
}

nonisolated private func ringOccupancyRatio(
    outerRect: CGRect,
    innerRect: CGRect,
    mask: [UInt8],
    width: Int
) -> Double {
    let outer = outerRect.integral
    let inner = innerRect.integral
    guard outer.width >= 1, outer.height >= 1 else { return 0 }

    var marked = 0
    var total = 0

    for y in Int(outer.minY)..<Int(outer.maxY) {
        for x in Int(outer.minX)..<Int(outer.maxX) {
            let point = CGPoint(x: x, y: y)
            guard !inner.contains(point) else { continue }
            total += 1
            if mask[y * width + x] > 0 {
                marked += 1
            }
        }
    }

    guard total > 0 else { return 0 }
    return Double(marked) / Double(total)
}

nonisolated private func topLeftPixelRect(
    fromVisionRect rect: CGRect,
    imageWidth: Int,
    imageHeight: Int
) -> CGRect {
    CGRect(
        x: rect.minX * CGFloat(imageWidth),
        y: (1 - rect.maxY) * CGFloat(imageHeight),
        width: rect.width * CGFloat(imageWidth),
        height: rect.height * CGFloat(imageHeight)
    )
}

nonisolated private func visionRect(
    fromTopLeftPixelRect rect: CGRect,
    sourceWidth: Int,
    sourceHeight: Int
) -> CGRect {
    let width = rect.width / CGFloat(sourceWidth)
    let height = rect.height / CGFloat(sourceHeight)
    let minX = rect.minX / CGFloat(sourceWidth)
    let maxY = 1 - rect.minY / CGFloat(sourceHeight)

    return CGRect(
        x: minX,
        y: max(0, maxY - height),
        width: max(0, width),
        height: max(0, height)
    )
}

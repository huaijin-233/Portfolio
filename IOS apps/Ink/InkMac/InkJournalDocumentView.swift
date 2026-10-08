#if os(macOS)
//
//  InkJournalDocumentView.swift
//  Ink
//
//  Created by Codex on 3/13/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct InkJournalDocumentView: View {
    @EnvironmentObject private var localization: InkLocalization
    @EnvironmentObject private var themeController: WriteThemeController

    @Binding var document: InkJournalDocument
    let fileURL: URL?
    @FocusState private var isTitleFocused: Bool
    @State private var isBodyFocused = false
    @State private var isImportingMedia = false
    @State private var isPresentingCamera = false
    @State private var isCapturingScreenshot = false
    @State private var isProcessingMedia = false
    @State private var mediaErrorMessage: String?
    @State private var attachmentCacheDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("InkDocumentCache-\(UUID().uuidString)", isDirectory: true)
    @State private var cachedAttachmentURLs: [UUID: URL] = [:]
    @State private var cachedAttachmentAudioURLs: [UUID: URL] = [:]
    @State private var attachmentsPreparingCache: Set<UUID> = []

    var body: some View {
        ZStack {
            ExecutiveBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(localization.documentHeader)
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.8)
                                .foregroundStyle(.secondary)

                            Text(localization.editorDate(document.entry.createdAt))
                                .font(.system(size: 28, weight: .medium, design: .serif))
                                .foregroundStyle(Color.primary.opacity(0.82))
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 12) {
                                EditorStatusPill(title: localization.editableDocument)
                                EditorStatusPill(title: localization.wordCountText(document.entry.wordCount))
                            }
                        }

                        Spacer(minLength: 20)

                        HStack(spacing: 10) {
                            ActionIconButton(
                                systemImage: "viewfinder.rectangular",
                                helpText: localization.screenshotMedia,
                                action: captureScreenshot
                            )
                            .disabled(isCapturingScreenshot || isProcessingMedia)

                            ActionIconButton(
                                systemImage: "camera",
                                helpText: localization.cameraMedia,
                                action: { isPresentingCamera = true }
                            )
                            .disabled(isProcessingMedia)

                            ActionIconButton(
                                systemImage: "tray.and.arrow.down",
                                helpText: localization.importMedia,
                                action: { isImportingMedia = true }
                            )
                            .disabled(isProcessingMedia)
                        }
                    }

                    Divider()
                        .overlay(themeController.palette.divider)

                    JournalTitleField(text: titleBinding, isFocused: $isTitleFocused)

                    JournalAttachmentSection(
                        attachments: document.entry.attachments,
                        urlProvider: attachmentURL,
                        audioURLProvider: audioAttachmentURL,
                        onRemove: removeAttachment,
                        showsImportProgress: isProcessingMedia
                    )

                    PremiumTextEditor(
                        text: bodyBinding,
                        placeholder: localization.bodyPlaceholder,
                        isFocused: false,
                        isEditorFocused: $isBodyFocused,
                        theme: themeController.palette
                    )
                    .frame(minHeight: 420)
                }
                .padding(38)
                .background {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                                .strokeBorder(themeController.palette.elevatedSurfaceStroke, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 28, y: 18)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 32)
            }
        }
        .background(SystemContainerBackgroundClearer())
        .toolbarBackground(.hidden, for: .windowToolbar)
        .onAppear {
            try? FileManager.default.createDirectory(
                at: attachmentCacheDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )

            guard document.entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                applyIconIfPossible(for: fileURL)
                return
            }

            DispatchQueue.main.async {
                isTitleFocused = true
            }

            applyIconIfPossible(for: fileURL)
        }
        .onChange(of: fileURL) { _, newURL in
            applyIconIfPossible(for: newURL)
        }
        .onChange(of: document.entry.attachments) { _, attachments in
            let attachmentIDs = Set(attachments.map(\.id))
            cachedAttachmentURLs = cachedAttachmentURLs.filter { attachmentIDs.contains($0.key) }
            cachedAttachmentAudioURLs = cachedAttachmentAudioURLs.filter { attachmentIDs.contains($0.key) }
            attachmentsPreparingCache = attachmentsPreparingCache.filter { attachmentIDs.contains($0) }
        }
        .fileImporter(
            isPresented: $isImportingMedia,
            allowedContentTypes: [.image, .movie],
            allowsMultipleSelection: true,
            onCompletion: handleImportedMedia
        )
        .sheet(isPresented: $isPresentingCamera) {
            CameraCaptureSheet(
                onPhotoCaptured: handleCapturedPhoto,
                onVideoCaptured: handleCapturedVideo
            )
            .environmentObject(localization)
        }
        .alert(
            localization.captureMediaErrorTitle,
            isPresented: Binding(
                get: { mediaErrorMessage != nil },
                set: { if !$0 { mediaErrorMessage = nil } }
            )
        ) {
            Button(localization.dismissAction) {
                mediaErrorMessage = nil
            }
        } message: {
            Text(mediaErrorMessage ?? "")
        }
        .onDisappear {
            try? FileManager.default.removeItem(at: attachmentCacheDirectory)
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { document.entry.title },
            set: {
                document.entry.title = $0
                document.entry.updatedAt = .now
            }
        )
    }

    private var bodyBinding: Binding<String> {
        Binding(
            get: { document.entry.body },
            set: {
                document.entry.body = $0
                document.entry.updatedAt = .now
            }
        )
    }

    private func applyIconIfPossible(for url: URL?) {
        guard let url else {
            return
        }

        DocumentIconManager.applyInkIcon(to: url)
    }

    private func attachmentURL(for attachment: JournalAttachment) -> URL? {
        if let cachedURL = cachedAttachmentURLs[attachment.id],
           FileManager.default.fileExists(atPath: cachedURL.path) {
            return cachedURL
        }

        let cachedURL = attachmentCacheDirectory.appendingPathComponent(attachment.filename)

        if FileManager.default.fileExists(atPath: cachedURL.path) {
            cachedAttachmentURLs[attachment.id] = cachedURL
            return cachedURL
        }

        prepareAttachmentCacheIfNeeded(for: attachment)
        return nil
    }

    private func audioAttachmentURL(for attachment: JournalAttachment) -> URL? {
        guard attachment.audioFilename != nil else {
            return nil
        }

        if let cachedURL = cachedAttachmentAudioURLs[attachment.id],
           FileManager.default.fileExists(atPath: cachedURL.path) {
            return cachedURL
        }

        prepareAttachmentCacheIfNeeded(for: attachment)
        return nil
    }

    private func removeAttachment(_ attachment: JournalAttachment) {
        withAnimation(.spring(duration: 0.3, bounce: 0.04)) {
            document.removeAttachment(attachment.id)
        }

        let cachedURL = attachmentCacheDirectory.appendingPathComponent(attachment.filename)
        try? FileManager.default.removeItem(at: cachedURL)
        cachedAttachmentURLs.removeValue(forKey: attachment.id)

        if let audioFilename = attachment.audioFilename {
            let cachedAudioURL = attachmentCacheDirectory.appendingPathComponent(audioFilename)
            try? FileManager.default.removeItem(at: cachedAudioURL)
        }
        cachedAttachmentAudioURLs.removeValue(forKey: attachment.id)
        attachmentsPreparingCache.remove(attachment.id)
    }

    private func captureScreenshot() {
        guard !isCapturingScreenshot else {
            return
        }

        isCapturingScreenshot = true

        Task {
            defer {
                isCapturingScreenshot = false
            }

            do {
                guard let screenshotURL = try await ScreenshotCaptureService.captureSelection() else {
                    return
                }

                try await importPayload(
                    from: screenshotURL,
                    removeSourceWhenFinished: true
                )
            } catch {
                mediaErrorMessage = error.localizedDescription
            }
        }
    }

    private func handleCapturedPhoto(_ data: Data) {
        let payload = JournalAttachmentLibrary.payload(
            data: data,
            fileExtension: "jpg",
            kind: .image,
            originalFilename: "Camera Photo.jpg"
        )
        document.addAttachment(payload)
    }

    private func handleCapturedVideo(_ capture: CapturedVideoRecording) {
        Task {
            do {
                try await importPayload(
                    from: capture.videoURL,
                    companionAudioAt: capture.audioURL,
                    removeSourceWhenFinished: true
                )
            } catch {
                mediaErrorMessage = error.localizedDescription
            }
        }
    }

    private func handleImportedMedia(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else {
                return
            }

            Task {
                do {
                    for url in urls {
                        let didAccess = url.startAccessingSecurityScopedResource()
                        defer {
                            if didAccess {
                                url.stopAccessingSecurityScopedResource()
                            }
                        }

                        try await importPayload(from: url)
                    }
                } catch {
                    mediaErrorMessage = error.localizedDescription
                }
            }

        case .failure(let error):
            mediaErrorMessage = error.localizedDescription
        }
    }

    private func importPayload(
        from sourceURL: URL,
        companionAudioAt companionAudioURL: URL? = nil,
        removeSourceWhenFinished: Bool = false
    ) async throws {
        let cacheDirectory = attachmentCacheDirectory

        isProcessingMedia = true

        defer {
            isProcessingMedia = false

            if removeSourceWhenFinished {
                try? FileManager.default.removeItem(at: sourceURL)
                if let companionAudioURL {
                    try? FileManager.default.removeItem(at: companionAudioURL)
                }
            }
        }

        let result = try await Task.detached(priority: .userInitiated) {
            let payload = try JournalAttachmentLibrary.payload(from: sourceURL, companionAudioAt: companionAudioURL)
            let cacheURL = cacheDirectory.appendingPathComponent(payload.attachment.filename)

            try FileManager.default.createDirectory(
                at: cacheDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try payload.data.write(to: cacheURL, options: [.atomic])

            let cacheAudioURL: URL?
            if let companionAudio = payload.companionAudio,
               let audioFilename = payload.attachment.audioFilename {
                let url = cacheDirectory.appendingPathComponent(audioFilename)
                try companionAudio.data.write(to: url, options: [.atomic])
                cacheAudioURL = url
            } else {
                cacheAudioURL = nil
            }

            return (payload, cacheURL, cacheAudioURL)
        }.value

        cachedAttachmentURLs[result.0.attachment.id] = result.1
        if let cacheAudioURL = result.2 {
            cachedAttachmentAudioURLs[result.0.attachment.id] = cacheAudioURL
        }
        attachmentsPreparingCache.remove(result.0.attachment.id)
        document.addAttachment(result.0)
    }

    private func prepareAttachmentCacheIfNeeded(for attachment: JournalAttachment) {
        let needsPrimaryCache = cachedAttachmentURLs[attachment.id] == nil
        let needsAudioCache = attachment.audioFilename != nil && cachedAttachmentAudioURLs[attachment.id] == nil

        guard (needsPrimaryCache || needsAudioCache),
              !attachmentsPreparingCache.contains(attachment.id),
              let data = document.data(for: attachment) else {
            return
        }

        let audioData = document.audioData(for: attachment)

        attachmentsPreparingCache.insert(attachment.id)

        let cacheURL = attachmentCacheDirectory.appendingPathComponent(attachment.filename)
        let cacheDirectory = attachmentCacheDirectory

        Task {
            do {
                let preparedURL = try await Task.detached(priority: .utility) {
                    try FileManager.default.createDirectory(
                        at: cacheDirectory,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                    try data.write(to: cacheURL, options: [.atomic])
                    if let audioData,
                       let audioFilename = attachment.audioFilename {
                        let audioCacheURL = cacheDirectory.appendingPathComponent(audioFilename)
                        try audioData.write(to: audioCacheURL, options: [.atomic])
                        return (cacheURL, audioCacheURL as URL?)
                    }

                    return (cacheURL, nil as URL?)
                }.value

                cachedAttachmentURLs[attachment.id] = preparedURL.0
                if let audioURL = preparedURL.1 {
                    cachedAttachmentAudioURLs[attachment.id] = audioURL
                }
            } catch {
                mediaErrorMessage = error.localizedDescription
            }

            attachmentsPreparingCache.remove(attachment.id)
        }
    }
}
#endif

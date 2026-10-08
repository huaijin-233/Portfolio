#if os(macOS)
//
//  ContentView.swift
//  Ink
//
//  Created by Huaijin233 on 3/13/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: JournalStore
    @EnvironmentObject private var localization: InkLocalization
    @Namespace private var selectionAnimation
    @State private var focusRequestID: UUID?
    @State private var exportDocument: InkJournalDocument?
    @State private var isExportingDocument = false
    @State private var isPreparingExport = false
    @State private var isImportingMedia = false
    @State private var isPresentingCamera = false
    @State private var activeMediaEntryID: UUID?
    @State private var isCapturingScreenshot = false
    @State private var mediaProcessingEntryID: UUID?
    @State private var mediaErrorMessage: String?

    var body: some View {
        NavigationSplitView {
            SidebarView(
                entries: store.entries,
                selection: store.selectedEntryID,
                selectionAnimation: selectionAnimation,
                onSelectEntry: selectEntry,
                onCreateEntry: createEntry,
                onMoveEntry: moveEntry
            )
            .navigationSplitViewColumnWidth(min: 290, ideal: 320, max: 360)
        } detail: {
            ZStack {
                ExecutiveBackdrop()

                if let selectedEntry = store.selectedEntry {
                    JournalEditorView(
                        entry: selectedEntry,
                        title: titleBinding(for: selectedEntry.id),
                        bodyText: bodyBinding(for: selectedEntry.id),
                        attachmentURLProvider: { attachment in
                            store.attachmentURL(for: attachment, entryID: selectedEntry.id)
                        },
                        attachmentAudioURLProvider: { attachment in
                            store.audioAttachmentURL(for: attachment, entryID: selectedEntry.id)
                        },
                        isTitleFocusRequested: focusRequestID == selectedEntry.id,
                        onFocusHandled: { focusRequestID = nil },
                        onCreateEntry: createEntry,
                        onSaveAs: exportSelectedEntry,
                        onDelete: deleteSelectedEntry,
                        onCaptureScreenshot: { captureScreenshot(for: selectedEntry.id) },
                        onOpenCamera: { openCamera(for: selectedEntry.id) },
                        onImportMedia: { importMedia(for: selectedEntry.id) },
                        onRemoveAttachment: { attachment in
                            removeAttachment(attachment, from: selectedEntry.id)
                        },
                        isCapturingScreenshot: isCapturingScreenshot,
                        isProcessingMedia: mediaProcessingEntryID == selectedEntry.id,
                        isPreparingExport: isPreparingExport
                    )
                    .id(selectedEntry.id)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 18)),
                            removal: .opacity
                        )
                    )
                } else {
                    EmptyJournalView(onCreateEntry: createEntry)
                        .transition(.opacity)
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.04), value: store.selectedEntryID)
        }
        .background(SystemContainerBackgroundClearer())
        .toolbarBackground(.hidden, for: .windowToolbar)
        .fileExporter(
            isPresented: $isExportingDocument,
            document: exportDocument,
            contentType: .inkJournal,
            defaultFilename: exportDocument?.suggestedFilename
        ) { result in
            switch result {
            case .success(let url):
                DocumentIconManager.applyInkIcon(to: url)

            case .failure:
                NSSound.beep()
            }

            exportDocument = nil
        }
        .fileImporter(
            isPresented: $isImportingMedia,
            allowedContentTypes: [.image, .movie],
            allowsMultipleSelection: true
        ) { result in
            guard let entryID = activeMediaEntryID else {
                return
            }

            handleImportedMedia(result, entryID: entryID)
        }
        .sheet(
            isPresented: $isPresentingCamera,
            onDismiss: {
                activeMediaEntryID = nil
            }
        ) {
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
    }

    private func createEntry() {
        let animation = Animation.spring(duration: 0.45, bounce: 0.14)
        let newEntryID = withAnimation(animation) {
            store.createEntry()
        }

        focusRequestID = newEntryID
    }

    private func selectEntry(_ entryID: UUID) {
        withAnimation(.spring(duration: 0.35, bounce: 0.06)) {
            store.selectedEntryID = entryID
        }
    }

    private func moveEntry(_ entryID: UUID, to destinationIndex: Int) {
        store.moveEntry(entryID, to: destinationIndex)
    }

    private func deleteSelectedEntry() {
        withAnimation(.spring(duration: 0.32, bounce: 0.02)) {
            store.deleteSelectedEntry()
        }
    }

    private func titleBinding(for entryID: UUID) -> Binding<String> {
        Binding(
            get: { store.entry(for: entryID)?.title ?? "" },
            set: { store.updateTitle($0, for: entryID) }
        )
    }

    private func bodyBinding(for entryID: UUID) -> Binding<String> {
        Binding(
            get: { store.bodyText(for: entryID) },
            set: { store.updateBody($0, for: entryID) }
        )
    }

    private func exportSelectedEntry() {
        guard let entryID = store.selectedEntryID,
              !isPreparingExport else {
            return
        }

        isPreparingExport = true

        Task {
            defer {
                isPreparingExport = false
            }

            do {
                exportDocument = try await store.prepareDocument(for: entryID)
                isExportingDocument = true
            } catch {
                mediaErrorMessage = error.localizedDescription
            }
        }
    }

    private func captureScreenshot(for entryID: UUID) {
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

                beginMediaProcessing(for: entryID)

                defer {
                    finishMediaProcessing(for: entryID)
                    try? FileManager.default.removeItem(at: screenshotURL)
                }

                try await store.importAttachment(from: screenshotURL, to: entryID)
            } catch {
                mediaErrorMessage = error.localizedDescription
            }
        }
    }

    private func openCamera(for entryID: UUID) {
        activeMediaEntryID = entryID
        isPresentingCamera = true
    }

    private func importMedia(for entryID: UUID) {
        activeMediaEntryID = entryID
        isImportingMedia = true
    }

    private func removeAttachment(_ attachment: JournalAttachment, from entryID: UUID) {
        withAnimation(.spring(duration: 0.3, bounce: 0.04)) {
            store.removeAttachment(attachment.id, from: entryID)
        }
    }

    private func handleCapturedPhoto(_ data: Data) {
        guard let entryID = activeMediaEntryID else {
            return
        }

        beginMediaProcessing(for: entryID)

        Task {
            defer {
                finishMediaProcessing(for: entryID)
            }

            do {
                try await store.importAttachment(
                    data: data,
                    fileExtension: "jpg",
                    kind: .image,
                    originalFilename: "Camera Photo.jpg",
                    to: entryID
                )
            } catch {
                mediaErrorMessage = error.localizedDescription
            }
        }
    }

    private func handleCapturedVideo(_ capture: CapturedVideoRecording) {
        guard let entryID = activeMediaEntryID else {
            return
        }

        beginMediaProcessing(for: entryID)

        Task {
            defer {
                finishMediaProcessing(for: entryID)
                try? FileManager.default.removeItem(at: capture.videoURL)
                if let audioURL = capture.audioURL {
                    try? FileManager.default.removeItem(at: audioURL)
                }
            }

            do {
                try await store.importRecordedAttachment(
                    videoAt: capture.videoURL,
                    audioAt: capture.audioURL,
                    to: entryID
                )
            } catch {
                mediaErrorMessage = error.localizedDescription
            }
        }
    }

    private func handleImportedMedia(_ result: Result<[URL], Error>, entryID: UUID) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else {
                return
            }

            beginMediaProcessing(for: entryID)

            Task {
                defer {
                    finishMediaProcessing(for: entryID)
                }

                do {
                    for url in urls {
                        let didAccess = url.startAccessingSecurityScopedResource()
                        defer {
                            if didAccess {
                                url.stopAccessingSecurityScopedResource()
                            }
                        }

                        try await store.importAttachment(from: url, to: entryID)
                    }
                } catch {
                    mediaErrorMessage = error.localizedDescription
                }
            }

        case .failure(let error):
            mediaErrorMessage = error.localizedDescription
        }
    }

    private func beginMediaProcessing(for entryID: UUID) {
        mediaProcessingEntryID = entryID
    }

    private func finishMediaProcessing(for entryID: UUID) {
        guard mediaProcessingEntryID == entryID else {
            return
        }

        mediaProcessingEntryID = nil
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var localization: InkLocalization
    @EnvironmentObject private var themeController: WriteThemeController

    let entries: [JournalEntry]
    let selection: UUID?
    let selectionAnimation: Namespace.ID
    let onSelectEntry: (UUID) -> Void
    let onCreateEntry: () -> Void
    let onMoveEntry: (UUID, Int) -> Void

    @State private var draggedEntryID: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartFrame: CGRect?
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var lastDragDestinationIndex: Int?

    var body: some View {
        ZStack {
            SidebarBackdrop()

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ink5")
                                .font(.system(size: 28, weight: .semibold, design: .serif))

                            Text(localization.sidebarSubtitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        ActionIconButton(
                            systemImage: "plus",
                            helpText: localization.newJournal,
                            action: onCreateEntry
                        )

                        ThemeMenuButton()
                        LanguageMenuButton()
                    }

                    HStack(spacing: 10) {
                        InfoChip(title: "\(entries.count)", subtitle: localization.entriesLabel)
                        InfoChip(title: localization.localStorageTitle, subtitle: localization.storageLabel)
                    }
                }

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            ForEach(entries) { entry in
                                Button {
                                    onSelectEntry(entry.id)
                                } label: {
                                    JournalRowView(
                                        entry: entry,
                                        isSelected: selection == entry.id,
                                        isDragging: draggedEntryID == entry.id,
                                        selectionAnimation: selectionAnimation
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(entry.id)
                                .opacity(draggedEntryID == entry.id ? 0 : 1)
                                .background(
                                    GeometryReader { geometry in
                                        Color.clear
                                            .preference(
                                                key: SidebarRowFramePreferenceKey.self,
                                                value: [
                                                    entry.id: geometry.frame(in: .named("sidebarList"))
                                                ]
                                            )
                                    }
                                )
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .opacity
                                    )
                                )
                            }
                        }
                        .padding(.bottom, 32)
                    }
                    .overlay(alignment: .topLeading) {
                        draggingOverlay
                    }
                    .overlay {
                        SidebarDragEventMonitor(
                            rowFrames: rowFrames,
                            onBegin: beginDrag,
                            onChange: updateDrag,
                            onEnd: endDrag
                        )
                        .allowsHitTesting(false)
                    }
                    .coordinateSpace(name: "sidebarList")
                    .onPreferenceChange(SidebarRowFramePreferenceKey.self) { newValue in
                        rowFrames = newValue
                    }
                    .onAppear {
                        guard let selection else {
                            return
                        }

                        proxy.scrollTo(selection, anchor: .top)
                    }
                    .onChange(of: selection) { _, newSelection in
                        guard let newSelection else {
                            return
                        }

                        withAnimation(.spring(duration: 0.42, bounce: 0.08)) {
                            proxy.scrollTo(newSelection, anchor: .center)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private var draggingOverlay: some View {
        if let draggedEntryID,
           let draggedEntry = entries.first(where: { $0.id == draggedEntryID }),
           let startFrame = dragStartFrame {
            JournalRowView(
                entry: draggedEntry,
                isSelected: selection == draggedEntryID,
                isDragging: true,
                selectionAnimation: selectionAnimation
            )
            .frame(width: startFrame.width, height: startFrame.height)
            .offset(x: startFrame.minX, y: startFrame.minY + dragOffset.height)
            .allowsHitTesting(false)
            .zIndex(20)
        }
    }

    private func beginDrag(_ entryID: UUID, at location: CGPoint) {
        guard let startFrame = rowFrames[entryID] else {
            return
        }

        lastDragDestinationIndex = entries.firstIndex(where: { $0.id == entryID })

        withAnimation(.easeOut(duration: 0.12)) {
            draggedEntryID = entryID
            dragStartFrame = startFrame
            dragOffset = .zero
        }

        reorderEntryIfNeeded(entryID: entryID, dragLocation: location)
    }

    private func updateDrag(_ entryID: UUID, translation: CGSize, location: CGPoint) {
        guard draggedEntryID == entryID else {
            return
        }

        dragOffset = translation
        reorderEntryIfNeeded(entryID: entryID, dragLocation: location)
    }

    private func endDrag(_ entryID: UUID) {
        guard draggedEntryID == entryID else {
            resetDragState()
            return
        }

        withAnimation(.easeOut(duration: 0.12)) {
            resetDragState()
        }
    }

    private func resetDragState() {
        draggedEntryID = nil
        dragOffset = .zero
        dragStartFrame = nil
        lastDragDestinationIndex = nil
    }

    private func reorderEntryIfNeeded(entryID: UUID, dragLocation: CGPoint) {
        guard let currentIndex = entries.firstIndex(where: { $0.id == entryID }) else {
            return
        }

        let destinationIndex = entries.reduce(into: 0) { count, candidate in
            guard candidate.id != entryID,
                  let frame = rowFrames[candidate.id],
                  frame.midY < dragLocation.y else {
                return
            }

            count += 1
        }

        guard destinationIndex != currentIndex,
              destinationIndex != lastDragDestinationIndex else {
            return
        }

        lastDragDestinationIndex = destinationIndex

        withAnimation(.easeInOut(duration: 0.14)) {
            onMoveEntry(entryID, destinationIndex)
        }
    }
}

private struct JournalRowView: View {
    @EnvironmentObject private var localization: InkLocalization
    @EnvironmentObject private var themeController: WriteThemeController

    let entry: JournalEntry
    let isSelected: Bool
    let isDragging: Bool
    let selectionAnimation: Namespace.ID

    var body: some View {
        ZStack {
            if isSelected {
                let selectionBackground = RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                themeController.palette.selectionStart,
                                themeController.palette.selectionEnd
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 18, y: 10)

                if isDragging {
                    selectionBackground
                } else {
                    selectionBackground
                        .matchedGeometryEffect(id: "sidebarSelection", in: selectionAnimation)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? themeController.palette.accent : themeController.palette.accentMuted)
                        .frame(width: 8, height: 28)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(localization.entryTitle(for: entry))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.9))
                            .lineLimit(1)

                        Text(localization.previewText(for: entry))
                            .font(.system(size: 13.5))
                            .foregroundStyle(isSelected ? Color.secondary : Color.secondary.opacity(0.85))
                            .lineLimit(2)
                    }
                }

                HStack {
                    Text(localization.sidebarDate(entry.createdAt))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    if entry.wordCount > 0 {
                        Text(localization.wordCountText(entry.wordCount))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if !isSelected {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(themeController.palette.surfaceFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(themeController.palette.surfaceStroke, lineWidth: 1)
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.black.opacity(isSelected ? 0.05 : 0.03), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .scaleEffect(isSelected ? 1 : 0.992)
    }
}

private struct SidebarRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct SidebarDragEventMonitor: NSViewRepresentable {
    let rowFrames: [UUID: CGRect]
    let onBegin: (UUID, CGPoint) -> Void
    let onChange: (UUID, CGSize, CGPoint) -> Void
    let onEnd: (UUID) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.hostView = view
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.hostView = nsView
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        var parent: SidebarDragEventMonitor
        weak var hostView: NSView?

        private var eventMonitor: Any?
        private var pendingEntryID: UUID?
        private var activeEntryID: UUID?
        private var mouseDownPoint: CGPoint?
        private var latestPoint: CGPoint?
        private var longPressWorkItem: DispatchWorkItem?

        init(parent: SidebarDragEventMonitor) {
            self.parent = parent
        }

        func installMonitor() {
            removeMonitor()

            eventMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
            ) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func removeMonitor() {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }

            eventMonitor = nil
            cancelPendingLongPress()
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard let hostView,
                  event.window === hostView.window,
                  let point = localPoint(for: event, in: hostView) else {
                return event
            }

            switch event.type {
            case .leftMouseDown:
                return handleMouseDown(event, at: point)

            case .leftMouseDragged:
                return handleMouseDragged(event, at: point)

            case .leftMouseUp:
                return handleMouseUp(event)

            default:
                return event
            }
        }

        private func handleMouseDown(_ event: NSEvent, at point: CGPoint) -> NSEvent? {
            cancelPendingLongPress()
            pendingEntryID = hitEntryID(at: point)
            activeEntryID = nil
            mouseDownPoint = point
            latestPoint = point

            guard let pendingEntryID else {
                return event
            }

            let workItem = DispatchWorkItem { [weak self] in
                guard let self,
                      self.pendingEntryID == pendingEntryID,
                      self.activeEntryID == nil,
                      let latestPoint = self.latestPoint else {
                    return
                }

                self.activeEntryID = pendingEntryID
                self.parent.onBegin(pendingEntryID, latestPoint)
            }

            longPressWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)

            return event
        }

        private func handleMouseDragged(_ event: NSEvent, at point: CGPoint) -> NSEvent? {
            latestPoint = point

            if let activeEntryID,
               let mouseDownPoint {
                parent.onChange(
                    activeEntryID,
                    CGSize(
                        width: point.x - mouseDownPoint.x,
                        height: point.y - mouseDownPoint.y
                    ),
                    point
                )

                return nil
            }

            if let mouseDownPoint,
               distance(from: mouseDownPoint, to: point) > 8 {
                cancelPendingLongPress()
            }

            return event
        }

        private func handleMouseUp(_ event: NSEvent) -> NSEvent? {
            cancelPendingLongPress()

            if let activeEntryID {
                parent.onEnd(activeEntryID)
                self.activeEntryID = nil
                pendingEntryID = nil
                mouseDownPoint = nil
                latestPoint = nil
                return nil
            }

            pendingEntryID = nil
            mouseDownPoint = nil
            latestPoint = nil
            return event
        }

        private func cancelPendingLongPress() {
            longPressWorkItem?.cancel()
            longPressWorkItem = nil
        }

        private func localPoint(for event: NSEvent, in hostView: NSView) -> CGPoint? {
            guard hostView.bounds.width > 0,
                  hostView.bounds.height > 0 else {
                return nil
            }

            let localPoint = hostView.convert(event.locationInWindow, from: nil)
            return CGPoint(
                x: localPoint.x,
                y: hostView.bounds.height - localPoint.y
            )
        }

        private func hitEntryID(at point: CGPoint) -> UUID? {
            parent.rowFrames
                .sorted { $0.value.minY < $1.value.minY }
                .first { _, frame in frame.contains(point) }?
                .key
        }

        private func distance(from start: CGPoint, to end: CGPoint) -> CGFloat {
            let width = end.x - start.x
            let height = end.y - start.y
            return sqrt(width * width + height * height)
        }
    }
}

private struct JournalEditorView: View {
    @EnvironmentObject private var store: JournalStore
    @EnvironmentObject private var localization: InkLocalization
    @EnvironmentObject private var themeController: WriteThemeController

    let entry: JournalEntry
    @Binding var title: String
    @Binding var bodyText: String
    let attachmentURLProvider: (JournalAttachment) -> URL?
    let attachmentAudioURLProvider: (JournalAttachment) -> URL?
    let isTitleFocusRequested: Bool
    let onFocusHandled: () -> Void
    let onCreateEntry: () -> Void
    let onSaveAs: () -> Void
    let onDelete: () -> Void
    let onCaptureScreenshot: () -> Void
    let onOpenCamera: () -> Void
    let onImportMedia: () -> Void
    let onRemoveAttachment: (JournalAttachment) -> Void
    let isCapturingScreenshot: Bool
    let isProcessingMedia: Bool
    let isPreparingExport: Bool

    @FocusState private var isTitleFocused: Bool
    @State private var isBodyFocused = false
    @State private var bodyDraft = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(localization.privateJournalHeader)
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.8)
                            .foregroundStyle(.secondary)

                        Text(localization.editorDate(entry.createdAt))
                            .font(.system(size: 28, weight: .medium, design: .serif))
                            .foregroundStyle(Color.primary.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 12) {
                            EditorStatusPill(title: localization.savedLocally)
                            EditorStatusPill(title: localization.wordCountText(entry.wordCount))
                        }
                    }

                    Spacer(minLength: 20)

                    VStack(alignment: .trailing, spacing: 10) {
                        HStack(spacing: 10) {
                            ActionIconButton(systemImage: "plus", helpText: localization.newJournal, action: onCreateEntry)
                            ActionIconButton(
                                systemImage: "square.and.arrow.down",
                                helpText: localization.saveAs,
                                action: onSaveAs,
                                isLoading: isPreparingExport
                            )
                            .disabled(isPreparingExport || isProcessingMedia)
                            ActionIconButton(systemImage: "trash", helpText: localization.deleteJournal, action: onDelete)
                        }

                        HStack(spacing: 10) {
                            ActionIconButton(
                                systemImage: "viewfinder.rectangular",
                                helpText: localization.screenshotMedia,
                                action: onCaptureScreenshot
                            )
                            .disabled(isCapturingScreenshot || isProcessingMedia)

                            ActionIconButton(
                                systemImage: "camera",
                                helpText: localization.cameraMedia,
                                action: onOpenCamera
                            )
                            .disabled(isProcessingMedia)

                            ActionIconButton(
                                systemImage: "tray.and.arrow.down",
                                helpText: localization.importMedia,
                                action: onImportMedia
                            )
                            .disabled(isProcessingMedia)
                        }
                    }
                }

                Divider()
                    .overlay(themeController.palette.divider)

                JournalTitleField(text: $title, isFocused: $isTitleFocused)

                JournalAttachmentSection(
                    attachments: entry.attachments,
                    urlProvider: attachmentURLProvider,
                    audioURLProvider: attachmentAudioURLProvider,
                    onRemove: onRemoveAttachment,
                    showsImportProgress: isProcessingMedia
                )

                PremiumTextEditor(
                    text: $bodyDraft,
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
        .onAppear {
            requestTitleFocusIfNeeded()
            bodyDraft = bodyText
            store.setBodyEditing(isBodyFocused, for: entry.id)
        }
        .onChange(of: isTitleFocusRequested) { _, _ in
            requestTitleFocusIfNeeded()
        }
        .onChange(of: bodyDraft) { _, newValue in
            guard bodyText != newValue else {
                return
            }

            bodyText = newValue
        }
        .onChange(of: bodyText) { _, newValue in
            guard !isBodyFocused, bodyDraft != newValue else {
                return
            }

            bodyDraft = newValue
        }
        .onChange(of: isBodyFocused) { _, isFocused in
            store.setBodyEditing(isFocused, for: entry.id)
        }
        .onDisappear {
            store.setBodyEditing(false, for: entry.id)
        }
    }

    private func requestTitleFocusIfNeeded() {
        guard isTitleFocusRequested else {
            return
        }

        DispatchQueue.main.async {
            isTitleFocused = true
            onFocusHandled()
        }
    }
}

private struct EmptyJournalView: View {
    @EnvironmentObject private var localization: InkLocalization
    @EnvironmentObject private var themeController: WriteThemeController

    let onCreateEntry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "book.pages")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text(localization.emptyStateTitle)
                .font(.system(size: 30, weight: .semibold, design: .serif))

            Text(localization.emptyStateMessage)
                .font(.system(size: 14.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Button(action: onCreateEntry) {
                Text(localization.newJournal)
                    .font(.system(size: 13.5, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(themeController.palette.accent)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(40)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(themeController.palette.elevatedSurfaceStroke, lineWidth: 1)
                )
        }
        .padding(40)
    }
}
struct ActionIconButton: View {
    @EnvironmentObject private var themeController: WriteThemeController

    let systemImage: String
    let helpText: String
    let action: () -> Void
    var isLoading = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(themeController.palette.buttonFill)

                Circle()
                    .strokeBorder(themeController.palette.buttonStroke, lineWidth: 1)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(themeController.palette.accent)
                        .scaleEffect(0.65)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
    }
}

private struct InfoChip: View {
    @EnvironmentObject private var themeController: WriteThemeController

    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))

            Text(subtitle)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(themeController.palette.pillFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(themeController.palette.pillStroke, lineWidth: 1)
        )
    }
}

struct EditorStatusPill: View {
    @EnvironmentObject private var themeController: WriteThemeController

    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(themeController.palette.pillFill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(themeController.palette.pillStroke, lineWidth: 1)
            )
    }
}

struct ExecutiveBackdrop: View {
    @EnvironmentObject private var themeController: WriteThemeController

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    themeController.palette.canvasStart,
                    themeController.palette.canvasEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [themeController.palette.orbSecondary, .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 280
                    )
                )
                .frame(width: 420, height: 420)
                .offset(x: 280, y: -240)
        }
        .ignoresSafeArea()
    }
}

private struct SidebarBackdrop: View {
    @EnvironmentObject private var themeController: WriteThemeController

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    themeController.palette.sidebarStart,
                    themeController.palette.sidebarEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.85))
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
        .environmentObject(JournalStore.previewStore)
        .environmentObject(InkLocalization())
        .environmentObject(WriteThemeController())
}
#endif

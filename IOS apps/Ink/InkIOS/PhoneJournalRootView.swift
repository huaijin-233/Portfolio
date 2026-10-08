//
//  PhoneJournalRootView.swift
//  Ink
//
//  Created by Codex on 3/14/26.
//

import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct PhoneJournalRootView: View {
    @EnvironmentObject private var store: JournalStore
    @EnvironmentObject private var localization: InkLocalization
    @EnvironmentObject private var themeController: WriteThemeController
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                PhoneExecutiveBackdrop()

                List {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ink5")
                                .font(.system(size: 36, weight: .semibold, design: .serif))
                                .foregroundStyle(Color.primary.opacity(0.9))

                            Text(localization.sidebarSubtitle)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 18)

                        HStack(spacing: 14) {
                            PhoneSummaryCard(
                                value: "\(store.entries.count)",
                                title: localization.entriesLabel
                            )

                            PhoneSummaryCard(
                                value: localization.localStorageTitle,
                                title: localization.syncedWithICloud
                            )
                        }
                    }
                    .listRowInsets(.init(top: 0, leading: 22, bottom: 12, trailing: 22))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    ForEach(store.entries) { entry in
                        Button {
                            path.append(entry.id)
                        } label: {
                            PhoneEntryCard(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                path.removeAll { $0 == entry.id }
                                store.deleteEntry(entry.id)
                            } label: {
                                Text(swipeDeleteTitle)
                            }
                        }
                        .listRowInsets(.init(top: 8, leading: 22, bottom: 8, trailing: 22))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }

                    Color.clear
                        .frame(height: 12)
                        .listRowInsets(.init())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .background(PhoneListBackgroundClearer())
            }
            .background(SystemContainerBackgroundClearer())
            .navigationTitle(localization.libraryWindowTitle)
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ThemeMenuButton()
                    LanguageMenuButton()
                    Button(action: createEntryAndOpen) {
                        PhoneToolbarIcon(systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localization.newJournal)
                }
            }
            .navigationDestination(for: UUID.self) { entryID in
                PhoneJournalEditorView(
                    entryID: entryID,
                    onCreateEntry: createEntryAndOpen
                )
            }
        }
    }

    private func createEntryAndOpen() {
        let entryID = store.createEntry()
        path.append(entryID)
    }

    private var swipeDeleteTitle: String {
        switch localization.language {
        case .english:
            return "Delete"
        case .simplifiedChinese:
            return "删除"
        }
    }
}

private struct PhoneListBackgroundClearer: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            var currentView = uiView.superview

            while let view = currentView {
                if let scrollView = view as? UIScrollView {
                    scrollView.backgroundColor = .clear
                }

                if let tableView = view as? UITableView {
                    tableView.backgroundColor = .clear
                }

                currentView = view.superview
            }
        }
    }
}

private struct PhoneEntryCard: View {
    @EnvironmentObject private var localization: InkLocalization
    @EnvironmentObject private var themeController: WriteThemeController

    let entry: JournalEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(themeController.palette.accentMuted)
                .frame(width: 8, height: 44)

            VStack(alignment: .leading, spacing: 10) {
                Text(localization.entryTitle(for: entry))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.88))
                    .lineLimit(1)

                Text(localization.previewText(for: entry))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(localization.sidebarDate(entry.createdAt))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.8))
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(themeController.palette.elevatedSurfaceFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(themeController.palette.elevatedSurfaceStroke, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 18, y: 10)
    }
}

private struct PhoneSummaryCard: View {
    @EnvironmentObject private var themeController: WriteThemeController

    let value: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.88))

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(themeController.palette.pillFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(themeController.palette.pillStroke, lineWidth: 1)
                )
        )
    }
}

private struct PhoneJournalEditorView: View {
    @EnvironmentObject private var store: JournalStore
    @EnvironmentObject private var localization: InkLocalization
    @EnvironmentObject private var themeController: WriteThemeController

    let entryID: UUID
    let onCreateEntry: () -> Void

    @FocusState private var isTitleFocused: Bool
    @FocusState private var isBodyFocused: Bool
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isImportingPhotos = false
    @State private var isImportingCapturedMedia = false
    @State private var isShowingCamera = false
    @State private var mediaAlert: PhoneMediaAlert?
    @State private var bodyDraft = ""

    private var entry: JournalEntry? {
        store.entry(for: entryID)
    }

    private var isBusy: Bool {
        isImportingPhotos || isImportingCapturedMedia
    }

    var body: some View {
        ZStack {
            PhoneExecutiveBackdrop()

            if let entry {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(localization.privateJournalHeader)
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(1.8)
                                .foregroundStyle(.secondary)

                            Text(localization.editorDate(entry.createdAt))
                                .font(.system(size: 30, weight: .medium, design: .serif))
                                .foregroundStyle(Color.primary.opacity(0.84))
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 10) {
                                PhoneStatusPill(title: localization.syncedWithICloud)
                                PhoneStatusPill(title: localization.wordCountText(entry.wordCount))
                            }
                        }

                        Divider()
                            .overlay(themeController.palette.divider)

                        JournalTitleField(
                            text: titleBinding(for: entry.id),
                            isFocused: $isTitleFocused
                        )

                        PhoneAttachmentStrip(
                            attachments: entry.attachments,
                            urlProvider: { attachment in
                                store.attachmentURL(for: attachment, entryID: entry.id)
                            },
                            audioURLProvider: { attachment in
                                store.audioAttachmentURL(for: attachment, entryID: entry.id)
                            },
                            onRemove: { attachment in
                                store.removeAttachment(attachment.id, from: entry.id)
                            }
                        )

                        PhonePlaceholderTextEditor(
                            text: $bodyDraft,
                            placeholder: localization.bodyPlaceholder,
                            isFocused: $isBodyFocused
                        )
                        .frame(minHeight: 320)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 34, style: .continuous)
                                    .strokeBorder(themeController.palette.elevatedSurfaceStroke, lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.08), radius: 24, y: 16)
                    )
                    .padding(.horizontal, 18)
                    .padding(.vertical, 22)
                }
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .background(
            PhoneKeyboardDismissGesture(isEnabled: isTitleFocused || isBodyFocused) {
                dismissKeyboard()
            }
        )
        .onAppear {
            bodyDraft = store.bodyText(for: entryID)
            store.setBodyEditing(isBodyFocused, for: entryID)
        }
        .onChange(of: bodyDraft) { _, newValue in
            let binding = bodyBinding(for: entryID)
            guard binding.wrappedValue != newValue else {
                return
            }

            binding.wrappedValue = newValue
        }
        .onChange(of: store.bodyText(for: entryID)) { _, newValue in
            guard !isBodyFocused, bodyDraft != newValue else {
                return
            }

            bodyDraft = newValue
        }
        .onChange(of: isBodyFocused) { _, isFocused in
            store.setBodyEditing(isFocused, for: entryID)
        }
        .onDisappear {
            store.setBodyEditing(false, for: entryID)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ThemeMenuButton()
                LanguageMenuButton()
                Button(action: onCreateEntry) {
                    PhoneToolbarIcon(systemImage: "plus")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localization.newJournal)

                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    PhoneToolbarIcon(systemImage: "photo.on.rectangle")
                }
                .disabled(isBusy)
                .accessibilityLabel(localization.importPhotos)

                Button {
                    Task {
                        await openCamera()
                    }
                } label: {
                    PhoneToolbarIcon(systemImage: "camera")
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .accessibilityLabel(localization.cameraMedia)
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            PhoneCameraCaptureSheet(
                onCapture: { result in
                    Task {
                        await handleCapturedMedia(result)
                    }
                },
                onCancel: {
                    isShowingCamera = false
                },
                onError: { _ in
                    isShowingCamera = false
                    presentMediaAlert(
                        title: localization.captureMediaErrorTitle,
                        message: localization.importMediaFailedMessage
                    )
                }
            )
        }
        .alert(item: $mediaAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(localization.dismissAction))
            )
        }
        .task(id: selectedPhotoItems) {
            await importSelectedPhotos()
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

    @MainActor
    private func importSelectedPhotos() async {
        guard !selectedPhotoItems.isEmpty, !isImportingPhotos else {
            return
        }

        isImportingPhotos = true
        defer {
            isImportingPhotos = false
            selectedPhotoItems = []
        }

        for item in selectedPhotoItems {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let jpegData = image.jpegData(compressionQuality: 0.92) else {
                    continue
                }

                try await store.importAttachment(
                    data: jpegData,
                    fileExtension: "jpg",
                    kind: .image,
                    originalFilename: "Photo Library.jpg",
                    to: entryID
                )
            } catch {
                presentMediaAlert(
                    title: localization.captureMediaErrorTitle,
                    message: localization.importMediaFailedMessage
                )
            }
        }
    }

    @MainActor
    private func openCamera() async {
        guard !isBusy else {
            return
        }

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presentMediaAlert(
                title: localization.cameraUnavailableTitle,
                message: localization.mobileCameraNotSupportedMessage
            )
            return
        }

        let cameraAuthorized = await requestCameraAccess()
        guard cameraAuthorized else {
            presentMediaAlert(
                title: localization.cameraPermissionTitle,
                message: localization.cameraPermissionMessage
            )
            return
        }

        await requestMicrophoneAccessIfNeeded()
        isShowingCamera = true
    }

    private func requestCameraAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func requestMicrophoneAccessIfNeeded() async {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else {
            return
        }

        _ = await AVCaptureDevice.requestAccess(for: .audio)
    }

    @MainActor
    private func handleCapturedMedia(_ result: PhoneCameraCaptureResult) async {
        guard !isImportingCapturedMedia else {
            return
        }

        isShowingCamera = false
        isImportingCapturedMedia = true
        defer {
            isImportingCapturedMedia = false
        }

        do {
            switch result {
            case .photo(let data):
                try await store.importAttachment(
                    data: data,
                    fileExtension: "jpg",
                    kind: .image,
                    originalFilename: "\(localization.takePhoto).jpg",
                    to: entryID
                )
            case .video(let url):
                try await store.importRecordedAttachment(
                    videoAt: url,
                    audioAt: nil,
                    to: entryID
                )
            }
        } catch {
            presentMediaAlert(
                title: localization.captureMediaErrorTitle,
                message: localization.importMediaFailedMessage
            )
        }
    }

    private func presentMediaAlert(title: String, message: String) {
        mediaAlert = PhoneMediaAlert(title: title, message: message)
    }

    private func dismissKeyboard() {
        isTitleFocused = false
        isBodyFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct PhonePlaceholderTextEditor: View {
    @EnvironmentObject private var themeController: WriteThemeController

    @Binding var text: String
    let placeholder: String
    let isFocused: FocusState<Bool>.Binding

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isFocused.wrappedValue {
                Text(placeholder)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.secondary.opacity(0.72))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                    .allowsHitTesting(false)
            }

            PhoneBodyTextView(
                text: $text,
                isFocused: isFocused
            )
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .focused(isFocused)
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(themeController.palette.surfaceFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(themeController.palette.surfaceStroke, lineWidth: 1)
                )
        )
    }
}

private struct PhoneBodyTextView: UIViewRepresentable {
    @Binding var text: String
    let isFocused: FocusState<Bool>.Binding

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        configure(textView)
        textView.delegate = context.coordinator
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        let isCurrentlyFocused = isFocused.wrappedValue || uiView.isFirstResponder

        if !isCurrentlyFocused, uiView.text != text {
            let selectedRange = uiView.selectedRange
            uiView.attributedText = attributedText(for: text, font: uiView.font)
            uiView.selectedRange = NSRange(
                location: min(selectedRange.location, uiView.text.utf16.count),
                length: 0
            )
        }

        configure(uiView)
        context.coordinator.enforceTextColor(for: uiView)

        if isFocused.wrappedValue, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused.wrappedValue, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    private func configure(_ textView: UITextView) {
        let textColor = UIColor.black
        textView.backgroundColor = .clear
        textView.textColor = textColor
        textView.font = .systemFont(ofSize: 17, weight: .regular)
        textView.tintColor = .systemBlue
        textView.overrideUserInterfaceStyle = .light
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.typingAttributes.merge(
            [
                .foregroundColor: textColor,
                .font: textView.font as Any
            ],
            uniquingKeysWith: { _, new in new }
        )
        if textView.textStorage.length > 0 {
            textView.textStorage.addAttributes(
                [
                    .foregroundColor: textColor,
                    .font: textView.font as Any
                ],
                range: NSRange(location: 0, length: textView.textStorage.length)
            )
        }
    }

    private func attributedText(for string: String, font: UIFont?) -> NSAttributedString {
        NSAttributedString(
            string: string,
            attributes: [
                .foregroundColor: UIColor.black,
                .font: font as Any
            ]
        )
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: PhoneBodyTextView

        init(_ parent: PhoneBodyTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            enforceTextColor(for: textView)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused.wrappedValue = true
            enforceTextColor(for: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused.wrappedValue = false
            enforceTextColor(for: textView)
        }

        func enforceTextColor(for textView: UITextView) {
            let textColor = UIColor.black
            textView.textColor = textColor
            textView.typingAttributes.merge(
                [
                    .foregroundColor: textColor,
                    .font: textView.font as Any
                ],
                uniquingKeysWith: { _, new in new }
            )
            if textView.textStorage.length > 0 {
                textView.textStorage.addAttributes(
                    [
                        .foregroundColor: textColor,
                        .font: textView.font as Any
                    ],
                    range: NSRange(location: 0, length: textView.textStorage.length)
                )
            }
        }
    }
}

private struct PhoneToolbarIcon: View {
    @EnvironmentObject private var themeController: WriteThemeController

    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.primary.opacity(0.84))
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(themeController.palette.buttonFill)
            )
            .overlay(
                Circle()
                    .strokeBorder(themeController.palette.buttonStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

private struct PhoneStatusPill: View {
    @EnvironmentObject private var themeController: WriteThemeController

    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(themeController.palette.pillFill)
            )
    }
}

private struct PhoneExecutiveBackdrop: View {
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
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    themeController.palette.orbSecondary,
                    .clear
                ],
                center: .topLeading,
                startRadius: 10,
                endRadius: 360
            )
            .ignoresSafeArea()
        }
    }
}

private struct PhoneMediaAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct PhoneKeyboardDismissGesture: UIViewRepresentable {
    let isEnabled: Bool
    let onTapOutside: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapOutside: onTapOutside)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTapOutside = onTapOutside
        context.coordinator.isEnabled = isEnabled
        DispatchQueue.main.async {
            context.coordinator.attachIfNeeded(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTapOutside: () -> Void
        var isEnabled = false
        private weak var gestureHost: UIView?
        private var gestureRecognizer: UITapGestureRecognizer?

        init(onTapOutside: @escaping () -> Void) {
            self.onTapOutside = onTapOutside
        }

        func attachIfNeeded(from view: UIView) {
            guard gestureRecognizer == nil, let host = view.window else {
                return
            }

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            tapGesture.cancelsTouchesInView = false
            tapGesture.delegate = self
            host.addGestureRecognizer(tapGesture)
            gestureRecognizer = tapGesture
            gestureHost = host
        }

        func detach() {
            if let gestureRecognizer, let gestureHost {
                gestureHost.removeGestureRecognizer(gestureRecognizer)
            }

            gestureRecognizer = nil
            gestureHost = nil
        }

        @objc
        private func handleTap() {
            guard isEnabled else {
                return
            }

            onTapOutside()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard isEnabled else {
                return false
            }

            var currentView: UIView? = touch.view
            while let view = currentView {
                if view is UIControl || view is UITextField || view is UITextView {
                    return false
                }

                if NSStringFromClass(type(of: view)).contains("AVTouchIgnoringView") {
                    return false
                }

                currentView = view.superview
            }

            return true
        }
    }
}

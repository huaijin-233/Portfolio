#if os(macOS)
//
//  PremiumTextEditor.swift
//  Ink
//
//  Created by Codex on 3/13/26.
//

import AppKit
import SwiftUI

struct PremiumTextEditor: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isFocused: Bool
    @Binding var isEditorFocused: Bool
    let theme: WriteThemePalette

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> PremiumEditorContainerView {
        let view = PremiumEditorContainerView()
        configure(view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: PremiumEditorContainerView, context: Context) {
        context.coordinator.update(parent: self)
        let isCurrentlyFocused = isEditorFocused || nsView.window?.firstResponder === nsView.textView

        if !isCurrentlyFocused, nsView.textView.string != text {
            let selectedRange = nsView.textView.selectedRange()
            nsView.textView.textStorage?.setAttributedString(
                attributedText(for: text, font: nsView.textView.font)
            )
            nsView.textView.setSelectedRange(
                NSRange(
                    location: min(selectedRange.location, nsView.textView.string.utf16.count),
                    length: 0
                )
            )
        }

        configure(nsView, coordinator: context.coordinator)

        nsView.isEditorFocused = isCurrentlyFocused
        nsView.updatePlaceholderVisibility()

        if isFocused, nsView.window?.firstResponder !== nsView.textView {
            nsView.window?.makeFirstResponder(nsView.textView)
        }
    }

    private func configure(_ view: PremiumEditorContainerView, coordinator: Coordinator) {
        view.placeholderField.stringValue = placeholder
        view.textView.delegate = coordinator
        view.textView.font = .systemFont(ofSize: 17, weight: .regular)
        applyTextAppearance(to: view.textView)
        view.isEditorFocused = isEditorFocused || view.window?.firstResponder === view.textView
        view.applyTheme(theme)
        view.updatePlaceholderVisibility()
    }

    private func applyTextAppearance(to textView: NSTextView) {
        let textColor = NSColor.black
        textView.textColor = textColor
        textView.insertionPointColor = NSColor(theme.accent)
        textView.typingAttributes.merge(
            [
                .foregroundColor: textColor,
                .font: textView.font as Any
            ],
            uniquingKeysWith: { _, new in new }
        )
        if let textStorage = textView.textStorage, textStorage.length > 0 {
            textStorage.addAttributes(
                [
                    .foregroundColor: textColor,
                    .font: textView.font as Any
                ],
                range: NSRange(location: 0, length: textStorage.length)
            )
        }
    }

    private func attributedText(for string: String, font: NSFont?) -> NSAttributedString {
        NSAttributedString(
            string: string,
            attributes: [
                .foregroundColor: NSColor.black,
                .font: font as Any
            ]
        )
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private var parent: PremiumTextEditor

        init(_ parent: PremiumTextEditor) {
            self.parent = parent
        }

        func update(parent: PremiumTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            parent.text = textView.string
            parent.applyTextAppearance(to: textView)

            containerView(for: textView)?.updatePlaceholderVisibility()
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            parent.isEditorFocused = true
            parent.applyTextAppearance(to: textView)
            containerView(for: textView)?.isEditorFocused = true
            containerView(for: textView)?.updatePlaceholderVisibility()
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            parent.isEditorFocused = false
            parent.applyTextAppearance(to: textView)
            containerView(for: textView)?.isEditorFocused = false
            containerView(for: textView)?.updatePlaceholderVisibility()
        }

        private func containerView(for textView: NSTextView) -> PremiumEditorContainerView? {
            textView.enclosingScrollView?.superview as? PremiumEditorContainerView
        }
    }
}
final class PremiumEditorContainerView: NSView {
    let scrollView = NSScrollView()
    let textView = NSTextView()
    let placeholderField = NSTextField(labelWithString: "")
    var isEditorFocused = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updatePlaceholderVisibility() {
        let isEmpty = textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        placeholderField.isHidden = !isEmpty || isEditorFocused
    }

    func applyTheme(_ theme: WriteThemePalette) {
        layer?.backgroundColor = NSColor(theme.surfaceFill).cgColor
        layer?.borderColor = NSColor(theme.surfaceStroke).cgColor
    }

    private func configure() {
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.borderWidth = 1

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 14, height: 16)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        placeholderField.font = .systemFont(ofSize: 17, weight: .regular)
        placeholderField.textColor = NSColor.secondaryLabelColor.withAlphaComponent(0.7)
        placeholderField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)
        addSubview(placeholderField)
        scrollView.documentView = textView

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            placeholderField.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            placeholderField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            placeholderField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14)
        ])
    }
}
#endif

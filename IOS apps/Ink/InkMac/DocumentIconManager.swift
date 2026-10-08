#if os(macOS)
//
//  DocumentIconManager.swift
//  Ink
//
//  Created by Codex on 3/13/26.
//

import AppKit

enum DocumentIconManager {
    static func applyInkIcon(to url: URL) {
        guard let iconImage = iconImage() else {
            return
        }

        NSWorkspace.shared.setIcon(iconImage, forFile: url.path, options: [])
    }

    private static func iconImage(bundle: Bundle = .main) -> NSImage? {
        if let iconURL = bundle.url(forResource: "InkJournalDocument", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            return iconImage
        }

        return NSImage(named: "InkPaper")
    }
}
#endif

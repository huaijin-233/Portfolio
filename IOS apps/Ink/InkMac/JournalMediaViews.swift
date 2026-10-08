#if os(macOS)
//
//  JournalMediaViews.swift
//  Ink
//
//  Created by Codex on 3/13/26.
//

@preconcurrency import AVFoundation
import AVKit
import AppKit
import SwiftUI

struct JournalAttachmentSection: View {
    @EnvironmentObject private var localization: InkLocalization
    @EnvironmentObject private var themeController: WriteThemeController

    let attachments: [JournalAttachment]
    let urlProvider: (JournalAttachment) -> URL?
    let audioURLProvider: (JournalAttachment) -> URL?
    let onRemove: (JournalAttachment) -> Void
    let showsImportProgress: Bool

    var body: some View {
        if !attachments.isEmpty || showsImportProgress {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(localization.mediaSectionTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.4)

                    Spacer()

                    if !attachments.isEmpty {
                        EditorStatusPill(title: localization.attachmentCountText(attachments.count))
                    }
                }

                LazyVStack(spacing: 18) {
                    if showsImportProgress {
                        PendingMediaImportCard()
                    }

                    ForEach(attachments) { attachment in
                        JournalAttachmentCard(
                            attachment: attachment,
                            url: urlProvider(attachment),
                            audioURL: audioURLProvider(attachment),
                            onRemove: { onRemove(attachment) }
                        )
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
private struct PendingMediaImportCard: View {
    @EnvironmentObject private var localization: InkLocalization
    @EnvironmentObject private var themeController: WriteThemeController

    var body: some View {
        HStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.primary.opacity(0.82))
                .scaleEffect(0.9)

            VStack(alignment: .leading, spacing: 6) {
                Text(localization.importingMediaTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.84))

                Text(localization.importingMediaMessage)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(themeController.palette.surfaceFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(themeController.palette.surfaceStroke, lineWidth: 1)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.black.opacity(0.04), lineWidth: 1)
        )
    }
}

private struct JournalAttachmentCard: View {
    @EnvironmentObject private var localization: InkLocalization
    @EnvironmentObject private var themeController: WriteThemeController

    let attachment: JournalAttachment
    let url: URL?
    let audioURL: URL?
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                Group {
                    switch attachment.kind {
                    case .image:
                        AttachmentImageView(url: url)
                    case .video:
                        AttachmentVideoView(url: url, audioURL: audioURL)
                    }
                }

                HStack(spacing: 10) {
                    Text(localization.attachmentKindLabel(attachment.kind))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(themeController.palette.pillFill)
                        )

                    Text(attachment.displayName)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(themeController.palette.surfaceFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(themeController.palette.surfaceStroke, lineWidth: 1)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.04), lineWidth: 1)
            )

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.75))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(themeController.palette.buttonFill)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(themeController.palette.buttonStroke, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help(localization.removeAttachment)
            .padding(12)
        }
    }
}

private struct AttachmentImageView: View {
    let url: URL?
    @State private var image: NSImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                AttachmentLoadingView(symbolName: "photo")
            } else {
                AttachmentUnavailableView(symbolName: "photo")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .task(id: url) {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        image = nil

        guard let url else {
            isLoading = false
            return
        }

        isLoading = true

        do {
            let data = try await Task.detached(priority: .utility) {
                try Data(contentsOf: url, options: [.mappedIfSafe])
            }.value

            guard !Task.isCancelled else {
                return
            }

            image = NSImage(data: data)
        } catch {
            image = nil
        }

        isLoading = false
    }
}

private struct AttachmentVideoView: View {
    @EnvironmentObject private var themeController: WriteThemeController
    let url: URL?
    let audioURL: URL?

    var body: some View {
        Group {
            if let url {
                InlineVideoPlayerView(url: url, audioURL: audioURL)
            } else {
                AttachmentUnavailableView(symbolName: "video")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 260)
        .background(themeController.palette.surfaceFill)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct InlineVideoPlayerView: View {
    let url: URL
    let audioURL: URL?
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                EmbeddedVideoPlayerView(player: player)
            } else {
                AttachmentLoadingView(symbolName: "video")
            }
        }
        .task(id: playbackKey) {
            let playerItem = await buildPlayerItem()
            guard !Task.isCancelled else {
                return
            }

            let player = AVPlayer(playerItem: playerItem)
            player.isMuted = false
            player.volume = 1
            player.allowsExternalPlayback = false
            self.player = player
        }
        .onDisappear {
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
        }
    }

    private var playbackKey: String {
        let audioComponent = audioURL?.absoluteString ?? "no-audio"
        return "\(url.absoluteString)|\(audioComponent)"
    }

    private func buildPlayerItem() async -> AVPlayerItem {
        guard let audioURL else {
            return AVPlayerItem(url: url)
        }

        do {
            return try await VideoAudioCompositionBuilder.playerItem(videoURL: url, audioURL: audioURL)
        } catch {
            return AVPlayerItem(url: url)
        }
    }
}

private struct EmbeddedVideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .inline
        view.videoGravity = .resizeAspect
        player.isMuted = false
        player.volume = 1
        view.player = player
        view.showsFrameSteppingButtons = false
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        player.isMuted = false
        player.volume = 1
        if nsView.player !== player {
            nsView.player = player
        }
    }

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: ()) {
        nsView.player = nil
    }
}

private enum VideoAudioCompositionBuilder {
    // Manual sync compensation for the separate microphone file.
    // The sidecar audio consistently starts with ~0.8s of low-level pre-roll
    // before speech arrives, so we trim that lead-in during playback.
    private static let manualAudioLeadTrim = CMTime(seconds: 0.82, preferredTimescale: 600)

    static func playerItem(videoURL: URL, audioURL: URL) async throws -> AVPlayerItem {
        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)

        let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)

        guard let sourceVideoTrack = videoTracks.first,
              let sourceAudioTrack = audioTracks.first else {
            return AVPlayerItem(url: videoURL)
        }

        let videoDuration = try await videoAsset.load(.duration)
        let audioDuration = try await audioAsset.load(.duration)
        let composition = AVMutableComposition()

        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            return AVPlayerItem(url: videoURL)
        }

        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: videoDuration),
            of: sourceVideoTrack,
            at: .zero
        )

        let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
        compositionVideoTrack.preferredTransform = preferredTransform

        if let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) {
            let audioStartTime: CMTime
            if CMTimeCompare(audioDuration, manualAudioLeadTrim) == 1 {
                audioStartTime = manualAudioLeadTrim
            } else {
                audioStartTime = .zero
            }

            let availableAudioDuration = CMTimeSubtract(audioDuration, audioStartTime)
            let effectiveDuration = CMTimeMinimum(videoDuration, availableAudioDuration)
            try compositionAudioTrack.insertTimeRange(
                CMTimeRange(start: audioStartTime, duration: effectiveDuration),
                of: sourceAudioTrack,
                at: .zero
            )
        }

        return AVPlayerItem(asset: composition)
    }
}

private struct AttachmentUnavailableView: View {
    let symbolName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.08))

            Image(systemName: symbolName)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct AttachmentLoadingView: View {
    let symbolName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.06))

            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.primary.opacity(0.78))

                Image(systemName: symbolName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif

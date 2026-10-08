//
//  PhoneMediaAttachmentViews.swift
//  Ink
//
//  Created by Codex on 3/14/26.
//

import AVFoundation
import AVKit
import SwiftUI
import UIKit

struct PhoneAttachmentStrip: View {
    @EnvironmentObject private var localization: InkLocalization

    let attachments: [JournalAttachment]
    let urlProvider: (JournalAttachment) -> URL?
    let audioURLProvider: (JournalAttachment) -> URL?
    let onRemove: (JournalAttachment) -> Void

    var body: some View {
        if !attachments.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(attachments) { attachment in
                            PhoneAttachmentCard(
                                attachment: attachment,
                                url: urlProvider(attachment),
                                audioURL: audioURLProvider(attachment),
                                removeLabel: localization.removeAttachment,
                                onRemove: { onRemove(attachment) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct PhoneAttachmentCard: View {
    @EnvironmentObject private var localization: InkLocalization
    @EnvironmentObject private var themeController: WriteThemeController

    let attachment: JournalAttachment
    let url: URL?
    let audioURL: URL?
    let removeLabel: String
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                Group {
                    switch attachment.kind {
                    case .image:
                        PhoneImageAttachmentCard(url: url)
                    case .video:
                        PhoneVideoAttachmentCard(url: url, audioURL: audioURL)
                    }
                }

                HStack(spacing: 8) {
                    Text(attachment.kind == .image ? localization.imageLabel : localization.videoLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(themeController.palette.pillFill)
                        )

                    Text(attachment.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: attachment.kind == .image ? 152 : 276, alignment: .leading)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.72))
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
            .padding(8)
            .accessibilityLabel(removeLabel)
        }
    }
}

private struct PhoneImageAttachmentCard: View {
    @EnvironmentObject private var themeController: WriteThemeController
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(themeController.palette.surfaceFill)
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
        }
        .frame(width: 152, height: 152)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .task(id: url) {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        guard let url else {
            image = nil
            return
        }

        do {
            let data = try await Task.detached(priority: .utility) {
                try Data(contentsOf: url, options: [.mappedIfSafe])
            }.value

            image = UIImage(data: data)
        } catch {
            image = nil
        }
    }
}

private struct PhoneVideoAttachmentCard: View {
    @EnvironmentObject private var themeController: WriteThemeController
    let url: URL?
    let audioURL: URL?

    var body: some View {
        Group {
            if let url {
                PhoneInlineVideoPlayer(url: url, audioURL: audioURL)
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(themeController.palette.surfaceFill)
                    .overlay(
                        Image(systemName: "video")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .frame(width: 276, height: 188)
        .background(themeController.palette.surfaceFill)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct PhoneInlineVideoPlayer: View {
    let url: URL
    let audioURL: URL?

    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.black.opacity(0.84))

                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white.opacity(0.88))
                }
            }
        }
        .task(id: playbackKey) {
            let item = await buildPlayerItem()
            guard !Task.isCancelled else {
                return
            }

            let player = AVPlayer(playerItem: item)
            player.isMuted = false
            player.volume = 1
            self.player = player
        }
        .onDisappear {
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
        }
    }

    private var playbackKey: String {
        "\(url.absoluteString)|\(audioURL?.absoluteString ?? "no-audio")"
    }

    private func buildPlayerItem() async -> AVPlayerItem {
        guard let audioURL else {
            return AVPlayerItem(url: url)
        }

        do {
            return try await PhoneVideoAudioCompositionBuilder.playerItem(videoURL: url, audioURL: audioURL)
        } catch {
            return AVPlayerItem(url: url)
        }
    }
}

private enum PhoneVideoAudioCompositionBuilder {
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

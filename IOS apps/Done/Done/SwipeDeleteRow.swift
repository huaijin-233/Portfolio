//
//  SwipeDeleteRow.swift
//  Done
//
//  Created by Codex on 3/12/26.
//

import SwiftUI
import UIKit

struct SwipeDeleteRow<Content: View>: View {
    @EnvironmentObject private var localization: LocalizationStore
    @EnvironmentObject private var themeStore: ThemeStore

    let rowID: String
    @Binding var openedRowID: String?
    let isEnabled: Bool
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    @GestureState private var dragOffset: CGFloat = 0
    @State private var settledOffset: CGFloat = 0
    @State private var didHapticOpen = false
    @State private var openFeedback = UIImpactFeedbackGenerator(style: .light)
    @State private var deleteFeedback = UIImpactFeedbackGenerator(style: .medium)

    private let actionWidth: CGFloat = 88
    private let settleAnimation = Animation.interactiveSpring(response: 0.22, dampingFraction: 0.92, blendDuration: 0.06)

    private var palette: ThemePalette {
        themeStore.theme.palette
    }

    private var isOpen: Bool {
        openedRowID == rowID
    }

    private var currentOffset: CGFloat {
        guard isEnabled else { return 0 }
        return max(-actionWidth, min(0, settledOffset + dragOffset))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if isEnabled {
                actionRevealView
            }

            ZStack {
                content
                    .allowsHitTesting(!isOpen)

                if isOpen {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(settleAnimation) {
                                closeSwipe()
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .offset(x: currentOffset)
            .simultaneousGesture(swipeGesture)
            .animation(settleAnimation, value: settledOffset)
            .onChange(of: openedRowID) { _, newValue in
                guard newValue != rowID, settledOffset != 0 else { return }
                withAnimation(settleAnimation) {
                    closeSwipe()
                }
            }
            .onChange(of: currentOffset) { _, newValue in
                guard isEnabled else { return }
                if newValue <= -(actionWidth * 0.82), didHapticOpen == false {
                    openFeedback.impactOccurred()
                    openFeedback.prepare()
                    didHapticOpen = true
                } else if newValue > -(actionWidth * 0.45) {
                    didHapticOpen = false
                }
            }
        }
        .contentShape(Rectangle())
        .onAppear {
            openFeedback.prepare()
            deleteFeedback.prepare()
        }
    }

    private var actionRevealView: some View {
        let revealWidth = max(0, -currentOffset)
        let progress = min(1, revealWidth / actionWidth)

        return HStack {
            Spacer(minLength: 0)

            Button(role: .destructive) {
                withAnimation(settleAnimation) {
                    closeSwipe()
                }
                deleteFeedback.impactOccurred()
                deleteFeedback.prepare()
                onDelete()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                        .font(.headline)

                    Text(localization.text(.delete))
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(width: actionWidth)
                .frame(maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [palette.overdue, palette.overdue.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: palette.overdue.opacity(progress * 0.20), radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)
            .offset(x: max(0, actionWidth - revealWidth))
            .opacity(progress == 0 ? 0 : progress)
            .scaleEffect(x: 0.92 + (progress * 0.08), y: 0.96 + (progress * 0.04), anchor: .trailing)
            .frame(width: revealWidth, alignment: .trailing)
            .clipped()
            .allowsHitTesting(progress > 0.95)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .updating($dragOffset) { value, state, _ in
                guard isEnabled else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                if !isOpen && value.translation.width < 0 {
                    openedRowID = rowID
                }

                let proposed = settledOffset + value.translation.width
                state = min(0, max(-actionWidth, proposed)) - settledOffset
            }
            .onEnded { value in
                guard isEnabled else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                let projectedOffset = settledOffset + value.predictedEndTranslation.width
                let shouldOpen = projectedOffset < (-actionWidth * 0.52)

                withAnimation(settleAnimation) {
                    if shouldOpen {
                        settledOffset = -actionWidth
                        openedRowID = rowID
                    } else {
                        closeSwipe()
                    }
                }
            }
    }

    private func closeSwipe() {
        settledOffset = 0
        if openedRowID == rowID {
            openedRowID = nil
        }
        didHapticOpen = false
    }
}

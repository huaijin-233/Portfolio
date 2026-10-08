import SwiftUI
import Translation

struct AppLaunchView: View {
    @AppStorage("hasPreparedEnglishChineseTranslationResources")
    private var hasPreparedTranslationResources = false

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                TranslationPreparationView(isPrepared: $hasPreparedTranslationResources)
            } else {
                RootTabView()
            }
        }
    }
}

@available(iOS 18.0, *)
private struct TranslationPreparationView: View {
    private enum PreparationPhase: Equatable {
        case waitingForTaskStart
        case preparing

        var message: String {
            switch self {
            case .waitingForTaskStart:
                return "正在启动系统翻译资源下载。"
            case .preparing:
                return "准备好以后，你扫描出来的英文单词就能自动补中文备注。"
            }
        }
    }

    @Binding var isPrepared: Bool
    @State private var preparationRequestID = UUID()
    @State private var phase: PreparationPhase = .waitingForTaskStart
    @State private var hasRequestedPreparation = false
    @State private var hasEnteredApp = false

    private let sourceLanguage = Locale.Language(identifier: "en-US")
    private let targetLanguage = Locale.Language(identifier: "zh-Hans")
    private let taskStartRetrySeconds: Double = 5
    private let launchDeadlineSeconds: Double = 60
    private let retryDelaySeconds: Double = 2

    var body: some View {
        ZStack {
            RootTabView()
                .opacity((isPrepared || hasEnteredApp) ? 1 : 0)
                .allowsHitTesting(isPrepared || hasEnteredApp)

            if !isPrepared && !hasEnteredApp {
                launchCard
                    .transition(.opacity)
            }
        }
        .overlay {
            if !isPrepared {
                TranslationPreparationTaskView(
                    requestID: preparationRequestID,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage
                ) { session in
                    await prepareTranslationResources(using: session)
                }
            }
        }
        .task(id: preparationRequestID) {
            await monitorTaskStart(for: preparationRequestID)
        }
        .task {
            await enforceLaunchDeadline()
        }
        .animation(.easeInOut(duration: 0.25), value: hasEnteredApp)
        .animation(.easeInOut(duration: 0.25), value: isPrepared)
    }

    private var launchCard: some View {
        ZStack {
            PlayfulBackground()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(AppColors.lemon.opacity(0.92))
                            .frame(width: 86, height: 86)

                        Image(systemName: "character.book.closed")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(AppColors.primaryText)
                    }

                    VStack(spacing: 10) {
                        Text("下载相关资源中，只会下载一次")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(AppColors.primaryText)
                            .multilineTextAlignment(.center)

                        Text(phase.message)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    ProgressView()
                        .tint(AppColors.primary)
                        .scaleEffect(1.15)
                        .padding(.top, 4)
                }
                .padding(28)
                .frame(maxWidth: 360)
                .background(AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
                .shadow(color: AppStyle.cardShadow, radius: 18, y: 10)

                Spacer()
            }
            .padding(.horizontal, AppStyle.contentPadding)
        }
    }

    private func prepareTranslationResources(using session: TranslationSession) async {
        let requestID = await MainActor.run { () -> UUID? in
            guard !hasRequestedPreparation else { return nil }

            hasRequestedPreparation = true
            phase = .preparing
            return preparationRequestID
        }

        guard let requestID else { return }

        do {
            try await session.prepareTranslation()

            await MainActor.run {
                guard preparationRequestID == requestID else { return }
                isPrepared = true
                hasEnteredApp = true
            }
        } catch {
            guard !Task.isCancelled else { return }

            try? await Task.sleep(for: .seconds(retryDelaySeconds))

            await MainActor.run {
                guard preparationRequestID == requestID else { return }
                hasRequestedPreparation = false
                phase = .waitingForTaskStart
                preparationRequestID = UUID()
            }
        }
    }

    private func monitorTaskStart(for requestID: UUID) async {
        try? await Task.sleep(for: .seconds(taskStartRetrySeconds))
        guard !Task.isCancelled else { return }

        await MainActor.run {
            guard preparationRequestID == requestID else { return }
            guard !isPrepared else { return }
            guard !hasRequestedPreparation else { return }

            preparationRequestID = UUID()
        }
    }

    private func enforceLaunchDeadline() async {
        try? await Task.sleep(for: .seconds(launchDeadlineSeconds))
        guard !Task.isCancelled else { return }

        await MainActor.run {
            guard !isPrepared else { return }
            hasEnteredApp = true
        }
    }
}

@available(iOS 18.0, *)
private struct TranslationPreparationTaskView: View {
    let requestID: UUID
    let sourceLanguage: Locale.Language
    let targetLanguage: Locale.Language
    let prepareResources: (TranslationSession) async -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .id(requestID)
            .translationTask(
                TranslationSession.Configuration(
                    source: sourceLanguage,
                    target: targetLanguage
                )
            ) { session in
                await prepareResources(session)
            }
    }
}

#Preview {
    AppLaunchView()
        .environmentObject(WordStore())
}

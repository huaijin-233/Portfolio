import SwiftUI
import Translation

struct WordSheetPreviewView: View {
    @EnvironmentObject private var wordStore: WordStore

    let bookID: UUID
    let template: WordSheetTemplate

    @State private var currentPageIndex = 0
    @State private var exportAlert: ExportAlert?
    @State private var isExporting = false
    @State private var isRecoveringMeanings = false
    @State private var hasAttemptedMeaningRecovery = false
    @State private var meaningRecoveryRequestID: UUID?
    @State private var selectedFontStyle: WordSheetFontStyle = .default

    private let translationService = WordTranslationService()

    private var displayBook: WordBook? {
        wordStore.book(with: bookID)
    }

    private var pages: [WordSheetPage] {
        guard let displayBook else { return [] }
        return WordSheetPaginator.paginate(book: displayBook, template: template)
    }

    private var currentPage: WordSheetPage? {
        guard pages.indices.contains(currentPageIndex) else {
            return nil
        }

        return pages[currentPageIndex]
    }

    private var missingMeaningWords: [String] {
        guard let displayBook else { return [] }

        return displayBook.words
            .filter { $0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(\.word)
    }

    var body: some View {
        ZStack {
            PlayfulBackground()

            GeometryReader { proxy in
                if displayBook != nil, let currentPage {
                    VStack(spacing: 12) {
                        previewCard(for: currentPage)
                            .frame(maxHeight: proxy.size.height * 0.78)
                        pageControlCard(for: currentPage)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                } else {
                    EmptyStateView(
                        title: "这个单词本不见了",
                        message: "它可能已经被删除了，请返回【做表格】重新选择。"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, AppStyle.contentPadding)
                }
            }
        }
        .navigationTitle("预览表格")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.backgroundTop.opacity(0.98), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if displayBook != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("选择字体", selection: $selectedFontStyle) {
                            ForEach(WordSheetFontStyle.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                    } label: {
                        Image(systemName: "textformat")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppColors.primaryText)
                    }
                }
            }
        }
        .onAppear {
            clampPageIndex()

            guard #available(iOS 18.0, *),
                  !hasAttemptedMeaningRecovery,
                  !missingMeaningWords.isEmpty
            else { return }

            hasAttemptedMeaningRecovery = true
            isRecoveringMeanings = true
            meaningRecoveryRequestID = UUID()
        }
        .onChange(of: pages.count) { _, _ in
            clampPageIndex()
        }
        .alert(exportAlert?.title ?? "导出结果", isPresented: exportAlertPresented) {
            Button("知道了", role: .cancel) {
                exportAlert = nil
            }
        } message: {
            Text(exportAlert?.message ?? "")
        }
        .overlay {
            if #available(iOS 18.0, *), let meaningRecoveryRequestID {
                MissingMeaningRecoveryTaskView(requestID: meaningRecoveryRequestID) { session in
                    await recoverMissingMeanings(using: session)
                }
            }
        }
    }
}

private extension WordSheetPreviewView {
    func clampPageIndex() {
        guard !pages.isEmpty else {
            currentPageIndex = 0
            return
        }

        currentPageIndex = min(currentPageIndex, pages.count - 1)
        currentPageIndex = max(currentPageIndex, 0)
    }
}

private extension WordSheetPreviewView {
    struct ExportAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var exportAlertPresented: Binding<Bool> {
        Binding(
            get: { exportAlert != nil },
            set: { newValue in
                if !newValue {
                    exportAlert = nil
                }
            }
        )
    }

    @available(iOS 18.0, *)
    func recoverMissingMeanings(using session: TranslationSession) async {
        let words = missingMeaningWords
        guard !words.isEmpty else {
            await MainActor.run {
                isRecoveringMeanings = false
                meaningRecoveryRequestID = nil
            }
            return
        }

        let translatedNotes = await translationService.translate(words: words, using: session)

        await MainActor.run {
            guard let displayBook else {
                isRecoveringMeanings = false
                meaningRecoveryRequestID = nil
                return
            }

            _ = wordStore.fillMissingNotes(bookID: displayBook.id, translatedNotes: translatedNotes)
            isRecoveringMeanings = false
            meaningRecoveryRequestID = nil
        }
    }

    func exportCurrentPage() async {
        guard !isExporting, let currentPage else { return }
        isExporting = true
        defer { isExporting = false }

        guard let exportImage = WordSheetExportRenderer.render(
            page: currentPage,
            fontStyle: selectedFontStyle
        ) else {
            exportAlert = ExportAlert(
                title: "暂时无法导出这一页",
                message: "这一页生成失败了，请返回上一页后再试一次。"
            )
            return
        }

        do {
            try await WordSheetPhotoLibrarySaver.save(image: exportImage)
            exportAlert = ExportAlert(
                title: "已保存到相册",
                message: "当前这一页已经成功保存到系统相册。"
            )
        } catch let error as WordSheetPhotoLibrarySaver.SaveError {
            exportAlert = ExportAlert(
                title: error.title,
                message: error.message
            )
        } catch {
            exportAlert = ExportAlert(
                title: "保存失败",
                message: "请稍后再试一次。"
            )
        }
    }

    func previewCard(for currentPage: WordSheetPage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayBook?.title ?? "单词本")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.primaryText)

                    Text(template.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryText)

                    Text(
                        isRecoveringMeanings
                        ? "正在补全这一页的意思…"
                        : "当前导出的是第 \(currentPage.pageNumber) 页"
                    )
                        .font(.caption2)
                        .foregroundStyle(AppColors.secondaryText)
                }

                Spacer()
            }

            WordSheetCanvasView(page: currentPage, fontStyle: selectedFontStyle)
                .aspectRatio(
                    currentPage.template.canvasSize.width / currentPage.template.canvasSize.height,
                    contentMode: .fit
                )
        }
        .padding(12)
        .background(AppColors.elevatedCard)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous)
                .stroke(AppColors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 14, y: 8)
    }

    func pageControlCard(for currentPage: WordSheetPage) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    guard currentPageIndex > 0 else { return }
                    withAnimation(AppStyle.quickSpring) {
                        currentPageIndex -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 40, height: 40)
                        .background(AppColors.background)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(currentPageIndex == 0)
                .opacity(currentPageIndex == 0 ? 0.35 : 1)

                VStack(spacing: 4) {
                    Text("第 \(currentPage.pageNumber) 页")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.primaryText)

                    Text("共 \(currentPage.totalPageCount) 页")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
                .frame(maxWidth: .infinity)

                Button {
                    guard currentPageIndex < pages.count - 1 else { return }
                    withAnimation(AppStyle.quickSpring) {
                        currentPageIndex += 1
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 40, height: 40)
                        .background(AppColors.background)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(currentPageIndex == pages.count - 1)
                .opacity(currentPageIndex == pages.count - 1 ? 0.35 : 1)
            }
            Button {
                Task {
                    await exportCurrentPage()
                }
            } label: {
                Label(
                    isRecoveringMeanings ? "正在补全意思…" : (isExporting ? "保存中…" : "导出到相册"),
                    systemImage: "square.and.arrow.up"
                )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.primary)
            .disabled(currentPage.entries.isEmpty || isExporting || isRecoveringMeanings)
        }
        .padding(14)
        .background(AppColors.elevatedCard)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous)
                .stroke(AppColors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 12, y: 8)
    }
}

@available(iOS 18.0, *)
private struct MissingMeaningRecoveryTaskView: View {
    let requestID: UUID
    let performRecovery: (TranslationSession) async -> Void

    private let sourceLanguage = Locale.Language(identifier: "en-US")
    private let targetLanguage = Locale.Language(identifier: "zh-Hans")

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
                await performRecovery(session)
            }
    }
}

#Preview {
    NavigationStack {
        WordSheetPreviewView(bookID: WordBook.mock.id, template: .blue)
            .environmentObject(WordStore())
    }
}

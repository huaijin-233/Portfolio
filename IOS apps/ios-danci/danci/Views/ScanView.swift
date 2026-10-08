import PhotosUI
import SwiftUI
import Translation

struct ScanView: View {
    @EnvironmentObject private var wordStore: WordStore
    @StateObject private var viewModel = ScanViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var contentVisible = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                PlayfulBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        ScanButton(
                            isScanning: viewModel.isProcessing,
                            modeTitle: viewModel.selectedMode.title,
                            tint: viewModel.selectedMode == .marked ? AppColors.peach : AppColors.primary
                        ) {
                            viewModel.startScan()
                        }
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 24)

                        ModeToggleCard(
                            selectedMode: $viewModel.selectedMode,
                            detailedTranslationEnabled: $viewModel.detailedTranslationEnabled
                        )
                            .opacity(contentVisible ? 1 : 0)
                            .offset(y: contentVisible ? 0 : 28)
                        modeGuideCard
                            .opacity(contentVisible ? 1 : 0)
                            .offset(y: contentVisible ? 0 : 32)

                        if viewModel.isProcessing {
                            processingCard
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        if let summary = viewModel.lastSummary {
                            ScanSummaryCard(summary: summary)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        recentBooksCard
                            .opacity(contentVisible ? 1 : 0)
                            .offset(y: contentVisible ? 0 : 34)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .padding(.horizontal, AppStyle.contentPadding)
                    .padding(.top, AppStyle.pageTopSpacing + 6)
                    .padding(.bottom, AppStyle.floatingTabBarClearance)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !contentVisible else { return }
            withAnimation(AppStyle.softSpring.delay(0.04)) {
                contentVisible = true
            }
        }
        .sheet(isPresented: $viewModel.isPresentingSourceDialog) {
            sourcePickerSheet
                .presentationDetents([.height(viewModel.canUseDocumentScanner ? 250 : 210)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
        .sheet(isPresented: $viewModel.isPresentingDocumentScanner) {
            DocumentScannerView(
                onCancel: {
                    viewModel.handleDocumentCancellation()
                },
                onComplete: { images in
                    viewModel.processScannedImages(images, wordStore: wordStore)
                },
                onError: { error in
                    viewModel.handleDocumentError(error)
                }
            )
            .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $viewModel.isPresentingPhotoPicker,
            selection: $selectedPhoto,
            matching: .images
        )
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }

            Task {
                if let image = await PhotoImportService.loadImage(from: newValue) {
                    viewModel.handleImportedPhoto(image, wordStore: wordStore)
                } else {
                    viewModel.presentPhotoImportFailure()
                }

                selectedPhoto = nil
            }
        }
        .alert(item: $viewModel.alertState) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("知道了"))
            )
        }
        .overlay {
            if let translationRequestID = viewModel.translationRequestID {
                if #available(iOS 18.0, *) {
                    PendingTranslationTaskView(requestID: translationRequestID) { session in
                        await viewModel.performPendingTranslation(using: session, wordStore: wordStore)
                    }
                } else {
                    Color.clear
                        .frame(width: 0, height: 0)
                }
            }
        }
        .fullScreenCover(item: $viewModel.markedSelectionDraft) { draft in
            MarkedSelectionEditorView(
                images: draft.images,
                onCancel: {
                    viewModel.cancelMarkedSelection()
                },
                onComplete: { selections, totalPageCount in
                    viewModel.completeMarkedSelection(
                        selections,
                        source: draft.source,
                        totalPageCount: totalPageCount,
                        wordStore: wordStore
                    )
                }
            )
        }
        .animation(AppStyle.softSpring, value: viewModel.isProcessing)
        .animation(AppStyle.softSpring, value: viewModel.lastSummary?.createdBookTitle)
    }
}

#Preview {
    NavigationStack {
        ScanView()
            .environmentObject(WordStore())
    }
}

@available(iOS 18.0, *)
private struct PendingTranslationTaskView: View {
    let requestID: UUID
    let performTranslation: (TranslationSession) async -> Void

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
                await performTranslation(session)
            }
    }
}

private extension ScanView {
    var sourcePickerSheet: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("选择扫描方式")
                    .font(.headline)
                    .foregroundStyle(AppColors.primaryText)

                Text("只识别英文单词")
                    .font(.footnote)
                    .foregroundStyle(AppColors.secondaryText)
            }
            .padding(.top, 4)

            VStack(spacing: 12) {
                if viewModel.canUseDocumentScanner {
                    Button {
                        viewModel.isPresentingSourceDialog = false
                        viewModel.startDocumentScan()
                    } label: {
                        Text("文稿扫描")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.plain)
                    .background(AppColors.background)
                    .clipShape(Capsule())
                }

                Button {
                    viewModel.isPresentingSourceDialog = false
                    viewModel.startPhotoImport()
                } label: {
                    Text("从照片导入")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.plain)
                .background(AppColors.background)
                .clipShape(Capsule())
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .presentationBackground(AppColors.elevatedCard)
    }

    var modeGuideCard: some View {
        HStack(spacing: 14) {
            Image(systemName: viewModel.selectedMode == .marked ? "scribble.variable" : "text.viewfinder")
                .font(.title3.weight(.semibold))
                .foregroundStyle(viewModel.selectedMode == .marked ? AppColors.mint : AppColors.primary)
                .frame(width: 42, height: 42)
                .background((viewModel.selectedMode == .marked ? AppColors.mint : AppColors.primary).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(viewModel.selectedMode.helperTitle)
                    .font(.headline)
                    .foregroundStyle(AppColors.primaryText)

                Text(viewModel.selectedMode == .marked ? "先选位置，再扫描。" : "直接识别整页英文。")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.elevatedCard)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous)
                .stroke(AppColors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 12, y: 8)
    }

    var processingCard: some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(AppColors.primary)
                .scaleEffect(1.08)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.selectedMode == .marked ? "正在识别选中的单词" : "正在识别英文单词")
                    .font(.headline)
                    .foregroundStyle(AppColors.primaryText)

                Text(viewModel.selectedMode == .marked ? "只整理刚刚选中的位置。" : "识别后会自动整理进书架。")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
            }

            Spacer()
        }
        .padding(18)
        .background(AppColors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
    }

    var recentBooksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("最近书架")
                    .font(.headline)
                    .foregroundStyle(AppColors.primaryText)
                Spacer()
                Text("\(wordStore.books.count) 本")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryText)
            }

            if wordStore.books.isEmpty {
                Text("还没有单词本。")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(wordStore.books.prefix(4))) { book in
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(AppColors.primary.opacity(0.14))
                                    .frame(width: 42, height: 48)

                                Image(systemName: "book.closed.fill")
                                    .foregroundStyle(AppColors.primary)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(book.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppColors.primaryText)
                                        .lineLimit(2)

                                    Spacer()

                                    Text("\(book.wordCount) 词")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppColors.secondaryText)
                                }

                                if book.previewWords.isEmpty {
                                    Text("还没有单词")
                                        .font(.footnote)
                                        .foregroundStyle(AppColors.secondaryText)
                                } else {
                                    Text(book.previewWords.joined(separator: " · "))
                                        .font(.footnote)
                                        .foregroundStyle(AppColors.secondaryText)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .padding(14)
                        .background(AppColors.background)
                        .clipShape(RoundedRectangle(cornerRadius: AppStyle.smallCornerRadius, style: .continuous))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.elevatedCard)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous)
                .stroke(AppColors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
        .shadow(color: AppStyle.cardShadow, radius: 12, y: 8)
    }

}

//
//  smallapp1.swift
//  newhuaixin
//
//  Created by Huaijin233 on 3/7/26.
//

import SwiftUI
import Photos
import UIKit

struct SmallApp1View: View {
    enum AvatarStyle: String, CaseIterable, Identifiable {
        case anime = "动漫"
        case photo = "照片"
        case oilPainting = "油画"
        case dreamy = "唯美"
        case sketch = "素描"
        case abstract = "抽象"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .anime:
                return LT("Anime", "アニメ", "動漫")
            case .photo:
                return LT("Photo", "写真", "照片")
            case .oilPainting:
                return LT("Oil", "油絵", "油畫")
            case .dreamy:
                return LT("Dreamy", "唯美", "唯美")
            case .sketch:
                return LT("Sketch", "素描", "素描")
            case .abstract:
                return LT("Abstract", "抽象", "抽象")
            }
        }
    }

    @State private var userPrompt = ""
    @State private var selectedStyle: AvatarStyle = .anime
    @State private var isGenerating = false
    @State private var remainingCount = 5
    @State private var resultImageURL: String?
    @State private var errorMessage = ""
    @State private var toastMessage = ""
    @State private var showToast = false

    private let quotaManager = AvatarWorkshopQuotaManager.shared
    private let service = ReplicateAvatarService()

    private let bgGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 1.0, green: 0.98, blue: 0.99),
            Color(red: 1.0, green: 0.95, blue: 0.97)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private let accent = Color(red: 1.0, green: 0.45, blue: 0.65)
    private let accentSoft = Color(red: 1.0, green: 0.94, blue: 0.96)

    var body: some View {
        ZStack {
            bgGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    formSection

                    if let urlString = resultImageURL, let url = URL(string: urlString) {
                        resultSection(url: url)
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.9))
                            .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 24)
                }
            }

            if showToast {
                toastView
            }
        }
        .navigationTitle(LT("Avatar Studio", "アバタースタジオ", "頭像工坊"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshRemainingCount()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(accent)
                Text(LT("Avatar Studio", "アバタースタジオ", "頭像工坊"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.black.opacity(0.85))
                Spacer()
                Text("\(LT("Left", "残り", "剩餘")) \(remainingCount)/5")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(accentSoft)
                    .cornerRadius(12)
            }

            Text(LT("Up to 5 generations per day. Resets to 5 the next day.", "1日に5回まで生成できます。翌日に5回へリセットされます。", "每天最多生成 5 次，次日自動刷新為 5 次。"))
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LT("Choose a Style", "スタイルを選択", "選擇風格"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.black.opacity(0.8))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(AvatarStyle.allCases) { style in
                    styleButton(style)
                }
            }

            Text(LT("Describe what you want to generate", "生成したい内容を入力", "描述你想生成的頭像"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.black.opacity(0.8))

            TextEditor(text: $userPrompt)
                .frame(height: 110)
                .padding(8)
                .background(accentSoft.opacity(0.45))
                .cornerRadius(14)

            Button(action: generateAvatar) {
                generateButtonContent
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(generateButtonBackground)
            .foregroundColor(.white)
            .cornerRadius(14)
            .shadow(color: accent.opacity(0.24), radius: 8, x: 0, y: 4)
            .disabled(isGenerateDisabled)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 20)
    }

    private func resultSection(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LT("Result", "生成結果", "生成結果"))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black.opacity(0.85))

            AsyncImage(url: url) { phase in
                resultImageView(for: phase)
            }

            Button(action: saveImageToPhotos) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text(LT("Save Image", "画像を保存", "保存圖片"))
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
            }
            .background(primaryButtonGradient)
            .foregroundColor(.white)
            .cornerRadius(14)
            .shadow(color: accent.opacity(0.22), radius: 8, x: 0, y: 4)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 20)
    }

    private var toastView: some View {
        VStack {
            Spacer()
                Text(toastMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.76))
                .cornerRadius(24)
                .padding(.bottom, 48)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func styleButton(_ style: AvatarStyle) -> some View {
        let isSelected = selectedStyle == style

        return Button(action: {
            selectedStyle = style
        }) {
            Text(style.title)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(isSelected ? AnyShapeStyle(accent) : AnyShapeStyle(accentSoft.opacity(0.8)))
                .foregroundColor(isSelected ? .white : .black.opacity(0.75))
                .cornerRadius(12)
        }
    }

    @ViewBuilder
    private func resultImageView(for phase: AsyncImagePhase) -> some View {
        switch phase {
        case .empty:
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color.white)
                ProgressView()
            }
            .frame(height: 300)
        case .success(let image):
            image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(16)
        case .failure:
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color.white)
                Text(LT("Failed to load image", "画像の読み込みに失敗しました", "圖片載入失敗"))
                    .foregroundColor(.gray)
            }
            .frame(height: 220)
        @unknown default:
            EmptyView()
        }
    }

    private var isGenerateDisabled: Bool {
        userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating || remainingCount <= 0
    }

    private var primaryButtonGradient: LinearGradient {
        LinearGradient(
            colors: [accent, Color(red: 0.97, green: 0.60, blue: 0.75)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    @ViewBuilder
    private var generateButtonBackground: some View {
        if isGenerateDisabled {
            Color.gray.opacity(0.35)
        } else {
            primaryButtonGradient
        }
    }

    private var generateButtonContent: some View {
        HStack {
            if isGenerating {
                ProgressView()
                    .tint(.white)
            } else {
                Image(systemName: "sparkles")
                Text(LT("Generate", "生成する", "生成頭像"))
                    .fontWeight(.bold)
            }
        }
    }

    private func refreshRemainingCount() {
        remainingCount = quotaManager.refreshAndGetRemaining(for: Auth.auth().currentUser?.uid)
    }

    private func generateAvatar() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        let input = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        userPrompt = input

        errorMessage = ""
        resultImageURL = nil

        guard quotaManager.refreshAndGetRemaining(for: Auth.auth().currentUser?.uid) > 0 else {
            refreshRemainingCount()
            errorMessage = LT("Today's limit is used up. Please try again tomorrow.", "本日の回数を使い切りました。明日もう一度お試しください。", "今日次數已用完，請明天再試。")
            return
        }

        isGenerating = true
        Task {
            do {
                let translatedInput = try await translateToEnglish(input)
                let prompt = translatedInput + ", " + selectedStylePromptText()
                let imageURL = try await service.generateAvatar(prompt: prompt)
                await MainActor.run {
                    _ = quotaManager.consumeOneIfAvailable(for: Auth.auth().currentUser?.uid)
                    refreshRemainingCount()
                    resultImageURL = imageURL
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = LT("Generation failed", "生成に失敗しました", "生成失敗") + "：\(error.localizedDescription)"
                }
            }
        }
    }

    private func selectedStylePromptText() -> String {
        switch selectedStyle {
        case .anime:
            return "anime style, one picture, clean line art, vivid colors, high detail"
        case .photo:
            return "realistic photo style, one picture, natural lighting, realistic texture, sharp details"
        case .oilPainting:
            return "oil painting style, one picture, rich brush strokes, canvas texture, classic art look"
        case .dreamy:
            return "dreamy watercolor style, one picture, premium pink color palette, soft light, elegant and delicate atmosphere"
        case .sketch:
            return "clean sketch style, one picture, minimal lines, monochrome pencil drawing feel"
        case .abstract:
            return "Pablo Picasso abstract cubist style, one picture, geometric fragmentation, expressive abstract composition"
        }
    }

    private func translateToEnglish(_ text: String) async throws -> String {
        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")
        components?.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: "en"),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]

        guard let url = components?.url else {
            throw NSError(domain: "Translate", code: 1, userInfo: [NSLocalizedDescriptionKey: LT("Invalid translation URL", "翻訳URLが無効です", "翻譯地址無效")])
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "Translate", code: 2, userInfo: [NSLocalizedDescriptionKey: LT("Translation request failed", "翻訳リクエストに失敗しました", "翻譯請求失敗")])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [Any],
              let translationBlocks = json.first as? [Any] else {
            throw NSError(domain: "Translate", code: 3, userInfo: [NSLocalizedDescriptionKey: LT("Failed to parse translation result", "翻訳結果の解析に失敗しました", "翻譯結果解析失敗")])
        }

        var translated = ""
        for block in translationBlocks {
            if let arr = block as? [Any], let piece = arr.first as? String {
                translated += piece
            }
        }

        let cleaned = translated.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? text : cleaned
    }

    private func saveImageToPhotos() {
        guard let urlString = resultImageURL, let url = URL(string: urlString) else { return }

        let saveAction = {
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    let saved = try await savePhotoDataToLibrary(data: data, sourceURL: url)
                    await MainActor.run {
                        showToast(saved ? LT("Saved to Photos", "写真に保存しました", "已保存到相冊") : LT("Save failed", "保存に失敗しました", "保存失敗"))
                    }
                } catch {
                    await MainActor.run { showToast(LT("Save failed", "保存に失敗しました", "保存失敗")) }
                }
            }
        }

        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            saveAction()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        saveAction()
                    } else {
                        showToast(LT("Please allow photo access", "写真へのアクセスを許可してください", "請允許訪問相冊"))
                    }
                }
            }
        default:
            showToast(LT("Please allow photo access", "写真へのアクセスを許可してください", "請允許訪問相冊"))
        }
    }

    private func savePhotoDataToLibrary(data: Data, sourceURL: URL) async throws -> Bool {
        let ext = preferredImageExtension(from: sourceURL)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)

        try data.write(to: tempURL, options: .atomic)

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = false
                request.addResource(with: .photo, fileURL: tempURL, options: options)
            }) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    private func preferredImageExtension(from url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "heic", "webp"].contains(ext) {
            return ext
        }
        return "jpg"
    }

    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                showToast = false
            }
        }
    }
}

final class AvatarWorkshopQuotaManager {
    static let shared = AvatarWorkshopQuotaManager()

    private let limit = 5
    private let defaults = UserDefaults.standard
    private let dayKeyPrefix = "avatar_workshop_day_"
    private let countKeyPrefix = "avatar_workshop_count_"

    private init() {}

    func refreshAndGetRemaining(for uid: String?) -> Int {
        let userKey = uid ?? "guest"
        let dayKey = dayKeyPrefix + userKey
        let countKey = countKeyPrefix + userKey
        let today = todayKey()

        let savedDay = defaults.string(forKey: dayKey)
        if savedDay != today {
            defaults.set(today, forKey: dayKey)
            defaults.set(limit, forKey: countKey)
            return limit
        }

        if defaults.object(forKey: countKey) == nil {
            defaults.set(limit, forKey: countKey)
            return limit
        }

        let current = defaults.integer(forKey: countKey)
        return max(0, min(limit, current))
    }

    func consumeOneIfAvailable(for uid: String?) -> Bool {
        let remaining = refreshAndGetRemaining(for: uid)
        guard remaining > 0 else { return false }

        let userKey = uid ?? "guest"
        let countKey = countKeyPrefix + userKey
        defaults.set(remaining - 1, forKey: countKey)
        return true
    }

    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

final class ReplicateAvatarService {
    private let endpoint = "https://api.302.ai/v1/images/generations"
    private let token = "sk-SqztARuLPfz2Hu7rGgLlZWrgdUpf6rN7f48RFOsgG2qlUelg"

    func generateAvatar(prompt: String) async throws -> String {
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "302AIImage", code: 1, userInfo: [NSLocalizedDescriptionKey: LT("Invalid endpoint", "無効なエンドポイントです", "Endpoint 無效")])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "dall-e-2-i2i",
            "prompt": prompt,
            "size": "1024x1024",
            "response_format": "url"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response: response, data: data)

        let generated = try JSONDecoder().decode(GeneratedImageResponse.self, from: data)
        guard let first = generated.data.first else {
            throw NSError(domain: "302AIImage", code: 2, userInfo: [NSLocalizedDescriptionKey: LT("No image was returned", "画像が返されませんでした", "未返回圖片")])
        }

        if let url = first.url, !url.isEmpty {
            return url
        }

        if let b64 = first.b64JSON,
           let data = Data(base64Encoded: b64) {
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("png")
            try data.write(to: fileURL, options: .atomic)
            return fileURL.absoluteString
        }

        throw NSError(domain: "302AIImage", code: 3, userInfo: [NSLocalizedDescriptionKey: LT("No usable image data was returned", "使用できる画像データが返されませんでした", "未返回可用圖片數據")])
    }

    private func validateHTTP(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "302AIImage", code: 0, userInfo: [NSLocalizedDescriptionKey: LT("Invalid network response", "無効なネットワーク応答です", "網路響應無效")])
        }

        guard (200...299).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8) ?? LT("Request failed", "リクエストに失敗しました", "請求失敗")
            throw NSError(domain: "302AIImage", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: raw])
        }
    }
}

struct GeneratedImageResponse: Decodable {
    struct ImageData: Decodable {
        let url: String?
        let b64JSON: String?

        enum CodingKeys: String, CodingKey {
            case url
            case b64JSON = "b64_json"
        }
    }

    let data: [ImageData]
}

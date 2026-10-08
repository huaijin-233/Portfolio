import Foundation

struct ScanSummary: Equatable {
    let mode: ScanMode
    let pageCount: Int
    let detectedCount: Int
    let addedCount: Int
    let createdBookTitle: String?
    let previewWords: [String]

    var title: String {
        if let createdBookTitle, addedCount > 0 {
            return "已创建单词本《\(createdBookTitle)》"
        }

        if detectedCount > 0 {
            return "这次没有生成新的单词本"
        }

        return "这次没有识别到英文单词"
    }

    var subtitle: String {
        var parts: [String] = []
        parts.append("\(mode.title)")
        parts.append("\(pageCount) 页")
        parts.append("识别到 \(detectedCount) 个英文词")

        if addedCount > 0 {
            parts.append("收进 \(addedCount) 个单词")
        }

        return parts.joined(separator: " · ")
    }
}

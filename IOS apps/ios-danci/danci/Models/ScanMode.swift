import Foundation

enum ScanMode: String, CaseIterable, Identifiable, Hashable, Codable {
    case normal
    case marked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal:
            return "普通模式"
        case .marked:
            return "标记模式"
        }
    }

    var subtitle: String {
        switch self {
        case .normal:
            return "扫描页面中的所有英文单词"
        case .marked:
            return "拍照后手动选择，只识别你选中的英文单词"
        }
    }

    var iconName: String {
        switch self {
        case .normal:
            return "text.viewfinder"
        case .marked:
            return "highlighter"
        }
    }

    var helperTitle: String {
        switch self {
        case .normal:
            return "适合整页英文内容"
        case .marked:
            return "适合只挑重点词慢慢收"
        }
    }

    var source: WordSource {
        switch self {
        case .normal:
            return .normalScan
        case .marked:
            return .markedScan
        }
    }
}

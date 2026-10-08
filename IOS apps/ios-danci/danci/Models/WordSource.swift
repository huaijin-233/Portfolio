import Foundation

enum WordSource: String, Codable, CaseIterable, Hashable {
    case manual
    case normalScan
    case markedScan

    var title: String {
        switch self {
        case .manual:
            return "手动新增"
        case .normalScan:
            return "普通扫描"
        case .markedScan:
            return "标记扫描"
        }
    }

    var subtitle: String {
        switch self {
        case .manual:
            return "由你手动创建或补充"
        case .normalScan:
            return "来自普通模式扫描"
        case .markedScan:
            return "来自标记模式扫描"
        }
    }

    var iconName: String {
        switch self {
        case .manual:
            return "square.and.pencil"
        case .normalScan:
            return "text.viewfinder"
        case .markedScan:
            return "highlighter"
        }
    }
}

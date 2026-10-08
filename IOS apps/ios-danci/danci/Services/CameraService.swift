import AVFoundation
import Foundation
import UIKit

struct CameraService {
    var isRunningInSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    var supportsDocumentScanner: Bool {
        guard !isRunningInSimulator else {
            return false
        }

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return false
        }

        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    var fallbackMessage: String {
        if isRunningInSimulator {
            return "模拟器里的系统文稿扫描不稳定，已自动切换为从照片导入。真机上再使用相机扫描会更可靠。"
        }

        return "当前设备不支持系统文稿扫描，已经为你保留了从照片导入的方式。"
    }
}

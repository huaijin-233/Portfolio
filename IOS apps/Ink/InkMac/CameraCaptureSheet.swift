#if os(macOS)
//
//  CameraCaptureSheet.swift
//  Ink
//
//  Created by Codex on 3/13/26.

@preconcurrency import AVFoundation
import AppKit
import Combine
import CoreAudio
import SwiftUI

nonisolated struct CapturedVideoRecording: Sendable, Equatable {
    let videoURL: URL
    let audioURL: URL?
}

struct CameraCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: InkLocalization
    @StateObject private var controller = CameraCaptureController()
    @State private var showsPreview = true
    @State private var isClosingSheet = false

    let onPhotoCaptured: (Data) -> Void
    let onVideoCaptured: (CapturedVideoRecording) -> Void

    private var recordingIssueBinding: Binding<CameraCaptureController.RecordingIssue?> {
        Binding(
            get: { controller.recordingIssue },
            set: { controller.recordingIssue = $0 }
        )
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.black.opacity(0.9))

            switch controller.state {
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)

            case .ready:
                cameraContent

            case .permissionDenied:
                permissionView(
                    title: localization.cameraPermissionTitle,
                    message: localization.cameraPermissionMessage,
                    showSettings: true
                )

            case .unavailable:
                permissionView(
                    title: localization.cameraUnavailableTitle,
                    message: localization.cameraUnavailableMessage,
                    showSettings: false
                )
            }
        }
        .frame(width: 760, height: 560)
        .task {
            showsPreview = true
            await controller.prepare()
        }
        .onDisappear {
            Task { @MainActor in
                showsPreview = false
                await controller.prepareForDismissal()
            }
        }
        .onChange(of: controller.capturedPhotoData) { _, newValue in
            guard let newValue else {
                return
            }

            controller.capturedPhotoData = nil
            dismissSafely {
                onPhotoCaptured(newValue)
            }
        }
        .onChange(of: controller.capturedVideoRecording) { _, newValue in
            guard let newValue else {
                return
            }

            controller.capturedVideoRecording = nil
            dismissSafely {
                onVideoCaptured(newValue)
            }
        }
        .interactiveDismissDisabled(
            isClosingSheet || controller.isRecording || controller.isFinalizingRecording
        )
        .alert(item: recordingIssueBinding) { issue in
            switch issue {
            case .microphonePermissionDenied:
                return Alert(
                    title: Text(localization.microphonePermissionTitle),
                    message: Text(localization.microphonePermissionMessage),
                    primaryButton: .default(Text(localization.openSettingsAction)) {
                        openPrivacySettings(for: .microphone)
                    },
                    secondaryButton: .cancel(Text(localization.closeAction))
                )

            case .microphoneUnavailable:
                return Alert(
                    title: Text(localization.microphoneUnavailableTitle),
                    message: Text(localization.microphoneUnavailableMessage),
                    dismissButton: .default(Text(localization.closeAction))
                )

            case .recordingFailed:
                return Alert(
                    title: Text(localization.recordingFailedTitle),
                    message: Text(localization.recordingFailedMessage),
                    dismissButton: .default(Text(localization.closeAction))
                )
            }
        }
    }

    private var cameraContent: some View {
        ZStack(alignment: .bottom) {
            Group {
                if showsPreview {
                    CameraPreviewView(session: controller.previewSession)
                } else {
                    Color.black.opacity(0.94)
                }
            }
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay {
                    if controller.isFinalizingRecording {
                        finalizingOverlay
                    }
                }
                .overlay(alignment: .topLeading) {
                    Text(localization.cameraLiveLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.84))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.35))
                        )
                        .padding(18)
                }

            HStack(spacing: 18) {
                secondaryButton(title: localization.closeAction) {
                    dismissSafely()
                }
                .disabled(
                    isClosingSheet || controller.isRecording || controller.isFinalizingRecording
                )

                Button(action: controller.capturePhoto) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 72, height: 72)

                            Circle()
                                .strokeBorder(Color.black.opacity(0.12), lineWidth: 2)
                                .frame(width: 58, height: 58)
                        }

                        Text(localization.takePhoto)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                }
                .buttonStyle(.plain)
                .disabled(
                    isClosingSheet || controller.isRecording || controller.isFinalizingRecording
                )

                Button(action: controller.toggleRecording) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.14))
                                .frame(width: 72, height: 72)

                            if controller.isFinalizingRecording {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .scaleEffect(0.9)
                            } else if controller.isRecording {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.red)
                                    .frame(width: 24, height: 24)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 30, height: 30)
                            }
                        }

                        Text(recordingButtonTitle)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isClosingSheet || controller.isFinalizingRecording)
            }
            .padding(.bottom, 26)
        }
    }

    private var recordingButtonTitle: String {
        if controller.isFinalizingRecording {
            return localization.finalizingVideoTitle
        }

        return controller.isRecording ? localization.stopRecording : localization.recordVideo
    }

    private var finalizingOverlay: some View {
        ZStack {
            Color.black.opacity(0.46)

            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)

                Text(localization.finalizingVideoTitle)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)

                Text(localization.finalizingVideoMessage)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.36))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private func permissionView(title: String, message: String, showSettings: Bool) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.fill")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.white.opacity(0.84))

            Text(title)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 14.5, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: 420)

            HStack(spacing: 12) {
                secondaryButton(title: localization.closeAction) {
                    dismissSafely()
                }

                if showSettings {
                    secondaryButton(title: localization.openSettingsAction, action: openCameraSettings)
                }
            }
        }
        .padding(36)
    }

    private func secondaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.14))
                )
        }
        .buttonStyle(.plain)
    }

    private func dismissSafely(after action: @escaping @MainActor () -> Void = {}) {
        guard !isClosingSheet else {
            return
        }

        isClosingSheet = true

        Task { @MainActor in
            showsPreview = false
            await controller.prepareForDismissal()
            action()
            dismiss()
            isClosingSheet = false
        }
    }

    private func openCameraSettings() {
        openPrivacySettings(for: .camera)
    }

    private func openPrivacySettings(for pane: PrivacyPane) {
        let urlString: String

        switch pane {
        case .camera:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        }

        guard let settingsURL = URL(string: urlString) else {
            return
        }

        NSWorkspace.shared.open(settingsURL)
    }
}

@MainActor
final class CameraCaptureController: NSObject, ObservableObject {
    enum State {
        case loading
        case ready
        case permissionDenied
        case unavailable
    }

    enum AudioCaptureState {
        case unknown
        case ready
        case permissionDenied
        case unavailable
    }

    enum RecordingIssue: String, Identifiable {
        case microphonePermissionDenied
        case microphoneUnavailable
        case recordingFailed

        var id: String { rawValue }
    }

    @Published var state: State = .loading
    @Published var audioCaptureState: AudioCaptureState = .unknown
    @Published var isRecording = false
    @Published var isFinalizingRecording = false
    @Published var capturedPhotoData: Data?
    @Published var capturedVideoRecording: CapturedVideoRecording?
    @Published var recordingIssue: RecordingIssue?
    @Published private(set) var previewSession: AVCaptureSession?

    nonisolated let session = AVCaptureSession()

    nonisolated private let sessionQueue = DispatchQueue(label: "com.zhuhuaijin.ink.camera")
    nonisolated private let photoOutput = AVCapturePhotoOutput()
    nonisolated private let movieOutput = AVCaptureMovieFileOutput()
    nonisolated(unsafe) private var isConfigured = false
    private var didPrepareForDismissal = false
    private var isPreparingSession = false
    private var isTearingDownSession = false
    private var hasPreparedSession = false
    private var isStartingRecording = false
    private var audioRecorder: AVAudioRecorder?
    private var activeAudioRecordingURL: URL?
    private var microphoneInputGuard: MicrophoneInputGuard?

    func prepare() async {
        guard !isPreparingSession, !isTearingDownSession else {
            return
        }

        if hasPreparedSession, previewSession != nil, state == .ready {
            return
        }

        isPreparingSession = true
        state = .loading
        recordingIssue = nil
        isFinalizingRecording = false
        didPrepareForDismissal = false
        hasPreparedSession = false
        previewSession = nil
        audioCaptureState = .unknown

        defer {
            isPreparingSession = false
        }

        let videoGranted = await requestAccess(for: .video)
        guard videoGranted else {
            hasPreparedSession = false
            state = .permissionDenied
            return
        }

        do {
            try await configureSessionAndStartRunning()
            previewSession = session
            hasPreparedSession = true
            state = .ready
        } catch {
            hasPreparedSession = false
            state = .unavailable
        }
    }

    nonisolated func capturePhoto() {
        sessionQueue.async {
            guard self.isConfigured else {
                return
            }

            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func toggleRecording() {
        if isRecording {
            isFinalizingRecording = true
            audioRecorder?.stop()
            audioRecorder = nil

            sessionQueue.async {
                guard self.movieOutput.isRecording else {
                    DispatchQueue.main.async {
                        self.isFinalizingRecording = false
                    }
                    return
                }

                self.movieOutput.stopRecording()
            }
            return
        }

        guard !isStartingRecording, !isPreparingSession, !isTearingDownSession else {
            return
        }

        isStartingRecording = true

        Task { @MainActor in
            defer {
                isStartingRecording = false
            }

            let audioState = await ensureAudioCaptureReady()
            guard audioState == .ready else {
                recordingIssue = audioState == .permissionDenied
                    ? .microphonePermissionDenied
                    : .microphoneUnavailable
                return
            }

            let videoOutputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Write-Camera-\(UUID().uuidString)")
                .appendingPathExtension("mov")
            let audioOutputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Write-Microphone-\(UUID().uuidString)")
                .appendingPathExtension("m4a")

            microphoneInputGuard = MicrophoneInputGuard.prepareForRecording()

            do {
                let recorder = try makeAudioRecorder(outputURL: audioOutputURL)
                guard recorder.record() else {
                    throw CocoaError(.fileWriteUnknown)
                }

                audioRecorder = recorder
                activeAudioRecordingURL = audioOutputURL
            } catch {
                restoreMicrophoneInputState()
                activeAudioRecordingURL = nil
                audioRecorder = nil
                recordingIssue = .recordingFailed
                return
            }

            sessionQueue.async {
                guard self.isConfigured else {
                    DispatchQueue.main.async {
                        self.audioRecorder?.stop()
                        self.audioRecorder = nil
                        self.activeAudioRecordingURL = nil
                        self.restoreMicrophoneInputState()
                        self.recordingIssue = .recordingFailed
                    }
                    return
                }

                self.movieOutput.startRecording(to: videoOutputURL, recordingDelegate: self)

                DispatchQueue.main.async {
                    self.isRecording = true
                }
            }
        }
    }

    func prepareForDismissal() async {
        guard !didPrepareForDismissal, !isTearingDownSession else {
            return
        }

        didPrepareForDismissal = true
        isTearingDownSession = true
        hasPreparedSession = false
        isPreparingSession = false
        previewSession = nil
        state = .loading
        audioCaptureState = .unknown
        isConfigured = false
        audioRecorder?.stop()
        audioRecorder = nil
        activeAudioRecordingURL = nil
        restoreMicrophoneInputState()

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(120))
        await stopSessionAndResetGraph()
        isTearingDownSession = false
    }

    private func restoreMicrophoneInputState() {
        microphoneInputGuard?.restore()
        microphoneInputGuard = nil
    }

    private func ensureAudioCaptureReady() async -> AudioCaptureState {
        if audioCaptureState == .ready {
            return .ready
        }

        let granted = await requestAccess(for: .audio)
        guard granted else {
            audioCaptureState = .permissionDenied
            return .permissionDenied
        }

        guard AVCaptureDevice.default(for: .audio) != nil else {
            audioCaptureState = .unavailable
            return .unavailable
        }

        audioCaptureState = .ready
        return .ready
    }

    nonisolated private func requestAccess(for mediaType: AVMediaType) async -> Bool {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: mediaType)

        switch authorizationStatus {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: mediaType)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    nonisolated private func configureSessionAndStartRunning() async throws {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                do {
                    self.session.beginConfiguration()
                    self.session.sessionPreset = .medium

                    self.session.inputs.forEach { input in
                        self.session.removeInput(input)
                    }

                    self.session.outputs.forEach { output in
                        self.session.removeOutput(output)
                    }

                    self.isConfigured = false

                    guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                        ?? AVCaptureDevice.default(for: .video) else {
                        throw CameraConfigurationError.noCamera
                    }

                    let videoInput = try AVCaptureDeviceInput(device: videoDevice)

                    guard self.session.canAddInput(videoInput) else {
                        throw CameraConfigurationError.unableToAddInput
                    }

                    self.session.addInput(videoInput)

                    guard self.session.canAddOutput(self.photoOutput),
                          self.session.canAddOutput(self.movieOutput) else {
                        throw CameraConfigurationError.unableToAddOutput
                    }

                    self.session.addOutput(self.photoOutput)
                    self.session.addOutput(self.movieOutput)
                    self.session.commitConfiguration()
                    if !self.session.isRunning {
                        self.session.startRunning()
                    }
                    self.isConfigured = true
                    continuation.resume()
                } catch {
                    self.session.commitConfiguration()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    nonisolated private func stopSessionAndResetGraph() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                self.resetSessionGraph()
                continuation.resume()
            }
        }
    }

    nonisolated private func resetSessionGraph() {
        if session.isRunning {
            session.stopRunning()
        }

        session.beginConfiguration()
        session.inputs.forEach { input in
            session.removeInput(input)
        }
        session.outputs.forEach { output in
            session.removeOutput(output)
        }
        session.commitConfiguration()

        isConfigured = false
    }

    private func makeAudioRecorder(outputURL: URL) throws -> AVAudioRecorder {
        try? FileManager.default.removeItem(at: outputURL)

        let recorder = try AVAudioRecorder(
            url: outputURL,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128_000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
        )
        recorder.prepareToRecord()
        recorder.isMeteringEnabled = false
        return recorder
    }

    deinit {
        audioRecorder?.stop()
    }
}

extension CameraCaptureController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation() else {
            return
        }

        DispatchQueue.main.async {
            self.capturedPhotoData = data
        }
    }
}

extension CameraCaptureController: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.isFinalizingRecording = false
            self.restoreMicrophoneInputState()

            guard error == nil else {
                if let audioURL = self.activeAudioRecordingURL {
                    try? FileManager.default.removeItem(at: audioURL)
                }
                self.activeAudioRecordingURL = nil
                self.recordingIssue = .recordingFailed
                return
            }

            let capture = CapturedVideoRecording(
                videoURL: outputFileURL,
                audioURL: self.activeAudioRecordingURL
            )
            self.activeAudioRecordingURL = nil
            self.capturedVideoRecording = capture
        }
    }
}

private enum CameraConfigurationError: Error {
    case noCamera
    case unableToAddInput
    case unableToAddOutput
}

private enum PrivacyPane {
    case camera
    case microphone
}

private struct MicrophoneInputGuard {
    private let deviceID: AudioDeviceID
    private let originalMute: UInt32?
    private let originalVolumeScalar: Float32?

    static func prepareForRecording() -> MicrophoneInputGuard? {
        guard let deviceID = defaultInputDeviceID() else {
            return nil
        }

        let originalMute = readUInt32Property(
            selector: kAudioDevicePropertyMute,
            scope: kAudioDevicePropertyScopeInput,
            deviceID: deviceID
        )
        let originalVolumeScalar = readFloat32Property(
            selector: kAudioDevicePropertyVolumeScalar,
            scope: kAudioDevicePropertyScopeInput,
            deviceID: deviceID
        )

        if originalMute == 1 {
            setUInt32PropertyIfPossible(
                0,
                selector: kAudioDevicePropertyMute,
                scope: kAudioDevicePropertyScopeInput,
                deviceID: deviceID
            )
        }

        if let originalVolumeScalar,
           originalVolumeScalar == 0 {
            setFloat32PropertyIfPossible(
                0.5,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: kAudioDevicePropertyScopeInput,
                deviceID: deviceID
            )
        }

        return MicrophoneInputGuard(
            deviceID: deviceID,
            originalMute: originalMute,
            originalVolumeScalar: originalVolumeScalar
        )
    }

    func restore() {
        if let originalMute {
            Self.setUInt32PropertyIfPossible(
                originalMute,
                selector: kAudioDevicePropertyMute,
                scope: kAudioDevicePropertyScopeInput,
                deviceID: deviceID
            )
        }

        if let originalVolumeScalar {
            Self.setFloat32PropertyIfPossible(
                originalVolumeScalar,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: kAudioDevicePropertyScopeInput,
                deviceID: deviceID
            )
        }
    }

    private static func defaultInputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceID
        )

        guard status == noErr else {
            return nil
        }

        return deviceID
    }

    private static func readUInt32Property(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        deviceID: AudioDeviceID
    ) -> UInt32? {
        var value = UInt32(0)
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &dataSize,
            &value
        )

        return status == noErr ? value : nil
    }

    private static func readFloat32Property(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        deviceID: AudioDeviceID
    ) -> Float32? {
        var value = Float32(0)
        var dataSize = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &dataSize,
            &value
        )

        return status == noErr ? value : nil
    }

    private static func setUInt32PropertyIfPossible(
        _ value: UInt32,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        deviceID: AudioDeviceID
    ) {
        guard isPropertySettable(selector: selector, scope: scope, deviceID: deviceID) else {
            return
        }

        var mutableValue = value
        let dataSize = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        _ = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            dataSize,
            &mutableValue
        )
    }

    private static func setFloat32PropertyIfPossible(
        _ value: Float32,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        deviceID: AudioDeviceID
    ) {
        guard isPropertySettable(selector: selector, scope: scope, deviceID: deviceID) else {
            return
        }

        var mutableValue = value
        let dataSize = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        _ = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            dataSize,
            &mutableValue
        )
    }

    private static func isPropertySettable(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        deviceID: AudioDeviceID
    ) -> Bool {
        var isSettable = DarwinBoolean(false)
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectIsPropertySettable(
            deviceID,
            &address,
            &isSettable
        )

        return status == noErr && isSettable.boolValue
    }
}

private struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession?

    func makeNSView(context: Context) -> CameraPreviewContainerView {
        let view = CameraPreviewContainerView()
        view.setSession(session)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewContainerView, context: Context) {
        nsView.setSession(session)
    }

    static func dismantleNSView(_ nsView: CameraPreviewContainerView, coordinator: ()) {
        nsView.detachPreviewLayer()
    }
}

private final class CameraPreviewContainerView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSession(_ session: AVCaptureSession?) {
        if previewLayer.session == nil, session == nil {
            return
        }

        guard previewLayer.session !== session else {
            return
        }

        previewLayer.session = session
    }

    func detachPreviewLayer() {
        previewLayer.session = nil
        previewLayer.removeFromSuperlayer()
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }

    deinit {
        previewLayer.session = nil
        previewLayer.removeFromSuperlayer()
    }
}
#endif

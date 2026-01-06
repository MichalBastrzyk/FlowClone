//
//  AudioCaptureService.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation
import AVFoundation

final class AudioCaptureService {
    static let shared = AudioCaptureService()

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var tempFileURL: URL?
    private let sessionID = UUID()

    private init() {}

    // MARK: - Recording Control

    func startRecording() async throws -> RecordingSession {
        Logger.shared.info("Starting audio recording...")

        // Check microphone permission
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard authStatus == .authorized else {
            throw AudioCaptureError.microphoneNotAuthorized
        }

        // Create temp file
        let tempDir = FileManager.default.temporaryDirectory
        let flowCloneDir = tempDir.appendingPathComponent("FlowClone", isDirectory: true)

        // Create FlowClone directory if it doesn't exist
        try? FileManager.default.createDirectory(at: flowCloneDir, withIntermediateDirectories: true)

        let fileName = "recording_\(UUID().uuidString).m4a"
        let fileURL = flowCloneDir.appendingPathComponent(fileName)

        // Setup audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioCaptureError.engineSetupFailed
        }

        // Get input node
        let inputNode = audioEngine.inputNode

        // Create recording format
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Create audio file
        audioFile = try AVAudioFile(forWriting: fileURL, settings: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ])

        tempFileURL = fileURL

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, time in
            guard let self = self,
                  let audioFile = self.audioFile else { return }

            do {
                try audioFile.write(from: buffer)
            } catch {
                Logger.shared.error("Failed to write audio buffer: \(error.localizedDescription)")
            }
        }

        // Start engine
        try audioEngine.start()
        Logger.shared.info("Audio recording started: \(fileURL.path)")

        return RecordingSession(
            id: sessionID,
            startedAt: Date(),
            tempFileURL: fileURL,
            maxDurationSeconds: 300 // 5 minutes
        )
    }

    func stopRecording() async throws -> URL {
        Logger.shared.info("Stopping audio recording...")

        guard let audioEngine = audioEngine else {
            throw AudioCaptureError.noActiveRecording
        }

        // Stop engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // Close file
        audioFile?.close()

        guard let fileURL = tempFileURL else {
            throw AudioCaptureError.noActiveRecording
        }

        Logger.shared.info("Audio recording stopped: \(fileURL.path)")

        // Cleanup
        audioEngine = nil
        audioFile = nil
        let finalURL = tempFileURL
        tempFileURL = nil

        return finalURL!
    }

    // MARK: - Cleanup

    func deleteTempFile(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            Logger.shared.debug("Deleted temp audio file: \(url.path)")
        } catch {
            Logger.shared.error("Failed to delete temp file: \(error.localizedDescription)")
        }
    }

    func cleanupAllTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        let flowCloneDir = tempDir.appendingPathComponent("FlowClone", isDirectory: true)

        guard FileManager.default.fileExists(atPath: flowCloneDir.path) else {
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: flowCloneDir, includingPropertiesForKeys: nil)
            for file in files {
                try FileManager.default.removeItem(at: file)
            }
            Logger.shared.info("Cleaned up \(files.count) temp audio file(s)")
        } catch {
            Logger.shared.error("Failed to cleanup temp files: \(error.localizedDescription)")
        }
    }
}

enum AudioCaptureError: LocalizedError {
    case microphoneNotAuthorized
    case engineSetupFailed
    case noActiveRecording
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .microphoneNotAuthorized:
            return "Microphone access not authorized"
        case .engineSetupFailed:
            return "Failed to setup audio engine"
        case .noActiveRecording:
            return "No active recording session"
        case .fileWriteFailed:
            return "Failed to write audio file"
        }
    }
}

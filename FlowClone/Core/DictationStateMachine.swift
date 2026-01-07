//
//  DictationStateMachine.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation

@Observable
final class DictationStateMachine {
    // MARK: - Published State

    private(set) var state: DictationState = .idle {
        willSet {
            Logger.shared.info("[State] \(stateDescription) -> \(DictationStateMachine.stateDescription(for: newValue)) (event: \(lastEvent ?? "unknown"))")
        }
    }

    var currentSession: RecordingSession? {
        switch state {
        case .recording(let session),
             .stopping(let session),
             .transcribing(let session):
            return session
        default:
            return nil
        }
    }

    private var lastEvent: String?

    // MARK: - Dependencies

    private let settings: AppSettings
    private let permissions: PermissionsService
    private let audioCapture: AudioCaptureService
    private let transcription: TranscriptionService
    private let textInjection: TextInjectionService
    private let keychain: KeychainService

    // MARK: - Timer References

    private var armingTimer: Timer?
    private var maxDurationTimer: Timer?
    private var errorRecoveryTimer: Timer?

    // MARK: - Callbacks

    /// Called when dictation completes successfully (after injection)
    var onDictationComplete: (() -> Void)?

    // MARK: - Constants

    private let armingDebounceInterval: TimeInterval = 0.065 // 65ms
    private let errorAutoRecoveryDelay: TimeInterval = 3.0

    // MARK: - Init

    init(
        settings: AppSettings,
        permissions: PermissionsService,
        audioCapture: AudioCaptureService,
        transcription: TranscriptionService,
        textInjection: TextInjectionService,
        keychain: KeychainService
    ) {
        self.settings = settings
        self.permissions = permissions
        self.audioCapture = audioCapture
        self.transcription = transcription
        self.textInjection = textInjection
        self.keychain = keychain
    }

    // MARK: - Event Handling

    func handle(_ event: DictationEvent) {
        lastEvent = eventDescription(for: event)

        switch (state, event) {

        // IDLE state
        case (.idle, .hotkeyDown(let date)):
            transitionToArming(startedAt: date)

        // ARMING state
        case (.arming, .armingDebounceFired):
            if permissions.canRecordAudio {
                transitionToRecording()
            } else {
                transitionToError("Microphone permission required", recoverable: true)
            }

        // RECORDING state
        case (.recording, .hotkeyUp):
            transitionToStopping()

        case (.recording, .maxDurationReached):
            transitionToStopping()

        // STOPPING state (will transition to transcribing via callback)
        case (.stopping(let session), .recordingStopped):
            transitionToTranscribing(session: session)

        // TRANSCRIBING state
        case (.transcribing(let session), .transcriptionSucceeded(let text)):
            transitionToInjecting(session: session, text: text)

        case (.transcribing(let session), .transcriptionFailed(let message)):
            cleanup(session: session)
            transitionToError(message, recoverable: true)

        // INJECTING state
        case (.injecting, .injectionSucceeded):
            transitionToIdle(fromSuccessfulInjection: true)

        case (.injecting, .injectionFailed(let message)):
            transitionToError(message, recoverable: true)

        // ERROR state
        case (.error, .hotkeyDown):
            // Ignore hotkey during error
            break

        // Permissions changed
        case (.idle, .permissionsChanged),
             (.arming, .permissionsChanged):
            if !permissions.canRecordAudio {
                transitionToError("Microphone permission required", recoverable: true)
            }

        case (.error, .permissionsChanged):
            if permissions.canRecordAudio {
                transitionToIdle()
            } else {
                transitionToError("Microphone permission required", recoverable: true)
            }

        default:
            Logger.shared.debug("Invalid transition: \(stateDescription) + \(eventDescription(for: event))")
        }
    }

    // MARK: - Transitions

    private func transitionToIdle(fromSuccessfulInjection: Bool = false) {
        state = .idle
        cancelAllTimers()

        if fromSuccessfulInjection {
            onDictationComplete?()
        }
    }

    private func transitionToArming(startedAt: Date) {
        state = .arming(startedAt: startedAt)

        // Schedule debounce
        armingTimer = Timer.scheduledTimer(
            withTimeInterval: armingDebounceInterval,
            repeats: false
        ) { [weak self] _ in
            self?.handle(.armingDebounceFired)
        }
    }

    private func transitionToRecording() {
        Task { @MainActor in
            do {
                let session = try await audioCapture.startRecording()
                state = .recording(session: session)

                // Schedule max duration timer
                self.maxDurationTimer = Timer.scheduledTimer(
                    withTimeInterval: session.maxDurationSeconds,
                    repeats: false
                ) { [weak self] _ in
                    self?.handle(.maxDurationReached)
                }

                self.armingTimer = nil
            } catch {
                self.transitionToError("Failed to start recording: \(error.localizedDescription)", recoverable: true)
            }
        }
    }

    private func transitionToStopping() {
        guard case .recording(let session) = state else { return }

        state = .stopping(session: session)
        cancelAllTimers()

        Task { @MainActor in
            do {
                _ = try await audioCapture.stopRecording()
                self.handle(.recordingStopped(session))
            } catch {
                self.transitionToError("Failed to stop recording: \(error.localizedDescription)", recoverable: true)
            }
        }
    }

    private func transitionToTranscribing(session: RecordingSession) {
        state = .transcribing(session: session)

        Task { @MainActor in
            do {
                let apiKey = try keychain.getGroqAPIKey()

                let text = try await transcription.transcribe(
                    fileURL: session.tempFileURL,
                    apiKey: apiKey,
                    model: settings.transcriptionModel,
                    language: settings.languageMode
                )

                self.handle(.transcriptionSucceeded(text: text))
            } catch {
                self.handle(.transcriptionFailed(message: error.localizedDescription))
            }
        }
    }

    private func transitionToInjecting(session: RecordingSession, text: String) {
        state = .injecting(text: text)

        Task { @MainActor in
            do {
                try await textInjection.inject(text, mode: settings.insertionMode)
                self.handle(.injectionSucceeded)

                // Cleanup after injection
                self.cleanup(session: session)
            } catch {
                self.handle(.injectionFailed(message: error.localizedDescription))
            }
        }
    }

    private func transitionToError(_ message: String, recoverable: Bool) {
        state = .error(message: message, recoverable: recoverable)
        cancelAllTimers()

        // Auto-recover after delay (store timer so it can be cancelled)
        if recoverable {
            errorRecoveryTimer = Timer.scheduledTimer(
                withTimeInterval: errorAutoRecoveryDelay,
                repeats: false
            ) { [weak self] _ in
                self?.transitionToIdle()
            }
        }
    }

    // MARK: - Helpers

    private func cleanup(session: RecordingSession) {
        if settings.deleteTempAudio {
            audioCapture.deleteTempFile(at: session.tempFileURL)
        }
    }

    private func cancelAllTimers() {
        armingTimer?.invalidate()
        armingTimer = nil
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
        errorRecoveryTimer?.invalidate()
        errorRecoveryTimer = nil
    }

    // MARK: - Description Helpers

    var stateDescription: String {
        DictationStateMachine.stateDescription(for: state)
    }

    private static func stateDescription(for state: DictationState) -> String {
        switch state {
        case .idle:
            return "idle"
        case .arming:
            return "arming"
        case .recording:
            return "recording"
        case .stopping:
            return "stopping"
        case .transcribing:
            return "transcribing"
        case .injecting:
            return "injecting"
        case .error(let message, _):
            return "error: \(message)"
        }
    }

    private func eventDescription(for event: DictationEvent) -> String {
        switch event {
        case .hotkeyDown:
            return "hotkeyDown"
        case .hotkeyUp:
            return "hotkeyUp"
        case .armingDebounceFired:
            return "armingDebounceFired"
        case .maxDurationReached:
            return "maxDurationReached"
        case .recordingStarted:
            return "recordingStarted"
        case .recordingStopped:
            return "recordingStopped"
        case .transcriptionSucceeded:
            return "transcriptionSucceeded"
        case .transcriptionFailed:
            return "transcriptionFailed"
        case .injectionSucceeded:
            return "injectionSucceeded"
        case .injectionFailed:
            return "injectionFailed"
        case .permissionsChanged:
            return "permissionsChanged"
        }
    }
}

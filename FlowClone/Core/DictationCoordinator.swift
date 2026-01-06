//
//  DictationCoordinator.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation
import AppKit

@Observable
final class DictationCoordinator {
    // MARK: - Singleton

    static let shared = DictationCoordinator()

    // MARK: - State Machine

    private(set) var stateMachine: DictationStateMachine!

    // MARK: - Dependencies

    private let settings = AppSettings()
    private let permissions = PermissionsService.shared
    private let audioCapture = AudioCaptureService.shared
    private let transcription = TranscriptionService.shared
    private let textInjection = TextInjectionService.shared
    private let keychain = KeychainService.shared
    private let hotkeyService = HotkeyService.shared

    // MARK: - UI State

    var isRecording: Bool {
        if case .recording = stateMachine.state {
            return true
        }
        return false
    }

    var isTranscribing: Bool {
        if case .transcribing = stateMachine.state {
            return true
        }
        return false
    }

    var errorMessage: String? {
        if case .error(let message, _) = stateMachine.state {
            return message
        }
        return nil
    }

    var currentSession: RecordingSession? {
        stateMachine.currentSession
    }

    // MARK: - Init

    private init() {
        setupStateMachine()
        setupHotkeyService()
        setupPermissionsObserver()
    }

    // MARK: - Setup

    private func setupStateMachine() {
        stateMachine = DictationStateMachine(
            settings: settings,
            permissions: permissions,
            audioCapture: audioCapture,
            transcription: transcription,
            textInjection: textInjection,
            keychain: keychain
        )
    }

    private func setupHotkeyService() {
        hotkeyService.onHotkeyDown = { [weak self] date in
            self?.handleHotkeyDown(at: date)
        }

        hotkeyService.onHotkeyUp = { [weak self] date in
            self?.handleHotkeyUp(at: date)
        }

        // Set fallback hotkey from settings
        hotkeyService.setFallbackHotkey(settings.fallbackHotkey)
    }

    private func setupPermissionsObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(permissionsChanged),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Hotkey Handling

    private func handleHotkeyDown(at date: Date) {
        Logger.shared.debug("Hotkey DOWN detected")
        stateMachine.handle(.hotkeyDown(date))
    }

    private func handleHotkeyUp(at date: Date) {
        Logger.shared.debug("Hotkey UP detected")
        stateMachine.handle(.hotkeyUp(date))
    }

    // MARK: - Permissions

    @objc private func permissionsChanged() {
        let oldCanRecord = permissions.canRecordAudio
        permissions.refreshAllPermissions()

        if oldCanRecord != permissions.canRecordAudio {
            stateMachine.handle(.permissionsChanged)
        }
    }

    // MARK: - Public API

    func updateFallbackHotkey(_ config: HotkeyConfig?) {
        settings.fallbackHotkey = config
        hotkeyService.setFallbackHotkey(config)
    }

    // MARK: - Diagnostics

    func getDiagnostics() -> String {
        var diagnostics = """
        FlowClone Diagnostics
        ====================

        State: \(stateMachine.stateDescription)

        Permissions:
        - Microphone: \(permissions.microphonePermissionStatus)
        - Accessibility: \(permissions.accessibilityPermissionStatus)
        - Input Monitoring: \(permissions.inputMonitoringPermissionStatus)

        Settings:
        - Model: \(settings.transcriptionModel.rawValue)
        - Language: \(settings.languageMode.rawValue)
        - Insertion Mode: \(settings.insertionMode.rawValue)
        - Delete Temp Audio: \(settings.deleteTempAudio)
        - Launch at Login: \(settings.launchAtLogin)
        - Use Fn/Globe: \(settings.useFnGlobeHotkey)
        - Fallback Hotkey: \(settings.fallbackHotkey?.displayName ?? "none")

        API Key: \(keychain.hasGroqAPIKey() ? "Set" : "Not set")
        """

        return diagnostics
    }

    func copyDiagnostics() {
        let diagnostics = getDiagnostics()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(diagnostics, forType: .string)
        Logger.shared.info("Diagnostics copied to clipboard")
    }
}

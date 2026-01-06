//
//  DictationCoordinator.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation
import AppKit
import AVFoundation

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

    // Track previous permission state to detect when granted
    private var previousAccessibilityPermission: PermissionStatus = .notDetermined

    // MARK: - Init

    private init() {
        setupStateMachine()
        setupHotkeyService()
        setupPermissionsObserver()
        setupDictationCompleteObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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

        // Initialize previous permission state
        previousAccessibilityPermission = permissions.accessibilityPermissionStatus
    }

    private func setupDictationCompleteObserver() {
        // Observe state changes for successful dictation completion
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Check if we just completed dictation successfully
            // We detect this by checking if previous state was .injecting and now is .idle
            if self.previousStateWasInjecting && self.stateMachine.state == .idle {
                self.playSuccessSound()
                self.previousStateWasInjecting = false
            } else if case .injecting = self.stateMachine.state {
                self.previousStateWasInjecting = true
            }
        }
    }

    private var previousStateWasInjecting: Bool = false

    private func playSuccessSound() {
        // Play a satisfying system sound
        NSSound(named: "Glass")?.play()
        Logger.shared.info("✅ Dictation completed successfully!")
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
        let oldAccessibilityStatus = previousAccessibilityPermission

        permissions.refreshAllPermissions()

        // Check if accessibility permission was just granted
        if oldAccessibilityStatus != .granted && permissions.accessibilityPermissionStatus == .granted {
            Logger.shared.info("✅ Accessibility permission granted!")
            previousAccessibilityPermission = .granted
            showRestartConfirmationModal()
        }

        // Update tracked state
        previousAccessibilityPermission = permissions.accessibilityPermissionStatus

        if oldCanRecord != permissions.canRecordAudio {
            stateMachine.handle(.permissionsChanged)
        }
    }

    private func showRestartConfirmationModal() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Granted"
            alert.informativeText = "FlowClone needs to restart to apply the new permission settings.\n\nWould you like to restart now?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Restart Now")
            alert.addButton(withTitle: "Later")

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                // User clicked "Restart Now"
                Logger.shared.info("User confirmed restart - relaunching app...")
                self.restartApp()
            } else {
                // User clicked "Later"
                Logger.shared.info("User postponed restart")
            }
        }
    }

    private func restartApp() {
        let bundleURL = Bundle.main.bundleURL

        // Use NSWorkspace to relaunch the app
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        NSWorkspace.shared.openApplication(
            at: bundleURL,
            configuration: config
        ) { app, error in
            if let error = error {
                Logger.shared.error("Failed to relaunch app: \(error.localizedDescription)")
            }
        }

        // Terminate current instance after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
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

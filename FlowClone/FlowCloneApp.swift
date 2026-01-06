//
//  FlowCloneApp.swift
//  FlowClone
//
//  Created by Claude
//

import SwiftUI
import Combine

@main
struct FlowCloneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button("Open Settings") {
                AppDelegate.shared.showSettings()
            }

            Divider()

            Button("Quit FlowClone") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            MenuBarIcon()
        }
    }
}

struct MenuBarIcon: View {
    // Observe the state machine directly via @Observable
    private var stateMachine: DictationStateMachine { DictationCoordinator.shared.stateMachine }

    var body: some View {
        Image(systemName: iconName(for: stateMachine.state))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(iconColor(for: stateMachine.state))
    }

    private func iconName(for state: DictationState) -> String {
        switch state {
        case .idle: return "waveform"
        case .arming: return "hand.raised.fill"
        case .recording: return "circle.fill"
        case .stopping, .transcribing: return "waveform.path"
        case .injecting: return "keyboard"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private func iconColor(for state: DictationState) -> Color {
        switch state {
        case .idle: return .primary
        case .arming: return .orange
        case .recording: return .red
        case .stopping, .transcribing: return .blue
        case .injecting: return .green
        case .error: return .red
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    /// The actual app delegate instance set by the system
    private(set) static var shared: AppDelegate!

    private var hudWindowController: HUDWindowController?
    private var settingsWindow: NSWindow?

    func showSettings() {
        if settingsWindow == nil {
            let hostingView = NSHostingView(rootView: SettingsView())
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 550, height: 450),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = NSViewController()
            window.contentViewController?.view = hostingView
            window.title = "FlowClone Settings"
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set the shared reference to this actual instance
        AppDelegate.shared = self

        // Don't show dock icon or menu bar
        NSApp.setActivationPolicy(.accessory)

        // Initialize the coordinator to start services
        _ = DictationCoordinator.shared

        Logger.shared.info("FlowClone started")

        // Setup HUD window
        if let stateMachine = DictationCoordinator.shared.stateMachine {
            hudWindowController = HUDWindowController(stateMachine: stateMachine)
        }

        // Request all permissions on first launch
        requestPermissionsIfNeeded()
    }

    private func requestPermissionsIfNeeded() {
        let permissions = PermissionsService.shared

        // Microphone permission
        Task {
            do {
                try await permissions.requestMicrophonePermission()
            } catch {
                Logger.shared.error("Microphone permission denied: \(error.localizedDescription)")
            }

            // After microphone permission, prompt for Accessibility/Input Monitoring
            await MainActor.run {
                promptForAccessibilityAndInputMonitoring()
            }
        }
    }

    private func promptForAccessibilityAndInputMonitoring() {
        let permissions = PermissionsService.shared

        // Check if we already have either permission
        if permissions.accessibilityPermissionStatus == .granted ||
           permissions.inputMonitoringPermissionStatus == .granted {
            Logger.shared.info("✅ Accessibility or Input Monitoring already granted")
            return
        }

        // Automatically prompt for Accessibility (shows system dialog)
        Logger.shared.info("🔐 Requesting Accessibility permission...")
        permissions.promptForAccessibilityPermission()

        // After a short delay, prompt for Input Monitoring as well
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Logger.shared.info("🔐 Requesting Input Monitoring permission...")
            permissions.promptForInputMonitoringPermission()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when settings window is closed
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.info("FlowClone terminating")
        HotkeyService.shared.stop()
    }
}

//
//  FlowCloneApp.swift
//  FlowClone
//
//  Created by Claude
//

import SwiftUI

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
            Image(systemName: iconName)
        }
    }

    private var iconName: String {
        switch DictationCoordinator.shared.stateMachine.state {
        case .idle: return "waveform"
        case .arming: return "hand.raised.fill"
        case .recording: return "circle.fill"
        case .stopping, .transcribing: return "waveform.path"
        case .injecting: return "keyboard"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()

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
        // Don't show dock icon or menu bar
        NSApp.setActivationPolicy(.accessory)

        // Initialize the coordinator to start services
        _ = DictationCoordinator.shared

        Logger.shared.info("FlowClone started")

        // Setup HUD window
        if let stateMachine = DictationCoordinator.shared.stateMachine {
            hudWindowController = HUDWindowController(stateMachine: stateMachine)
        }

        // Request microphone permission on first launch
        Task {
            try? await PermissionsService.shared.requestMicrophonePermission()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when settings window is closed
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.info("FlowClone terminating")
        HotkeyService.shared.stopMonitoring()
    }
}

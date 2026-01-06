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
        // Menu bar app - no main window
        MenuBarView()
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hudWindowController: HUDWindowController?

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
            await PermissionsService.shared.requestMicrophonePermission()
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

//
//  HUDWindow.swift
//  FlowClone
//
//  Created by Claude
//

import Cocoa
import SwiftUI
import Combine

final class HUDWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.isMovable = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Position on the screen where the mouse is located
        repositionOnMouseScreen()
    }

    func repositionOnMouseScreen() {
        // Get mouse location
        let mouseLocation = NSEvent.mouseLocation

        // Find which screen contains the mouse
        guard let screen = NSScreen.screens.first(where: { screen in
            screen.frame.contains(mouseLocation)
        }) ?? NSScreen.main else {
            return
        }

        let screenFrame = screen.visibleFrame
        let windowFrame = self.frame

        // Center horizontally, position low near the Dock (bottom 5% of screen)
        let targetX = screenFrame.midX - windowFrame.width / 2
        let targetY = screenFrame.minY + (screenFrame.height * 0.05) - windowFrame.height / 2

        self.setFrameOrigin(NSPoint(x: targetX, y: targetY))
    }
}

final class HUDWindowController: NSWindowController {
    private var hostingView: NSHostingView<HUDView>!
    private let stateMachine: DictationStateMachine
    private var updateTimer: Timer?

    init(stateMachine: DictationStateMachine) {
        self.stateMachine = stateMachine

        let hudView = HUDView(
            state: stateMachine.state,
            session: stateMachine.currentSession
        )

        self.hostingView = NSHostingView(rootView: hudView)

        let window = HUDWindow()
        window.contentViewController = NSViewController()
        window.contentViewController?.view = hostingView

        super.init(window: window)

        // Poll for state changes
        startUpdating()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func startUpdating() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateHUDIfNeeded()
        }
    }

    private func updateHUDIfNeeded() {
        guard let window = window else { return }

        let currentView = hostingView.rootView
        let newState = stateMachine.state
        let newSession = stateMachine.currentSession

        // Only update if state changed
        if needsUpdate(currentView: currentView, newState: newState, newSession: newSession) {
            hostingView.rootView = HUDView(
                state: newState,
                session: newSession
            )

            switch newState {
            case .idle:
                window.orderOut(nil)
            case .arming, .recording, .stopping, .error:
                // Reposition to mouse screen before showing
                if let hudWindow = window as? HUDWindow {
                    hudWindow.repositionOnMouseScreen()
                }
                window.orderFrontRegardless()
            case .transcribing, .injecting:
                // Hide HUD immediately for these states
                window.orderOut(nil)
            }
        }
    }

    private func needsUpdate(currentView: HUDView, newState: DictationState, newSession: RecordingSession?) -> Bool {
        currentView.state != newState || currentView.session != newSession
    }

    deinit {
        updateTimer?.invalidate()
    }

    func show() {
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }
}

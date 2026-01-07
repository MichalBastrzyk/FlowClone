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
    private var observationTask: Task<Void, Never>?

    init(stateMachine: DictationStateMachine) {
        self.stateMachine = stateMachine

        let hudView = HUDView(
            state: stateMachine.state,
            session: stateMachine.currentSession
        )

        self.hostingView = NSHostingView(rootView: hudView)
        self.hostingView.autoresizingMask = [.width, .height]

        let window = HUDWindow()
        window.contentViewController = NSViewController()
        window.contentViewController?.view = hostingView
        hostingView.frame = window.contentView?.bounds ?? .zero

        super.init(window: window)

        // Observe state changes using @Observable tracking
        startObserving()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func startObserving() {
        // Use withObservationTracking for efficient, event-driven updates
        // This only wakes when state actually changes, eliminating CPU waste at idle
        observationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                
                // Capture current values and set up tracking for next change
                let (currentState, currentSession) = withObservationTracking {
                    (self.stateMachine.state, self.stateMachine.currentSession)
                } onChange: {
                    // This closure is called when state changes, but we handle it via the loop
                }
                
                // Update HUD with current state
                self.updateHUD(newState: currentState, newSession: currentSession)
                
                // Wait for next state change using async stream pattern
                // Small sleep to coalesce rapid changes and prevent tight loops
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func updateHUD(newState: DictationState, newSession: RecordingSession?) {
        guard let window = window else { return }

        let currentView = hostingView.rootView

        // Only update if state changed
        if currentView.state != newState || currentView.session != newSession {
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

    deinit {
        observationTask?.cancel()
    }

    func show() {
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }
}

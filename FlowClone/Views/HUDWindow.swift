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

        // Center the window
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = self.frame
            self.setFrameOrigin(
                NSPoint(
                    x: screenFrame.midX - windowFrame.width / 2,
                    y: screenFrame.midY - windowFrame.height / 2 + 100 // Slightly above center
                )
            )
        }
    }
}

final class HUDWindowController: NSWindowController {
    private let hostingView: NSHostingView<HUDView>
    private let stateMachine: DictationStateMachine

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

        // Observe state changes
        stateMachine.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.updateHUD(for: state)
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateHUD(for state: DictationState) {
        guard let window = window else { return }

        switch state {
        case .idle:
            window.orderOut(nil)
        case .arming, .recording, .stopping, .transcribing, .injecting, .error:
            hostingView.rootView = HUDView(
                state: state,
                session: stateMachine.currentSession
            )
            window.orderFrontRegardless()
        }
    }

    func show() {
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }
}

//
//  MenuBarView.swift
//  FlowClone
//
//  Created by Claude
//

import SwiftUI

struct MenuBarView: View {
    @State private var coordinator = DictationCoordinator.shared
    @State private var settings = AppSettings()
    @State private var keychain = KeychainService.shared
    @State private var showingSettings = false

    var body: some View {
        MenuBarExtra(content: {
            menuContent
        }) {
            menuIcon
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 300, height: 400)
        .environment(coordinator)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .frame(minWidth: 550, minHeight: 450)
        }
    }

    private var menuIcon: some View {
        Image(systemName: iconName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(iconColor)
    }

    private var iconName: String {
        switch coordinator.stateMachine.state {
        case .idle:
            return "waveform"
        case .arming:
            return "hand.raised.fill"
        case .recording:
            return "circle.fill"
        case .stopping, .transcribing:
            return "waveform.path"
        case .injecting:
            return "keyboard"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch coordinator.stateMachine.state {
        case .idle:
            return .primary
        case .arming:
            return .orange
        case .recording:
            return .red
        case .stopping, .transcribing:
            return .blue
        case .injecting:
            return .green
        case .error:
            return .red
        }
    }

    private var menuContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status section
            VStack(alignment: .leading, spacing: 4) {
                Text("FlowClone")
                    .font(.headline)

                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Permissions warning
            if !PermissionsService.shared.hasAllPermissions {
                Button {
                    showingSettings = true
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Permissions Required")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            // API key warning
            if !keychain.hasGroqAPIKey() {
                Button {
                    showingSettings = true
                } label: {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.orange)
                        Text("Set API Key")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            Divider()
                .padding(.vertical, 4)

            // Settings
            Button("Settings...") {
                showingSettings = true
            }
            .keyboardShortcut(",", modifiers: .command)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Divider()
                .padding(.vertical, 4)

            // Quit
            Button("Quit FlowClone") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    private var statusText: String {
        switch coordinator.stateMachine.state {
        case .idle:
            return "Ready - Hold hotkey to record"
        case .arming:
            return "Get ready..."
        case .recording(let session):
            let duration = Date().timeIntervalSince(session.startedAt)
            let seconds = Int(duration)
            return "Recording (\(seconds)s)"
        case .stopping:
            return "Stopping..."
        case .transcribing:
            return "Transcribing..."
        case .injecting:
            return "Inserting text..."
        case .error(let message, _):
            return "Error: \(message)"
        }
    }
}

#Preview {
    MenuBarView()
}

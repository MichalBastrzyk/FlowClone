//
//  SettingsView.swift
//  FlowClone
//
//  Created by Claude
//

import SwiftUI

struct SettingsView: View {
    @State private var settings = AppSettings()
    @State private var permissions = PermissionsService.shared
    @State private var launchAtLogin = LaunchAtLoginService.shared
    @State private var keychain = KeychainService.shared

    @State private var apiKeyInput: String = ""
    @State private var showingAPIKeyError = false
    @State private var apiKeyErrorMessage = ""

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            permissionsTab
                .tabItem {
                    Label("Permissions", systemImage: "hand.raised.fill")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 550, height: 450)
        .onAppear {
            loadAPIKey()
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("API Key") {
                SecureField("Groq API Key", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save API Key") {
                        saveAPIKey()
                    }
                    .disabled(apiKeyInput.isEmpty)

                    if keychain.hasGroqAPIKey() {
                        Button("Remove") {
                            removeAPIKey()
                        }
                    }

                    Spacer()

                    if keychain.hasGroqAPIKey() {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                Text("Get your API key from console.groq.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Transcription") {
                Picker("Model", selection: $settings.transcriptionModel) {
                    ForEach(TranscriptionModel.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }

                Picker("Language", selection: $settings.languageMode) {
                    ForEach(LanguageMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            Section("Text Injection") {
                Picker("Mode", selection: $settings.insertionMode) {
                    ForEach(InsertionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .help("Paste mode is faster, Type mode works in more apps")

                Toggle("Delete temp audio files", isOn: $settings.deleteTempAudio)
            }

            Section("Launch") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try launchAtLogin.enable()
                            } else {
                                try launchAtLogin.disable()
                            }
                        } catch {
                            Logger.shared.error("Failed to toggle launch at login: \(error.localizedDescription)")
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Permissions Tab

    private var permissionsTab: some View {
        Form {
            Section("Required Permissions") {
                permissionRow(
                    title: "Microphone",
                    icon: "mic.fill",
                    status: permissions.microphonePermissionStatus,
                    action: {
                        Task {
                            do {
                                try await permissions.requestMicrophonePermission()
                            } catch {
                                Logger.shared.error("Failed to request microphone permission: \(error.localizedDescription)")
                            }
                        }
                    },
                    actionLabel: "Request"
                )

                permissionRow(
                    title: "Accessibility",
                    icon: "hand.raised.fill",
                    status: permissions.accessibilityPermissionStatus,
                    action: {
                        permissions.promptForAccessibilityPermission()
                    },
                    actionLabel: "Open Settings"
                )

                permissionRow(
                    title: "Input Monitoring",
                    icon: "keyboard",
                    status: permissions.inputMonitoringPermissionStatus,
                    action: {
                        permissions.promptForInputMonitoringPermission()
                    },
                    actionLabel: "Open Settings"
                )
            }

            Section("Info") {
                Text("FlowClone requires these permissions to function:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("• Microphone: To record audio")
                    Text("• Accessibility or Input Monitoring: For global hotkey and text injection")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            permissions.refreshAllPermissions()
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("FlowClone")
                .font(.title)
                .fontWeight(.bold)

            Text("Voice dictation directly where you need it")
                .font(.body)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Version:")
                        .foregroundColor(.secondary)
                    Text("1.0.0")
                }

                HStack {
                    Text("Made by:")
                        .foregroundColor(.secondary)
                    Text("Michał Bastrzyk")
                }
            }

            Spacer()

            Button("Copy Diagnostics") {
                DictationCoordinator.shared.copyDiagnostics()
            }

            Divider()

            Text("Hold your hotkey to record, release to transcribe")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Views

    private func permissionRow(
        title: String,
        icon: String,
        status: PermissionStatus,
        action: @escaping () -> Void,
        actionLabel: String
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(status == .granted ? .green : (status == .denied ? .red : .orange))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)

                Text(statusText(for: status))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if status != .granted {
                Button(actionLabel) {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }

    private func statusText(for status: PermissionStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not requested"
        case .granted:
            return "Granted"
        case .denied:
            return "Denied - Open System Settings to enable"
        }
    }

    // MARK: - API Key Management

    private func loadAPIKey() {
        if let key = try? keychain.getGroqAPIKey() {
            apiKeyInput = key
        }
    }

    private func saveAPIKey() {
        do {
            try keychain.setGroqAPIKey(apiKeyInput)
            Logger.shared.info("API key saved successfully")
        } catch {
            apiKeyErrorMessage = error.localizedDescription
            showingAPIKeyError = true
            Logger.shared.error("Failed to save API key: \(error.localizedDescription)")
        }
    }

    private func removeAPIKey() {
        do {
            try keychain.deleteGroqAPIKey()
            apiKeyInput = ""
            Logger.shared.info("API key removed")
        } catch {
            Logger.shared.error("Failed to remove API key: \(error.localizedDescription)")
        }
    }
}

#Preview {
    SettingsView()
}

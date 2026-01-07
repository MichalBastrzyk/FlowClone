//
//  GeneralSettingsTab.swift
//  FlowClone
//
//  Created by Claude
//

import SwiftUI

struct GeneralSettingsTab: View {
    private var settings: AppSettings { AppSettings.shared }
    private let keychain = KeychainService.shared
    private let launchAtLogin = LaunchAtLoginService.shared

    @State private var apiKeyInput: String = ""
    @State private var showingAPIKeyError = false
    @State private var apiKeyErrorMessage = ""

    var body: some View {
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
                Picker("Model", selection: Binding(
                    get: { settings.transcriptionModel },
                    set: { settings.transcriptionModel = $0 }
                )) {
                    ForEach(TranscriptionModel.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }

                Picker("Language", selection: Binding(
                    get: { settings.languageMode },
                    set: { settings.languageMode = $0 }
                )) {
                    ForEach(LanguageMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            Section("Text Injection") {
                Picker("Mode", selection: Binding(
                    get: { settings.insertionMode },
                    set: { settings.insertionMode = $0 }
                )) {
                    ForEach(InsertionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .help("Paste mode is faster, Type mode works in more apps")

                Toggle("Delete temp audio files", isOn: Binding(
                    get: { settings.deleteTempAudio },
                    set: { settings.deleteTempAudio = $0 }
                ))
            }

            Section("Launch") {
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { newValue in
                        settings.launchAtLogin = newValue
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
                ))
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            loadAPIKey()
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
    GeneralSettingsTab()
        .frame(width: 550, height: 450)
}

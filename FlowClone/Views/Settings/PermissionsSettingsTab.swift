//
//  PermissionsSettingsTab.swift
//  FlowClone
//
//  Created by Claude
//

import SwiftUI

struct PermissionsSettingsTab: View {
    @State private var permissions = PermissionsService.shared

    var body: some View {
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
            }

            Section("Info") {
                Text("FlowClone requires these permissions to function:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("• Microphone: To record audio")
                    Text("• Accessibility: For global hotkey and text injection")
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
}

#Preview {
    PermissionsSettingsTab()
        .frame(width: 550, height: 450)
}

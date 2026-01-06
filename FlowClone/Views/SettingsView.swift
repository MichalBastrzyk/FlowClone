//
//  SettingsView.swift
//  FlowClone
//
//  Created by Claude
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            HotkeySettingsTab()
                .tabItem {
                    Label("Hotkey", systemImage: "command")
                }

            WaveformTestTab()
                .tabItem {
                    Label("Waveform", systemImage: "waveform")
                }

            PermissionsSettingsTab()
                .tabItem {
                    Label("Permissions", systemImage: "hand.raised.fill")
                }

            AboutSettingsTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 550, height: 450)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}

//
//  AboutSettingsTab.swift
//  FlowClone
//
//  Created by Claude
//

import SwiftUI

struct AboutSettingsTab: View {
    var body: some View {
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
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AboutSettingsTab()
        .frame(width: 550, height: 450)
}

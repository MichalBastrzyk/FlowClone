//
//  WaveformTestTab.swift
//  FlowClone
//
//  Created by Claude
//

import SwiftUI
import Combine

struct WaveformTestTab: View {
    private let barCount = AudioWaveformMonitor.barCount

    // Observe the waveform monitor directly
    private var waveformMonitor: AudioWaveformMonitor { AudioWaveformMonitor.shared }

    @State private var testMagnitude: Float = 0.0
    @State private var useRealAudio: Bool = false

    private var currentMagnitudes: [Float] {
        useRealAudio ? waveformMonitor.magnitudes : Array(repeating: testMagnitude, count: barCount)
    }

    var body: some View {
        Form {
            Section("Waveform Visualization") {
                VStack(spacing: 20) {
                    // Waveform preview - matches actual recording pill
                    HStack(spacing: 0) {
                        HStack(spacing: 3) {
                            ForEach(0..<barCount, id: \.self) { i in
                                let magnitude = i < currentMagnitudes.count ? currentMagnitudes[i] : 0
                                WaveBar(
                                    index: i,
                                    magnitude: magnitude,
                                    isRecording: true
                                )
                            }
                        }
                        .frame(height: 32, alignment: .center)
                        .padding(.leading, 20)
                        .padding(.trailing, 20)
                    }
                    .padding(.horizontal, 0)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.black)
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )

                    // Magnitude display
                    HStack {
                        Text("Average Magnitude:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        let avgMagnitude = currentMagnitudes.reduce(0, +) / Float(currentMagnitudes.count)
                        Text(String(format: "%.3f", avgMagnitude))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }

            Section("Controls") {
                Toggle("Use Real Audio Input", isOn: $useRealAudio)
                    .help("When enabled, uses your actual microphone. When disabled, use the slider below.")
                    .onChange(of: useRealAudio) { _, isRealAudio in
                        if isRealAudio {
                            AudioWaveformMonitor.shared.startMonitoring()
                        } else {
                            AudioWaveformMonitor.shared.stopMonitoring()
                        }
                    }

                if !useRealAudio {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Manual Magnitude")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.2f", testMagnitude))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $testMagnitude, in: 0...1)
                            .controlSize(.small)

                        HStack(spacing: 10) {
                            Button("0.0") { testMagnitude = 0.0 }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("0.25") { testMagnitude = 0.25 }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("0.5") { testMagnitude = 0.5 }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("0.75") { testMagnitude = 0.75 }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("1.0") { testMagnitude = 1.0 }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Info") {
                Text("Uses FFT (Fast Fourier Transform) to analyze audio frequencies. Each bar represents a different frequency range.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear {
            // Stop monitoring when leaving the tab, but keep toggle state
            // so user can see their last choice when returning
            if useRealAudio {
                AudioWaveformMonitor.shared.stopMonitoring()
            }
        }
        .onAppear {
            // Resume monitoring if toggle is still on when returning to tab
            if useRealAudio {
                AudioWaveformMonitor.shared.startMonitoring()
            }
        }
    }
}

#Preview {
    WaveformTestTab()
        .frame(width: 550, height: 450)
}

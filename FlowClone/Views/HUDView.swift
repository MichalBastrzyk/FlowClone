//
//  HUDView.swift
//  FlowClone
//
//  Created by Claude
//

import SwiftUI
import Combine

struct HUDView: View {
    let state: DictationState
    let session: RecordingSession?
    private let barCount = AudioWaveformMonitor.barCount

    // Observe the waveform monitor directly - it's @Observable
    private var waveformMonitor: AudioWaveformMonitor { AudioWaveformMonitor.shared }

    @State private var recordingDuration: TimeInterval = 0
    @State private var isVisible = false
    
    // Use TimelineView for duration updates instead of a stored timer publisher
    // This avoids timer accumulation when HUDView structs are recreated

    private var shouldShow: Bool {
        switch state {
        case .recording, .error:
            return true
        default:
            return false
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                content
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .opacity(isVisible ? 1 : 0)
                    .scaleEffect(isVisible ? 1 : 0.92)
                    .blur(radius: isVisible ? 0 : 3)
            }
        }
        .onChange(of: shouldShow) { _, newValue in
            withAnimation(.easeOut(duration: 0.15)) {
                isVisible = newValue
            }
        }
        .onAppear {
            if shouldShow {
                withAnimation(.easeOut(duration: 0.15)) {
                    isVisible = true
                }
            }
        }
        .frame(width: 400, height: 100)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .recording:
            recordingPill
        case .error(let message, _):
            errorPill(message: message)
        default:
            EmptyView()
        }
    }

    // MARK: - Recording Pill
    private var recordingPill: some View {
        HStack(spacing: 0) {
            // Reactive waveform bars - centered vertically and offset right
            let magnitudes = waveformMonitor.magnitudes
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { i in
                    WaveBar(
                        index: i,
                        magnitude: i < magnitudes.count ? magnitudes[i] : 0,
                        isRecording: true
                    )
                }
            }
            .frame(height: 32, alignment: .center) // Center vertically
            .padding(.leading, 20) // Left padding inside pill
            .padding(.trailing, 20) // Right padding inside pill
        }
        .padding(.horizontal, 0) // No extra horizontal padding
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(Color.black)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Error Pill
    private func errorPill(message: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(Color.black)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        let tenths = Int((recordingDuration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - Wave Bar
struct WaveBar: View {
    let index: Int
    var magnitude: Float
    let isRecording: Bool

    @State private var currentHeight: CGFloat = 8

    private var minHeight: CGFloat { 4 } // Flat baseline when silent

    private var maxHeight: CGFloat {
        // Maximum height varies by position for visual interest
        let pattern: [CGFloat] = [14, 18, 22, 26, 16, 20, 15, 28, 20, 16, 22, 18, 30, 22, 15, 20, 18, 24, 18, 14, 26, 19, 23, 21, 25, 17, 22, 30, 19, 24, 16, 23]
        return pattern[index % pattern.count]
    }

    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.85))
            .frame(width: 3, height: currentHeight)
            .onAppear {
                currentHeight = minHeight
            }
            .onChange(of: magnitude) { _, newMagnitude in
                guard isRecording else { return }

                // Calculate height based on FFT magnitude (flat at 0, grows with sound)
                let audioHeight = CGFloat(newMagnitude) * (maxHeight - minHeight)
                let targetHeight = minHeight + audioHeight

                // Smooth animation
                withAnimation(.easeOut(duration: 0.08)) {
                    currentHeight = targetHeight
                }
            }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color(white: 0.15)
            .ignoresSafeArea()

        VStack(spacing: 40) {
            // Recording pill with no timer
            HStack(spacing: 0) {
                HStack(spacing: 3) {
                    ForEach(0..<AudioWaveformMonitor.barCount, id: \.self) { i in
                        WaveBar(
                            index: i,
                            magnitude: 0.3,
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

            HUDView(state: .error(message: "Microphone access required", recoverable: true), session: nil)
        }
    }
    .frame(width: 400, height: 300)
}

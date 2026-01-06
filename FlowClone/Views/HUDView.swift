//
//  HUDView.swift
//  FlowClone
//
//  Created by Claude
//

import SwiftUI

struct HUDView: View {
    let state: DictationState
    let session: RecordingSession?

    @State private var recordingDuration: TimeInterval = 0
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            switch state {
            case .idle:
                EmptyView()

            case .arming:
                pill(content: "Getting Ready...", icon: "hand.raised.fill")

            case .recording:
                recordingPill

            case .stopping:
                pill(content: "Stopping...", icon: "stop.circle.fill")

            case .transcribing:
                pill(content: "Transcribing...", icon: "waveform")

            case .injecting:
                pill(content: "Inserting Text...", icon: "keyboard")

            case .error(let message, _):
                errorPill(message: message)
            }
        }
        .frame(maxWidth: 300)
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.2), value: state)
    }

    private var recordingPill: some View {
        VStack(spacing: 8) {
            pill(content: formattedDuration, icon: "circle.fill", isRecording: true)

            // Audio waveform visualization (simplified)
            HStack(spacing: 4) {
                ForEach(0..<20, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 4, height: randomHeight(for: i))
                        .animation(
                            .easeInOut(duration: 0.3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.05),
                            value: UUID()
                        )
                }
            }
            .frame(height: 24)
        }
        .onAppear {
            // Start timer for recording duration
        }
        .onReceive(timer) { _ in
            if case .recording(let session) = state {
                recordingDuration = Date().timeIntervalSince(session.startedAt)
            }
        }
    }

    private func pill(content: String, icon: String, isRecording: Bool = false) -> some View {
        HStack(spacing: 8) {
            if isRecording {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .shadow(color: .red, radius: 4)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
            }

            Text(content)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        )
        .foregroundColor(.white)
    }

    private func errorPill(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 14, weight: .semibold))

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        )
        .foregroundColor(.white)
    }

    private var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        let milliseconds = Int((recordingDuration.truncatingRemainder(dividingBy: 1)) * 10)

        return String(format: "%02d:%02d.%01d", minutes, seconds, milliseconds)
    }

    private func randomHeight(for index: Int) -> CGFloat {
        // Simulate waveform heights
        let pattern: [CGFloat] = [8, 12, 16, 20, 24, 20, 16, 12, 8, 10,
                                   14, 18, 22, 18, 14, 10, 6, 10, 14, 18]
        return pattern[index % pattern.count]
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)

        VStack(spacing: 20) {
            HUDView(state: .arming(startedAt: Date()), session: nil)
            HUDView(state: .recording(session: RecordingSession(tempFileURL: URL(fileURLWithPath: "/tmp/test"))), session: nil)
            HUDView(state: .transcribing(session: RecordingSession(tempFileURL: URL(fileURLWithPath: "/tmp/test"))), session: nil)
            HUDView(state: .error(message: "Microphone permission required", recoverable: true), session: nil)
        }
    }
}

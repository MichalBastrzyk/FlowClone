//
//  AudioWaveformMonitor.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation
import AVFoundation
import Accelerate
import Observation

@Observable
final class AudioWaveformMonitor {
    static let shared = AudioWaveformMonitor()

    // MARK: - Configuration

    private enum Constants {
        static let sampleAmount: Int = 20 // Match our 20 bars
        static let bufferSize: Int = 2048 // Power of 2 for FFT
        static let magnitudeLimit: Float = 100.0
    }

    // MARK: - Published Properties

    var magnitudes = [Float](repeating: 0, count: Constants.sampleAmount)
    var isMonitoring = false

    // MARK: - Dependencies

    private var audioEngine = AVAudioEngine()
    private var fftSetup: OpaquePointer?

    // MARK: - Init

    private init() {}

    deinit {
        stopMonitoring()
    }

    // MARK: - Monitoring Control

    func startMonitoring() async {
        Logger.shared.info("Starting audio waveform monitoring...")

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        // Set up FFT
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            UInt(Constants.bufferSize),
            .FORWARD
        )

        // Install tap on input node
        inputNode.installTap(
            onBus: 0,
            bufferSize: UInt32(Constants.bufferSize),
            format: inputFormat
        ) { [weak self] buffer, _ in
            guard let self = self else { return }

            Task { @MainActor in
                let newMagnitudes = await self.performFFT(data: buffer)
                self.magnitudes = newMagnitudes
            }
        }

        // Start engine
        do {
            try audioEngine.start()
            await MainActor.run {
                self.isMonitoring = true
            }
            Logger.shared.info("Audio waveform monitoring started")
        } catch {
            Logger.shared.error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        Logger.shared.info("Stopping audio waveform monitoring...")

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // Clear magnitudes
        Task { @MainActor in
            self.magnitudes = [Float](repeating: 0, count: Constants.sampleAmount)
            self.isMonitoring = false
        }

        // Release FFT setup
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
            fftSetup = nil
        }

        Logger.shared.info("Audio waveform monitoring stopped")
    }

    // MARK: - FFT Processing

    private func performFFT(data: AVAudioPCMBuffer) async -> [Float] {
        guard let setup = fftSetup else {
            return [Float](repeating: 0, count: Constants.sampleAmount)
        }

        guard let channelData = data.floatChannelData?[0] else {
            return [Float](repeating: 0, count: Constants.sampleAmount)
        }

        let frameCount = Int(data.frameLength)

        // Prepare input data
        var realIn = [Float](repeating: 0, count: Constants.bufferSize)
        var imagIn = [Float](repeating: 0, count: Constants.bufferSize)

        // Copy available data (up to buffer size)
        let copyCount = min(frameCount, Constants.bufferSize)
        for i in 0..<copyCount {
            realIn[i] = channelData[i]
        }

        // Prepare output arrays
        var realOut = [Float](repeating: 0, count: Constants.bufferSize)
        var imagOut = [Float](repeating: 0, count: Constants.bufferSize)

        // Execute FFT
        realIn.withUnsafeMutableBufferPointer { realInPtr in
            imagIn.withUnsafeMutableBufferPointer { imagInPtr in
                realOut.withUnsafeMutableBufferPointer { realOutPtr in
                    imagOut.withUnsafeMutableBufferPointer { imagOutPtr in
                        vDSP_DFT_Execute(
                            setup,
                            realInPtr.baseAddress!,
                            imagInPtr.baseAddress!,
                            realOutPtr.baseAddress!,
                            imagOutPtr.baseAddress!
                        )
                    }
                }
            }
        }

        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0, count: Constants.sampleAmount)

        var complex = DSPSplitComplex(
            realp: &realOut,
            imagp: &imagOut
        )

        // Compute magnitudes for our sample count
        vDSP_zvabs(
            &complex,
            1,
            &magnitudes,
            1,
            UInt(Constants.sampleAmount)
        )

        // Apply logarithmic scaling for better dynamic range
        let scaledMagnitudes = magnitudes.map { magnitude in
            let logMagnitude = log10(1.0 + magnitude * 10.0)
            return min(logMagnitude, 1.0)
        }

        return scaledMagnitudes
    }
}

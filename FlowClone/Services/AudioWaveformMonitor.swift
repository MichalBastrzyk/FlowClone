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

/// Processes audio buffers for waveform visualization.
/// This class does NOT own an AVAudioEngine - it receives buffers from AudioCaptureService.
@Observable
final class AudioWaveformMonitor {
    static let shared = AudioWaveformMonitor()

    // MARK: - Configuration

    private enum Constants {
        static let sampleAmount: Int = 32 // Number of bars to render
        static let bufferSize: Int = 2048 // Power of 2 for FFT
        static let magnitudeLimit: Float = 100.0
    }

    static let barCount: Int = Constants.sampleAmount

    // MARK: - Published Properties

    var magnitudes = [Float](repeating: 0, count: Constants.sampleAmount)
    private(set) var isMonitoring = false

    // MARK: - FFT Resources (pre-allocated for performance)

    private var fftSetup: OpaquePointer?
    private var realIn = [Float](repeating: 0, count: Constants.bufferSize)
    private var imagIn = [Float](repeating: 0, count: Constants.bufferSize)
    private var realOut = [Float](repeating: 0, count: Constants.bufferSize)
    private var imagOut = [Float](repeating: 0, count: Constants.bufferSize)
    private var fftMagnitudes = [Float](repeating: 0, count: Constants.sampleAmount)
    
    // Serial queue for FFT processing to prevent race conditions
    private let processingQueue = DispatchQueue(label: "com.michalbastrzyk.FlowClone.audioProcessing", qos: .userInteractive)

    // MARK: - Init

    private init() {
        setupFFT()
    }

    deinit {
        teardownFFT()
    }

    // MARK: - FFT Setup

    private func setupFFT() {
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            UInt(Constants.bufferSize),
            .FORWARD
        )
    }

    private func teardownFFT() {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
            fftSetup = nil
        }
    }

    // MARK: - Monitoring Control

    /// Start monitoring audio waveform.
    /// Note: This is intentionally synchronous (not async) as it only sets a flag.
    /// The actual audio processing happens asynchronously in processBuffer().
    func startMonitoring() {
        guard !isMonitoring else { return }
        Logger.shared.info("Audio waveform monitoring started")
        isMonitoring = true
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        Logger.shared.info("Audio waveform monitoring stopped")
        isMonitoring = false
        magnitudes = [Float](repeating: 0, count: Constants.sampleAmount)
    }

    // MARK: - Buffer Processing (called by AudioCaptureService)

    /// Process an audio buffer and update magnitudes. Called from AudioCaptureService's tap.
    func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isMonitoring else { return }

        // Process FFT on serial queue to prevent concurrent access to FFT buffers
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            let newMagnitudes = self.performFFT(data: buffer)

            Task { @MainActor in
                self.magnitudes = newMagnitudes
            }
        }
    }

    // MARK: - FFT Processing

    private func performFFT(data: AVAudioPCMBuffer) -> [Float] {
        guard let setup = fftSetup else {
            return [Float](repeating: 0, count: Constants.sampleAmount)
        }

        guard let channelData = data.floatChannelData?[0] else {
            return [Float](repeating: 0, count: Constants.sampleAmount)
        }

        let frameCount = Int(data.frameLength)

        // Reset input arrays
        realIn = [Float](repeating: 0, count: Constants.bufferSize)
        imagIn = [Float](repeating: 0, count: Constants.bufferSize)

        // Copy available data (up to buffer size)
        let copyCount = min(frameCount, Constants.bufferSize)
        for i in 0..<copyCount {
            realIn[i] = channelData[i]
        }

        // Reset output arrays
        realOut = [Float](repeating: 0, count: Constants.bufferSize)
        imagOut = [Float](repeating: 0, count: Constants.bufferSize)

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
        fftMagnitudes = [Float](repeating: 0, count: Constants.sampleAmount)

        var complex = DSPSplitComplex(
            realp: &realOut,
            imagp: &imagOut
        )

        // Compute magnitudes for our sample count (first N frequency bins)
        vDSP_zvabs(
            &complex,
            1,
            &fftMagnitudes,
            1,
            UInt(Constants.sampleAmount)
        )

        // Apply logarithmic scaling for better dynamic range
        return fftMagnitudes.map { magnitude in
            let logMagnitude = log10(1.0 + magnitude * 10.0)
            return min(logMagnitude, 1.0)
        }
    }
}

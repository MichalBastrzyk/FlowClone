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
    
    // Throttling to reduce CPU usage (30fps max)
    private var lastProcessTime: CFAbsoluteTime = 0
    private let minProcessInterval: CFAbsoluteTime = 0.033 // ~30fps

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
    @MainActor
    func startMonitoring() {
        guard !isMonitoring else { return }
        Logger.shared.info("Audio waveform monitoring started")
        isMonitoring = true
    }

    @MainActor
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
        
        // Throttle to ~30fps to reduce CPU usage
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastProcessTime >= minProcessInterval else { return }
        lastProcessTime = now

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

        // Zero buffers in-place instead of reallocating (critical for memory/CPU)
        vDSP_vclr(&realIn, 1, vDSP_Length(Constants.bufferSize))
        vDSP_vclr(&imagIn, 1, vDSP_Length(Constants.bufferSize))

        // Copy available data (up to buffer size) using vDSP for efficiency
        let copyCount = min(frameCount, Constants.bufferSize)
        cblas_scopy(Int32(copyCount), channelData, 1, &realIn, 1)

        // Zero output buffers in-place
        vDSP_vclr(&realOut, 1, vDSP_Length(Constants.bufferSize))
        vDSP_vclr(&imagOut, 1, vDSP_Length(Constants.bufferSize))

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

        // Calculate magnitudes (zero buffer in-place)
        vDSP_vclr(&fftMagnitudes, 1, vDSP_Length(Constants.sampleAmount))

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

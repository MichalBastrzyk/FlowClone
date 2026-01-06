//
//  TranscriptionService.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation

final class TranscriptionService {
    static let shared = TranscriptionService()

    private let session = URLSession.shared
    private let endpoint = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!

    private init() {}

    // MARK: - Transcription

    func transcribe(
        fileURL: URL,
        apiKey: String,
        model: TranscriptionModel,
        language: LanguageMode
    ) async throws -> String {
        Logger.shared.info("Starting transcription...")

        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Logger.shared.error("Audio file not found: \(fileURL.path)")
            throw TranscriptionError.fileNotFound
        }

        // Create request
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add file
        guard let fileData = try? Data(contentsOf: fileURL) else {
            throw TranscriptionError.fileReadFailed
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // Add model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model.rawValue)\r\n".data(using: .utf8)!)

        // Add language (if not auto)
        if language != .auto {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(language.rawValue)\r\n".data(using: .utf8)!)
        }

        // Add response format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Set timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        let timedSession = URLSession(configuration: config)

        // Send request
        do {
            let (data, response) = try await timedSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranscriptionError.invalidResponse
            }

            Logger.shared.debug("Transcription response status: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 401 {
                throw TranscriptionError.unauthorized
            } else if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                Logger.shared.error("Transcription failed with status \(httpResponse.statusCode): \(errorMessage)")
                throw TranscriptionError.serverError(httpResponse.statusCode, errorMessage)
            }

            // Parse response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = json["text"] as? String {
                Logger.shared.info("Transcription successful: \(text.prefix(50))...")
                return text
            } else {
                Logger.shared.error("Failed to parse transcription response")
                throw TranscriptionError.invalidResponse
            }
        } catch let error as TranscriptionError {
            throw error
        } catch {
            Logger.shared.error("Transcription network error: \(error.localizedDescription)")
            throw TranscriptionError.networkError(error)
        }
    }
}

enum TranscriptionError: LocalizedError {
    case fileNotFound
    case fileReadFailed
    case unauthorized
    case invalidResponse
    case networkError(Error)
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Audio file not found"
        case .fileReadFailed:
            return "Failed to read audio file"
        case .unauthorized:
            return "Invalid Groq API key"
        case .invalidResponse:
            return "Invalid response from transcription service"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unauthorized:
            return "Please check your Groq API key in Settings"
        case .networkError:
            return "Please check your internet connection"
        case .serverError:
            return "The Groq service may be unavailable. Please try again later"
        default:
            return nil
        }
    }
}

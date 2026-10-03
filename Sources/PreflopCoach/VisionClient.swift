import Foundation
import PreflopCore

struct VisionModel: Equatable {
    let id: String
    let name: String
    /// Dollars per million tokens.
    let inputPrice: Double
    let outputPrice: Double
    /// Haiku 4.5 rejects the effort setting and has no server-side fallback.
    let isCurrentGeneration: Bool

    static let all = [
        VisionModel(id: "claude-opus-5-5", name: "Opus 5.5 (most accurate)", inputPrice: 4, outputPrice: 20, isCurrentGeneration: true),
        VisionModel(id: "claude-sonnet-5-5", name: "Sonnet 5.5 (faster, half the cost)", inputPrice: 2, outputPrice: 10, isCurrentGeneration: true),
        VisionModel(id: "claude-haiku-4-5", name: "Haiku 4.5 (fastest, cheapest)", inputPrice: 1, outputPrice: 5, isCurrentGeneration: false),
    ]
}

struct VisionError: Error {
    let message: String
    var badKey = false
}

struct VisionResult {
    let read: TableRead
    let cost: Double
    /// The model's JSON, for the log.
    let raw: String
}

/// Sends a screenshot to the Claude Messages API and gets the table state back as JSON.
final class VisionClient {
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        return URLSession(configuration: config)
    }()

    /// Set if the API ever rejects the fallback option, so later requests go without it.
    private var skipFallbacks = false

    func read(jpeg: Data, model: VisionModel, apiKey: String) async throws -> VisionResult {
        do {
            return try await send(jpeg: jpeg, model: model, apiKey: apiKey)
        } catch let error as VisionError where !skipFallbacks && error.message.lowercased().contains("fallback") {
            skipFallbacks = true
            return try await send(jpeg: jpeg, model: model, apiKey: apiKey)
        }
    }

    private func send(jpeg: Data, model: VisionModel, apiKey: String) async throws -> VisionResult {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        var outputConfig: [String: Any] = ["format": ["type": "json_schema", "schema": TableRead.schema]]
        let image: [String: Any] = [
            "type": "image",
            "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()],
        ]
        let prompt: [String: Any] = ["type": "text", "text": "Report the table state."]
        let message: [String: Any] = ["role": "user", "content": [image, prompt]]
        var body: [String: Any] = [
            "model": model.id,
            "max_tokens": 8000,
            "system": TableRead.instructions,
            "messages": [message],
        ]
        if model.isCurrentGeneration {
            // Reading a table is transcription, so keep thinking short for speed.
            outputConfig["effort"] = "low"
            if !skipFallbacks {
                // If a safety classifier declines the request, retry on a fallback model in the same call.
                body["fallbacks"] = "default"
                request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
            }
        }
        body["output_config"] = outputConfig
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw VisionError(message: "Network problem: \(error.localizedDescription)")
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        guard status == 200 else {
            let detail = (json["error"] as? [String: Any])?["message"] as? String ?? "HTTP \(status)"
            switch status {
            case 401, 403: throw VisionError(message: "The API key was rejected. Set it again from the menu.", badKey: true)
            case 429: throw VisionError(message: "Rate limited by the Claude API. Slowing down.")
            case 500...: throw VisionError(message: "The Claude API is busy (\(status)). Will retry.")
            default: throw VisionError(message: detail)
            }
        }

        let usage = json["usage"] as? [String: Any] ?? [:]
        let input = (usage["input_tokens"] as? Double ?? 0) + (usage["cache_creation_input_tokens"] as? Double ?? 0)
            + (usage["cache_read_input_tokens"] as? Double ?? 0)
        let output = usage["output_tokens"] as? Double ?? 0
        let cost = (input * model.inputPrice + output * model.outputPrice) / 1_000_000

        switch json["stop_reason"] as? String {
        case "refusal": throw VisionError(message: "The model declined to read this screen.")
        case "max_tokens": throw VisionError(message: "The read was cut off. Try again.")
        default: break
        }

        let blocks = json["content"] as? [[String: Any]] ?? []
        guard let text = blocks.first(where: { $0["type"] as? String == "text" })?["text"] as? String,
              let read = try? JSONDecoder().decode(TableRead.self, from: Data(text.utf8))
        else { throw VisionError(message: "Couldn't understand the model's reply.") }
        return VisionResult(read: read, cost: cost, raw: text)
    }
}

import Foundation
import UIKit

enum AIError: LocalizedError {
    case unavailable, auth, credits, rateLimited, server, parse

    var errorDescription: String? {
        switch self {
        case .unavailable: "AI features aren't configured yet."
        case .auth: "AI features are currently unavailable. Please restart the app."
        case .credits: "AI features are temporarily unavailable. Please try again later."
        case .rateLimited: "Too many requests. Please wait a moment and try again."
        case .server: "Something went wrong. Please try again."
        case .parse: "Couldn't read the AI response. Please try again."
        }
    }
}

struct FoodEstimate: Decodable {
    var foodName: String
    var servingDescription: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
}

struct CalorieBurnEstimate: Decodable {
    var calories: Int
    var explanation: String
}

/// Calls the Rork Toolkit AI gateway (OpenAI-compatible chat completions).
enum AIService {
    private static let models = ["google/gemini-3.5-flash", "google/gemini-2.5-flash"]

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    static func estimateFood(image: UIImage) async throws -> FoodEstimate {
        guard let jpeg = compress(image) else { throw AIError.parse }
        let dataURL = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
        let prompt = """
        Identify the food in this photo and estimate its nutrition for the visible portion.
        Respond ONLY with JSON: {"foodName": string, "servingDescription": string, "calories": integer, "protein": number, "carbs": number, "fat": number, "fiber": number}. Grams for macros.
        """
        let content: [[String: Any]] = [
            ["type": "text", "text": prompt],
            ["type": "image_url", "image_url": ["url": dataURL]],
        ]
        return try await complete(content: content, as: FoodEstimate.self)
    }

    static func estimateBurn(type: String, minutes: Int, description: String) async throws -> CalorieBurnEstimate {
        let prompt = """
        Estimate calories burned for an average adult. Workout type: \(type). Duration: \(minutes) minutes. Description: \(description).
        Respond ONLY with JSON: {"calories": integer, "explanation": short string}.
        """
        return try await complete(content: [["type": "text", "text": prompt]], as: CalorieBurnEstimate.self)
    }

    private static func complete<T: Decodable>(content: [[String: Any]], as type: T.Type) async throws -> T {
        let base = Config.EXPO_PUBLIC_TOOLKIT_URL
        let key = Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY
        guard !base.isEmpty, !key.isEmpty, let url = URL(string: "\(base)/v2/vercel/v1/chat/completions") else {
            throw AIError.unavailable
        }
        let body: [String: Any] = [
            "model": models[0],
            "providerOptions": ["gateway": ["models": Array(models.dropFirst())]],
            "messages": [["role": "user", "content": content]],
            "response_format": ["type": "json_object"],
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200: break
        case 401, 403: throw AIError.auth
        case 402: throw AIError.credits
        case 429: throw AIError.rateLimited
        default: throw AIError.server
        }
        let chat = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard var text = chat.choices.first?.message.content else { throw AIError.parse }
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            text = String(text[start...end])
        }
        guard let json = text.data(using: .utf8), let result = try? JSONDecoder().decode(T.self, from: json) else {
            throw AIError.parse
        }
        return result
    }

    /// Keeps payloads well under the gateway's request-size limit.
    static func compress(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 1024
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        var quality: CGFloat = 0.75
        var data = resized.jpegData(compressionQuality: quality)
        while let d = data, d.count > 2_500_000, quality > 0.3 {
            quality -= 0.15
            data = resized.jpegData(compressionQuality: quality)
        }
        return data
    }
}

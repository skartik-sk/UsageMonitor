// Sources/GLMUsageMonitor/Services/UsageService.swift
import Foundation

actor UsageService {
    let baseURL: String
    let authToken: String
    let baseDomain: String

    private let session: URLSession

    init(baseURL: String, authToken: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.authToken = authToken
        self.session = session

        // Extract base domain (protocol + host)
        let parsed = URL(string: baseURL)!
        self.baseDomain = "\(parsed.scheme!)://\(parsed.host!)"
    }

    // MARK: - Endpoint URLs

    var quotaLimitURL: URL {
        URL(string: "\(baseDomain)/api/monitor/usage/quota/limit")!
    }

    var modelUsageURL: URL {
        URL(string: "\(baseDomain)/api/monitor/usage/model-usage")!
    }

    var toolUsageURL: URL {
        URL(string: "\(baseDomain)/api/monitor/usage/tool-usage")!
    }

    // MARK: - Fetch Methods

    func fetchQuotaLimit() async throws -> QuotaLimitData {
        try await fetch(url: quotaLimitURL)
    }

    func fetchModelUsage() async throws -> [ModelUsage] {
        let window = UsageTimeWindow.now
        let url = URL(string: "\(modelUsageURL.absoluteString)?startTime=\(window.startString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&endTime=\(window.endString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")!
        return try await fetch(url: url)
    }

    func fetchToolUsage() async throws -> [ToolUsage] {
        let window = UsageTimeWindow.now
        let url = URL(string: "\(toolUsageURL.absoluteString)?startTime=\(window.startString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&endTime=\(window.endString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")!
        return try await fetch(url: url)
    }

    // MARK: - Generic Fetch

    private func fetch<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw UsageServiceError.unauthorized
            }
            throw UsageServiceError.httpError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
}

enum UsageServiceError: LocalizedError {
    case invalidResponse
    case unauthorized
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from server"
        case .unauthorized:
            "Authentication failed. Please update your auth token in Settings."
        case .httpError(let code, let body):
            "HTTP \(code): \(body)"
        }
    }
}

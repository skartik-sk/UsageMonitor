// Sources/UsageMonitor/Services/UsageService.swift
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
        NSLog("[GLM] Fetching quota limit...")
        let result: QuotaLimitData = try await fetch(url: quotaLimitURL)
        NSLog("[GLM] Quota: \(result.limits.count) limits, level=\(result.level)")
        for limit in result.limits {
            NSLog("[GLM]   \(limit.type): \(limit.percentage)%")
            if let details = limit.usageDetails {
                for d in details {
                    NSLog("[GLM]     \(d.modelCode): \(d.usage)")
                }
            }
        }
        return result
    }

    func fetchModelUsage(window: UsageTimeWindow = .now) async throws -> ModelUsageData {
        let urlString = "\(modelUsageURL.absoluteString)?startTime=\(window.startString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&endTime=\(window.endString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
        let url = URL(string: urlString)!
        NSLog("[GLM] Fetching model usage: \(urlString)")
        let result: ModelUsageData = try await fetch(url: url)
        NSLog("[GLM] Model usage: \(result.totalUsage.totalModelCallCount) calls, \(result.totalUsage.totalTokensUsage) tokens")
        return result
    }

    func fetchToolUsage(window: UsageTimeWindow = .now) async throws -> ToolUsageData {
        let urlString = "\(toolUsageURL.absoluteString)?startTime=\(window.startString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&endTime=\(window.endString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
        let url = URL(string: urlString)!
        NSLog("[GLM] Fetching tool usage: \(urlString)")
        let result: ToolUsageData = try await fetch(url: url)
        for detail in result.totalUsage.toolDetails {
            NSLog("[GLM]   \(detail.modelName): \(detail.totalUsageCount)")
        }
        return result
    }

    // MARK: - Generic Fetch

    private func fetch<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        NSLog("[GLM] → GET \(url.absoluteString)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            NSLog("[GLM] ✗ Invalid response (not HTTP)")
            throw UsageServiceError.invalidResponse
        }

        let bodyString = String(data: data, encoding: .utf8) ?? "(empty)"
        NSLog("[GLM] ← \(httpResponse.statusCode) body=\(bodyString.prefix(300))")

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                NSLog("[GLM] ✗ Unauthorized")
                throw UsageServiceError.unauthorized
            }
            throw UsageServiceError.httpError(httpResponse.statusCode, bodyString)
        }

        // Decode: API wraps in {"code":200,"msg":"...","data":{...},"success":true}
        let decoder = JSONDecoder()
        // Do NOT use convertFromSnakeCase — API uses camelCase
        let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)

        guard apiResponse.success else {
            NSLog("[GLM] ✗ API success=false: \(apiResponse.msg)")
            throw UsageServiceError.apiError(apiResponse.msg)
        }

        NSLog("[GLM] ✓ Decoded successfully")
        return apiResponse.data
    }
}

enum UsageServiceError: LocalizedError {
    case invalidResponse
    case unauthorized
    case httpError(Int, String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from server"
        case .unauthorized:
            "Authentication failed. Check your auth token in Settings."
        case .httpError(let code, let body):
            "HTTP \(code): \(body)"
        case .apiError(let msg):
            "API Error: \(msg)"
        }
    }
}

// Sources/GLMUsageMonitor/Models/UsageData.swift
import Foundation

// MARK: - API Response Wrapper

struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let msg: String
    let data: T
    let success: Bool
}

// MARK: - Quota Limit

struct QuotaLimitData: Decodable {
    let limits: [QuotaLimit]
    let level: String
}

struct QuotaLimit: Decodable {
    let type: String       // "TIME_LIMIT" or "TOKENS_LIMIT"
    let unit: Int
    let number: Int?
    let usage: Int?
    let currentValue: Int?
    let remaining: Int?
    let percentage: Double
    let nextResetTime: Int64?
    let usageDetails: [UsageDetail]?
}

struct UsageDetail: Decodable {
    let modelCode: String
    let usage: Int
}

// MARK: - Model Usage

struct ModelUsageData: Decodable {
    let xTime: [String]?
    let modelCallCount: [Int?]?
    let tokensUsage: [Int?]?
    let totalUsage: ModelTotalUsage

    enum CodingKeys: String, CodingKey {
        case xTime = "x_time"
        case modelCallCount
        case tokensUsage
        case totalUsage
    }
}

struct ModelTotalUsage: Decodable {
    let totalModelCallCount: Int
    let totalTokensUsage: Int
}

// MARK: - Tool Usage

struct ToolUsageData: Decodable {
    let xTime: [String]?
    let totalUsage: ToolTotalUsage

    enum CodingKeys: String, CodingKey {
        case xTime = "x_time"
        case totalUsage
    }
}

struct ToolTotalUsage: Decodable {
    let totalNetworkSearchCount: Int
    let totalWebReadMcpCount: Int
    let totalZreadMcpCount: Int
    let totalSearchMcpCount: Int
    let toolDetails: [ToolDetail]
}

struct ToolDetail: Decodable {
    let modelName: String
    let totalUsageCount: Int
}

// MARK: - Time Window

struct UsageTimeWindow {
    let start: Date
    let end: Date

    static var now: UsageTimeWindow {
        let calendar = Calendar.current
        let date = Date()
        let currentHour = calendar.component(.hour, from: date)

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date) else {
            return UsageTimeWindow(start: date, end: date)
        }

        var startComponents = calendar.dateComponents([.year, .month, .day], from: yesterday)
        startComponents.hour = currentHour
        startComponents.minute = 0
        startComponents.second = 0

        var endComponents = calendar.dateComponents([.year, .month, .day], from: date)
        endComponents.hour = currentHour
        endComponents.minute = 59
        endComponents.second = 59

        return UsageTimeWindow(
            start: calendar.date(from: startComponents)!,
            end: calendar.date(from: endComponents)!
        )
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    var startString: String { Self.formatter.string(from: start) }
    var endString: String { Self.formatter.string(from: end) }
}

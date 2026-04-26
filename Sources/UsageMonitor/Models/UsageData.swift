// Sources/UsageMonitor/Models/UsageData.swift
import Foundation

// MARK: - Provider

enum UsageProvider: String, CaseIterable, Identifiable {
    case codex
    case glm

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .codex: "Codex"
        case .glm: "GLM"
        }
    }

    var title: String {
        switch self {
        case .codex: "Usage Monitor"
        case .glm: "Usage Monitor"
        }
    }
}

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

extension UsageDetail {
    init(label: String, percent: Double) {
        self.modelCode = label
        self.usage = Int(percent.rounded())
    }
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
    let label: String

    static var now: UsageTimeWindow {
        .lastHours(5)
    }

    static func lastHours(_ hours: Int, relativeTo now: Date = Date()) -> UsageTimeWindow {
        let calendar = Calendar.current
        let end = now

        guard let start = calendar.date(byAdding: .hour, value: -hours, to: end) else {
            return UsageTimeWindow(start: now, end: now, label: "\(hours)h")
        }

        return UsageTimeWindow(
            start: start,
            end: end,
            label: "\(hours)h"
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

// MARK: - Codex Analytics

struct CodexUsageData {
    let fiveHourRemainingPercentage: Double?
    let weeklyRemainingPercentage: Double?
    let fiveHourResetLabel: String?
    let weeklyResetLabel: String?
    let planName: String?
    let totalTasks: Int?
    let creditsUsed: Int?
    let details: [UsageDetail]
}

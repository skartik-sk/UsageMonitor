// Sources/GLMUsageMonitor/Models/UsageData.swift
import Foundation

// MARK: - Generic API Response

struct APIResponse<T: Decodable>: Decodable {
    let data: T
}

// MARK: - Quota Limit

struct QuotaLimitData: Decodable {
    let limits: [QuotaLimit]
}

struct QuotaLimit: Decodable {
    let type: String
    let percentage: Double
    var currentValue: Int?
    var usage: String?
    var usageDetails: String?
}

// MARK: - Model Usage

struct ModelUsage: Decodable {
    let model: String
    let inputTokens: Int
    let outputTokens: Int

    var totalTokens: Int {
        inputTokens + outputTokens
    }
}

// MARK: - Tool Usage

struct ToolUsage: Decodable {
    let tool: String
    let count: Int
}

// MARK: - Time Window

struct UsageTimeWindow {
    let start: Date
    let end: Date

    static var now: UsageTimeWindow {
        let calendar = Calendar.current
        let date = Date()

        let currentHour = calendar.component(.hour, from: date)

        var startComponents = calendar.dateComponents([.year, .month, .day], from: date)
        startComponents.hour = currentHour
        startComponents.minute = 0
        startComponents.second = 0
        startComponents.day = (startComponents.day ?? 1) - 1

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

// Tests/GLMUsageMonitorTests/UsageDataTests.swift
import Foundation
import Testing
@testable import GLMUsageMonitor

@Suite("UsageData JSON Parsing")
struct UsageDataTests {

    let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    @Test("Parse quota limit response")
    func parseQuotaLimitResponse() throws {
        let json = """
        {
          "data": {
            "limits": [
              {"type": "TOKENS_LIMIT", "percentage": 42.3},
              {"type": "TIME_LIMIT", "percentage": 23.1, "currentValue": 50, "usage": "100 calls", "usageDetails": null}
            ]
          }
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(APIResponse<QuotaLimitData>.self, from: json)
        let limits = response.data.limits

        #expect(limits.count == 2)

        let tokenLimit = limits[0]
        #expect(tokenLimit.type == "TOKENS_LIMIT")
        #expect(tokenLimit.percentage == 42.3)

        let timeLimit = limits[1]
        #expect(timeLimit.type == "TIME_LIMIT")
        #expect(timeLimit.percentage == 23.1)
    }

    @Test("Parse model usage response")
    func parseModelUsageResponse() throws {
        let json = """
        {
          "data": [
            {"model": "claude-sonnet-4-6", "inputTokens": 8000, "outputTokens": 4340},
            {"model": "claude-opus-4-6", "inputTokens": 5000, "outputTokens": 3120}
          ]
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(APIResponse<[ModelUsage]>.self, from: json)
        let models = response.data

        #expect(models.count == 2)
        #expect(models[0].model == "claude-sonnet-4-6")
        #expect(models[0].inputTokens == 8000)
        #expect(models[0].outputTokens == 4340)
        #expect(models[0].totalTokens == 12340)
    }

    @Test("Parse tool usage response")
    func parseToolUsageResponse() throws {
        let json = """
        {
          "data": [
            {"tool": "Bash", "count": 145},
            {"tool": "Edit", "count": 89}
          ]
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(APIResponse<[ToolUsage]>.self, from: json)
        let tools = response.data

        #expect(tools.count == 2)
        #expect(tools[0].tool == "Bash")
        #expect(tools[0].count == 145)
    }

    @Test("Time window calculation")
    func timeWindowCalculation() {
        let calendar = Calendar.current
        let now = Date()

        let window = UsageTimeWindow.now

        // Start should be yesterday at current hour
        let startComponents = calendar.dateComponents([.year, .month, .day, .hour], from: window.start)
        let nowComponents = calendar.dateComponents([.year, .month, .day, .hour], from: now)

        #expect(startComponents.hour == nowComponents.hour)
        // Start date should be 1 day before now
        let daysDiff = calendar.dateComponents([.day], from: window.start, to: now).day
        #expect(daysDiff == 1)
    }
}

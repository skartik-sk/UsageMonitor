// Tests/UsageMonitorTests/UsageDataTests.swift
import Foundation
import Testing
@testable import UsageMonitor

@Suite("UsageData JSON Parsing")
struct UsageDataTests {

    let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    @Test("Parse quota limit response")
    func parseQuotaLimitResponse() throws {
        let json = """
        {
          "code": 200,
          "msg": "ok",
          "success": true,
          "data": {
            "limits": [
              {"type": "TOKENS_LIMIT", "unit": 1, "percentage": 42.3},
              {"type": "TIME_LIMIT", "unit": 1, "percentage": 23.1, "currentValue": 50, "usage": 100, "usageDetails": null}
            ],
            "level": "normal"
          }
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(APIResponse<QuotaLimitData>.self, from: json)
        let limits = response.data.limits

        #expect(response.code == 200)
        #expect(response.success == true)
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
          "code": 200,
          "msg": "ok",
          "success": true,
          "data": {
            "x_time": ["10:00", "11:00"],
            "modelCallCount": [12, 24],
            "tokensUsage": [300, 500],
            "totalUsage": {
              "totalModelCallCount": 36,
              "totalTokensUsage": 800
            }
          }
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(APIResponse<ModelUsageData>.self, from: json)
        let usage = response.data

        #expect(response.success == true)
        #expect(response.data.totalUsage.totalModelCallCount == 36)
        #expect(response.data.totalUsage.totalTokensUsage == 800)
        #expect(usage.xTime?.count == 2)
        #expect(usage.modelCallCount?.first == 12)
    }

    @Test("Parse tool usage response")
    func parseToolUsageResponse() throws {
        let json = """
        {
          "code": 200,
          "msg": "ok",
          "success": true,
          "data": {
            "x_time": [],
            "totalUsage": {
              "totalNetworkSearchCount": 4,
              "totalWebReadMcpCount": 1,
              "totalZreadMcpCount": 0,
              "totalSearchMcpCount": 5,
              "toolDetails": [
                {"modelName": "Bash", "totalUsageCount": 145},
                {"modelName": "Edit", "totalUsageCount": 89}
              ]
            }
          }
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(APIResponse<ToolUsageData>.self, from: json)
        let tools = response.data

        #expect(response.success == true)
        #expect(tools.totalUsage.toolDetails.count == 2)
        #expect(tools.totalUsage.totalSearchMcpCount == 5)
        #expect(tools.totalUsage.toolDetails[0].modelName == "Bash")
    }

    @Test("Time window calculation")
    func timeWindowCalculation() {
        let now = Date()
        let window = UsageTimeWindow.lastHours(5, relativeTo: now)

        let seconds = window.end.timeIntervalSince(window.start)
        let expected = 5 * 60 * 60.0

        #expect(window.label == "5h")
        #expect(abs(seconds - expected) < 1.0)
        #expect(window.start <= now && now <= window.end)
    }
}

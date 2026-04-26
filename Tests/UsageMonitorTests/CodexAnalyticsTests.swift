import Foundation
import Testing
@testable import UsageMonitor

@Suite("Codex Analytics")
struct CodexAnalyticsTests {

    @Test("Normalizes exported cookie rows into Cookie header")
    func normalizesCookieRows() {
        let exported = """
        __Secure-next-auth.session-token\tabc123\t.chatgpt.com\t/\tSession
        cf_clearance\tclearance456\t.chatgpt.com\t/\tSession
        """

        let header = CodexAnalyticsService.normalizedCookieHeader(exported)

        #expect(header == "__Secure-next-auth.session-token=abc123; cf_clearance=clearance456")
    }

    @Test("Extracts Cookie and Authorization from copied curl")
    func extractsHeadersFromCurl() {
        let curl = """
        curl 'https://chatgpt.com/backend-api/wham/usage' \\
        -H 'Cookie: a=1; b=two; route="abc"' \\
        -H 'Authorization: Bearer token.value' \\
        -H 'Accept: */*'
        """

        let cookie = CodexAnalyticsService.normalizedCookieHeader(curl)
        let authorization = CodexAnalyticsService.normalizedAuthorizationHeader(curl)

        #expect(cookie == #"a=1; b=two; route="abc""#)
        #expect(authorization == "Bearer token.value")
    }

    @Test("Parses Codex remaining percentages")
    func parsesRemainingPercentages() throws {
        let json = """
        {
          "rateLimits": {
            "fiveHour": {
              "remainingPercent": 72.5
            },
            "weekly": {
              "remainingPercent": 41
            }
          },
          "planName": "ChatGPT Plus",
          "totalTasks": 12,
          "creditsUsed": 45
        }
        """.data(using: .utf8)!

        let usage = try CodexAnalyticsParser.parse(data: json)

        #expect(usage.fiveHourRemainingPercentage == 72.5)
        #expect(usage.weeklyRemainingPercentage == 41)
        #expect(usage.planName == "ChatGPT Plus")
        #expect(usage.totalTasks == 12)
        #expect(usage.creditsUsed == 45)
    }

    @Test("Parses embedded analytics text")
    func parsesEmbeddedText() throws {
        let html = """
        <html><body><script>
        window.__data = {"copy":"Rate Limits Remaining: 5h 96%, Weekly 94%"};
        </script></body></html>
        """.data(using: .utf8)!

        let usage = try CodexAnalyticsParser.parse(data: html)

        #expect(usage.fiveHourRemainingPercentage == 96)
        #expect(usage.weeklyRemainingPercentage == 94)
    }

    @Test("Parses Wham usage API response")
    func parsesWhamUsageAPIResponse() throws {
        let json = """
        {
          "rate_limit": {
            "primary_window": {
              "used_percent": 22,
              "limit_window_seconds": 18000,
              "reset_after_seconds": 1200
            },
            "secondary_window": {
              "used_percent": 5,
              "limit_window_seconds": 604800,
              "reset_after_seconds": 400000
            }
          },
          "additional_rate_limits": [
            {
              "limit_name": "GPT-5.3-Codex-Spark",
              "rate_limit": {
                "primary_window": {
                  "used_percent": 2,
                  "limit_window_seconds": 18000
                },
                "secondary_window": {
                  "used_percent": 1,
                  "limit_window_seconds": 604800
                }
              }
            }
          ],
          "credits": { "balance": 12 }
        }
        """.data(using: .utf8)!

        let usage = try CodexAnalyticsParser.parseWhamUsage(data: json)

        #expect(usage.fiveHourRemainingPercentage == 22)
        #expect(usage.weeklyRemainingPercentage == 5)
        #expect(usage.details.map(\.modelCode) == ["GPT-5.3-Codex-Spark 5h", "GPT-5.3-Codex-Spark Weekly"])
        #expect(usage.details.map(\.usage) == [2, 1])
        #expect(usage.creditsUsed == 12)
    }
}

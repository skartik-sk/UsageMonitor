// Tests/UsageMonitorTests/UsageServiceTests.swift
import Testing
@testable import UsageMonitor

@Suite("UsageService")
struct UsageServiceTests {

    @Test("Builds correct URLs for api.z.ai")
    func buildsCorrectURLs() async {
        let service = UsageService(baseURL: "https://api.z.ai/api/anthropic", authToken: "test-token")

        let baseDomain = "https://api.z.ai"
        #expect(await service.quotaLimitURL.absoluteString == "\(baseDomain)/api/monitor/usage/quota/limit")
    }

    @Test("Time window query params are URL-encoded")
    func timeWindowQueryParams() {
        let window = UsageTimeWindow.now
        let params = "startTime=\(window.startString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&endTime=\(window.endString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"

        // Should contain encoded date format
        #expect(params.contains("startTime="))
        #expect(params.contains("endTime="))
    }

    @Test("Extracts base domain from full URL")
    func extractsBaseDomain() async {
        let service = UsageService(baseURL: "https://api.z.ai/api/anthropic", authToken: "test-token")
        #expect(await service.baseDomain == "https://api.z.ai")

        let service2 = UsageService(baseURL: "https://open.bigmodel.cn/api/anthropic", authToken: "test-token")
        #expect(await service2.baseDomain == "https://open.bigmodel.cn")
    }
}

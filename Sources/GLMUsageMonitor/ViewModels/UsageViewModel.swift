// Sources/GLMUsageMonitor/ViewModels/UsageViewModel.swift
import Foundation
import Observation

@Observable
@MainActor
final class UsageViewModel {

    // MARK: - Usage State

    var tokenPercentage: Double?
    var timePercentage: Double?
    var weeklyPercentage: Double?
    var usageDetails: [UsageDetail] = []
    var toolDetails: [ToolDetail] = []
    var totalModelCalls: Int = 0
    var totalTokensUsage: Int = 0
    var totalSearchMcpCount: Int = 0
    var lastUpdated: Date?
    var isLoading = false
    var errorMessage: String?
    var isMonitoring: Bool {
        didSet { UserDefaults.standard.set(isMonitoring, forKey: "isMonitoring") }
    }

    // MARK: - Settings

    var authToken: String {
        didSet { try? KeychainService.save(token: authToken) }
    }
    var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "baseURL") }
    }
    var pollIntervalMinutes: Int {
        didSet { UserDefaults.standard.set(pollIntervalMinutes, forKey: "pollIntervalMinutes") }
    }

    // MARK: - Menu Bar Title

    var menuBarTitle: String {
        if !isMonitoring {
            return "\u{26A1} Paused"
        }
        if isLoading && tokenPercentage == nil {
            return "\u{26A1} ..."
        }
        if errorMessage != nil {
            return "\u{26A1} !"
        }
        if let tokenPercentage {
            return String(format: "\u{26A1} %.0f%%", tokenPercentage)
        }
        return "\u{26A1} ..."
    }

    // MARK: - Polling

    private var timer: Timer?

    // MARK: - Init

    init() {
        self.authToken = KeychainService.load() ?? ""
        self.baseURL = UserDefaults.standard.string(forKey: "baseURL") ?? "https://api.z.ai/api/anthropic"

        let savedInterval = UserDefaults.standard.integer(forKey: "pollIntervalMinutes")
        self.pollIntervalMinutes = savedInterval == 0 ? 5 : savedInterval

        if UserDefaults.standard.object(forKey: "isMonitoring") != nil {
            self.isMonitoring = UserDefaults.standard.bool(forKey: "isMonitoring")
        } else {
            self.isMonitoring = true
        }
    }

    // MARK: - Fetch

    func fetchData() async {
        guard !authToken.isEmpty, !baseURL.isEmpty else {
            errorMessage = "Please configure auth token and base URL in Settings."
            NSLog("[GLM] No auth token or base URL configured")
            return
        }

        isLoading = true
        errorMessage = nil
        NSLog("[GLM] Starting data fetch...")

        let service = UsageService(baseURL: baseURL, authToken: authToken)

        do {
            async let quota = service.fetchQuotaLimit()
            async let models = service.fetchModelUsage()
            async let tools = service.fetchToolUsage()

            let (quotaData, modelData, toolData) = try await (quota, models, tools)

            // Extract percentages from quota limits
            for limit in quotaData.limits {
                NSLog("[GLM] Processing limit: \(limit.type) = \(limit.percentage)%")
                if limit.type == "TOKENS_LIMIT" {
                    tokenPercentage = limit.percentage
                } else if limit.type == "TIME_LIMIT" {
                    timePercentage = limit.percentage
                    if let details = limit.usageDetails {
                        usageDetails = details
                    }
                } else if limit.type == "WEEKLY_LIMIT" {
                    weeklyPercentage = limit.percentage
                }
            }

            totalModelCalls = modelData.totalUsage.totalModelCallCount
            totalTokensUsage = modelData.totalUsage.totalTokensUsage
            NSLog("[GLM] Totals: \(totalModelCalls) calls, \(totalTokensUsage) tokens")

            toolDetails = toolData.totalUsage.toolDetails
            totalSearchMcpCount = toolData.totalUsage.totalSearchMcpCount
            NSLog("[GLM] Tools: \(toolDetails.count) tools, \(totalSearchMcpCount) total searches")

            lastUpdated = Date()
            isLoading = false
            NSLog("[GLM] Fetch complete ✓")
        } catch {
            NSLog("[GLM] Fetch error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Polling Control

    func startPolling() {
        stopPolling()
        isMonitoring = true
        NSLog("[GLM] Starting polling (every \(pollIntervalMinutes) min)")
        Task {
            await fetchData()
        }
        timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(pollIntervalMinutes * 60),
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.fetchData()
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    func restartPolling() {
        startPolling()
    }
}

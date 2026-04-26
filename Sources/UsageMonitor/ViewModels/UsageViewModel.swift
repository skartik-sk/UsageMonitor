// Sources/UsageMonitor/ViewModels/UsageViewModel.swift
import Foundation
import Observation

@Observable
@MainActor
final class UsageViewModel {

    // MARK: - Usage State

    var tokenPercentage: Double?
    var timePercentage: Double?
    var weeklyPercentage: Double?
    var fiveHourResetLabel: String?
    var weeklyResetLabel: String?
    var usageDetails: [UsageDetail] = []
    var toolDetails: [ToolDetail] = []
    var totalModelCalls: Int = 0
    var totalTokensUsage: Int = 0
    var totalSearchMcpCount: Int = 0
    var lastUpdated: Date?
    var usageWindowLabel: String = "5h"
    var isLoading = false
    var errorMessage: String?
    var usageProvider: UsageProvider {
        didSet { UserDefaults.standard.set(usageProvider.rawValue, forKey: "usageProvider") }
    }
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
    var codexCookie: String {
        didSet { try? KeychainService.saveCodexCookie(codexCookie) }
    }
    var codexAnalyticsURL: String {
        didSet { UserDefaults.standard.set(codexAnalyticsURL, forKey: "codexAnalyticsURL") }
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
        if let percentage = tokenPercentage ?? weeklyPercentage {
            return String(format: "\u{26A1} %.0f%%", percentage)
        }
        return "\u{26A1} ..."
    }

    // MARK: - Polling

    private var pollingTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        let loadedAuthToken = KeychainService.load() ?? ""
        let loadedCodexCookie = KeychainService.loadCodexCookie() ?? ""

        self.authToken = loadedAuthToken
        self.codexCookie = loadedCodexCookie
        self.baseURL = UserDefaults.standard.string(forKey: "baseURL") ?? "https://api.z.ai/api/anthropic"
        self.codexAnalyticsURL = UserDefaults.standard.string(forKey: "codexAnalyticsURL") ?? "https://chatgpt.com/codex/cloud/settings/analytics"

        let savedProvider = UserDefaults.standard.string(forKey: "usageProvider")
        if let savedProvider, let provider = UsageProvider(rawValue: savedProvider) {
            self.usageProvider = provider
        } else if !loadedAuthToken.isEmpty && loadedCodexCookie.isEmpty {
            self.usageProvider = .glm
        } else {
            self.usageProvider = .codex
        }

        let savedInterval = UserDefaults.standard.integer(forKey: "pollIntervalMinutes")
        self.pollIntervalMinutes = savedInterval == 0 ? 5 : savedInterval

        if UserDefaults.standard.object(forKey: "isMonitoring") != nil {
            self.isMonitoring = UserDefaults.standard.bool(forKey: "isMonitoring")
        } else {
            self.isMonitoring = true
        }

        if isMonitoring {
            Task { @MainActor in
                startPolling()
            }
        }
    }

    // MARK: - Fetch

    func fetchData() async {
        guard !isLoading else {
            NSLog("[GLM] Skipping fetch because one is already running")
            return
        }
        guard hasRequiredCredentials else {
            errorMessage = credentialErrorMessage
            isLoading = false
            NSLog("[Usage] Missing credentials for \(usageProvider.displayName)")
            return
        }

        isLoading = true
        errorMessage = nil
        NSLog("[Usage] Starting \(usageProvider.displayName) data fetch...")

        do {
            switch usageProvider {
            case .codex:
                try await fetchCodexData()
            case .glm:
                try await fetchGLMData()
            }

            lastUpdated = Date()
            isLoading = false
            NSLog("[Usage] Fetch complete")
        } catch {
            NSLog("[Usage] Fetch error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Polling Control

    func startPolling() {
        stopPolling()
        isMonitoring = true
        NSLog("[Usage] Starting polling provider=\(usageProvider.displayName) interval=\(pollIntervalMinutes) min")

        Task { @MainActor in
            await fetchData()
        }

        let intervalSeconds = UInt64(max(1, pollIntervalMinutes) * 60)
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: intervalSeconds * 1_000_000_000)
                } catch {
                    break
                }

                guard let self, self.isMonitoring else { continue }
                await self.fetchData()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isMonitoring = false
    }

    func restartPolling() {
        startPolling()
    }

    private var hasRequiredCredentials: Bool {
        switch usageProvider {
        case .codex:
            !codexCookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !codexAnalyticsURL.isEmpty
        case .glm:
            !authToken.isEmpty && !baseURL.isEmpty
        }
    }

    private var credentialErrorMessage: String {
        switch usageProvider {
        case .codex:
            "Please paste your ChatGPT request headers in Settings."
        case .glm:
            "Please configure auth token and base URL in Settings."
        }
    }

    private func fetchGLMData() async throws {
        let service = UsageService(baseURL: baseURL, authToken: authToken)
        let window = UsageTimeWindow.now

        async let quota = service.fetchQuotaLimit()
        async let models = service.fetchModelUsage(window: window)
        async let tools = service.fetchToolUsage(window: window)

        let (quotaData, modelData, toolData) = try await (quota, models, tools)

        resetUsageState()

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
        toolDetails = toolData.totalUsage.toolDetails
        totalSearchMcpCount = toolData.totalUsage.totalSearchMcpCount
        usageWindowLabel = window.label
    }

    private func fetchCodexData() async throws {
        let service = try CodexAnalyticsService(
            analyticsURL: codexAnalyticsURL,
            cookieHeader: codexCookie
        )
        let data = try await service.fetchUsage()

        resetUsageState()

        tokenPercentage = data.fiveHourRemainingPercentage
        weeklyPercentage = data.weeklyRemainingPercentage
        fiveHourResetLabel = data.fiveHourResetLabel
        weeklyResetLabel = data.weeklyResetLabel
        usageDetails = data.details
        totalModelCalls = data.totalTasks ?? 0
        totalTokensUsage = data.creditsUsed ?? 0
        usageWindowLabel = "5h"

        NSLog(
            "[Codex] Parsed 5h used=%@ weekly used=%@",
            data.fiveHourRemainingPercentage.map { String(format: "%.1f%%", $0) } ?? "nil",
            data.weeklyRemainingPercentage.map { String(format: "%.1f%%", $0) } ?? "nil"
        )
    }

    private func resetUsageState() {
        tokenPercentage = nil
        timePercentage = nil
        weeklyPercentage = nil
        fiveHourResetLabel = nil
        weeklyResetLabel = nil
        usageDetails = []
        toolDetails = []
        totalModelCalls = 0
        totalTokensUsage = 0
        totalSearchMcpCount = 0
    }
}

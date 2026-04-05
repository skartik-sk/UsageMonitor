// Sources/GLMUsageMonitor/ViewModels/UsageViewModel.swift
import Foundation
import Observation

@Observable
@MainActor
final class UsageViewModel {

    // MARK: - Published State

    var tokenPercentage: Double?
    var mcpPercentage: Double?
    var modelUsages: [ModelUsage] = []
    var toolUsages: [ToolUsage] = []
    var lastUpdated: Date?
    var isLoading = false
    var errorMessage: String?

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
        if isLoading && tokenPercentage == nil {
            return "\u{26A1} ..."
        }
        if let errorMessage {
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
        self.pollIntervalMinutes = UserDefaults.standard.integer(forKey: "pollIntervalMinutes")
        if self.pollIntervalMinutes == 0 { self.pollIntervalMinutes = 5 }
    }

    // MARK: - Fetch

    func fetchData() async {
        guard !authToken.isEmpty, !baseURL.isEmpty else {
            errorMessage = "Please configure auth token and base URL in Settings."
            return
        }

        isLoading = true
        errorMessage = nil

        let service = UsageService(baseURL: baseURL, authToken: authToken)

        do {
            async let quota = service.fetchQuotaLimit()
            async let models = service.fetchModelUsage()
            async let tools = service.fetchToolUsage()

            let (quotaData, modelData, toolData) = try await (quota, models, tools)

            // Extract percentages from quota limits
            for limit in quotaData.limits {
                if limit.type == "TOKENS_LIMIT" {
                    tokenPercentage = limit.percentage
                } else if limit.type == "TIME_LIMIT" {
                    mcpPercentage = limit.percentage
                }
            }

            modelUsages = modelData
            toolUsages = toolData
            lastUpdated = Date()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Polling Control

    func startPolling() {
        stopPolling()
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
    }

    func restartPolling() {
        startPolling()
    }
}

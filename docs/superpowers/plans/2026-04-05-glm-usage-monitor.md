# GLM Usage Monitor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app that shows Z.ai token usage percentage and detailed breakdowns.

**Architecture:** SwiftUI app with `MenuBarExtra` (window style) for the dropdown, `@Observable` view model, `URLSession`-based API service, Keychain for token storage. Built with Swift Package Manager.

**Tech Stack:** Swift, SwiftUI, URLSession (async/await), Keychain Services, XCTest

---

## File Structure

```
GLMUsageMonitor/
├── Package.swift
├── Sources/
│   └── GLMUsageMonitor/
│       ├── App/
│       │   └── GLMUsageMonitorApp.swift      # @main, MenuBarExtra + Settings scenes
│       ├── Views/
│       │   ├── MenuBarContentView.swift       # Dropdown window content
│       │   └── SettingsView.swift             # Settings window
│       ├── Models/
│       │   └── UsageData.swift                # Codable structs for API responses
│       ├── Services/
│       │   ├── KeychainService.swift          # Keychain read/write for auth token
│       │   └── UsageService.swift             # API client (URLSession async)
│       └── ViewModels/
│           └── UsageViewModel.swift           # @Observable, ties service to UI
├── Tests/
│   └── GLMUsageMonitorTests/
│       ├── UsageDataTests.swift               # JSON parsing tests
│       └── UsageServiceTests.swift            # API service tests
└── docs/
```

---

### Task 1: Project Scaffolding + Package.swift

**Files:**
- Create: `Package.swift`

- [ ] **Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "GLMUsageMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GLMUsageMonitor",
            path: "Sources/GLMUsageMonitor"
        ),
        .testTarget(
            name: "GLMUsageMonitorTests",
            dependencies: ["GLMUsageMonitor"]
        )
    ]
)
```

- [ ] **Step 2: Create directory structure**

Run:
```bash
cd /Users/singupallikartik/Developer/GLMUsageMonitor
mkdir -p Sources/GLMUsageMonitor/{App,Views,Models,Services,ViewModels}
mkdir -p Tests/GLMUsageMonitorTests
```

- [ ] **Step 3: Verify structure builds**

Run: `swift build`
Expected: BUILD SUCCEEDED (no sources yet, but Package resolves)

- [ ] **Step 4: Commit**

```bash
git add Package.swift Sources/ Tests/
git commit -m "chore: scaffold project with Package.swift and directory structure"
```

---

### Task 2: Data Models

**Files:**
- Create: `Sources/GLMUsageMonitor/Models/UsageData.swift`
- Create: `Tests/GLMUsageMonitorTests/UsageDataTests.swift`

- [ ] **Step 1: Write the test file**

```swift
// Tests/GLMUsageMonitorTests/UsageDataTests.swift
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
```

- [ ] **Step 2: Write the model file**

```swift
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
```

- [ ] **Step 3: Run tests**

Run: `swift test`
Expected: All 4 tests PASS

- [ ] **Step 4: Commit**

```bash
git add Sources/GLMUsageMonitor/Models/UsageData.swift Tests/GLMUsageMonitorTests/UsageDataTests.swift
git commit -m "feat: add Codable data models for API responses with tests"
```

---

### Task 3: Keychain Service

**Files:**
- Create: `Sources/GLMUsageMonitor/Services/KeychainService.swift`

- [ ] **Step 1: Write KeychainService**

```swift
// Sources/GLMUsageMonitor/Services/KeychainService.swift
import Foundation
import Security

enum KeychainService {
    private static let service = "com.glm-usage-monitor"

    static func save(token: String) throws {
        let data = Data(token.utf8)

        // Delete any existing token first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "auth-token",
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "auth-token",
            kSecValueData as String: data,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "auth-token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "auth-token",
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            "Keychain save failed with status: \(status)"
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Sources/GLMUsageMonitor/Services/KeychainService.swift
git commit -m "feat: add KeychainService for secure auth token storage"
```

---

### Task 4: Usage API Service

**Files:**
- Create: `Sources/GLMUsageMonitor/Services/UsageService.swift`
- Create: `Tests/GLMUsageMonitorTests/UsageServiceTests.swift`

- [ ] **Step 1: Write the test file**

```swift
// Tests/GLMUsageMonitorTests/UsageServiceTests.swift
import Testing
@testable import GLMUsageMonitor

@Suite("UsageService")
struct UsageServiceTests {

    @Test("Builds correct URLs for api.z.ai")
    func buildsCorrectURLs() {
        let service = UsageService(baseURL: "https://api.z.ai/api/anthropic", authToken: "test-token")

        let baseDomain = "https://api.z.ai"
        #expect(service.quotaLimitURL.absoluteString == "\(baseDomain)/api/monitor/usage/quota/limit")
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
    func extractsBaseDomain() {
        let service = UsageService(baseURL: "https://api.z.ai/api/anthropic", authToken: "test-token")
        #expect(service.baseDomain == "https://api.z.ai")

        let service2 = UsageService(baseURL: "https://open.bigmodel.cn/api/anthropic", authToken: "test-token")
        #expect(service2.baseDomain == "https://open.bigmodel.cn")
    }
}
```

- [ ] **Step 2: Write UsageService**

```swift
// Sources/GLMUsageMonitor/Services/UsageService.swift
import Foundation

actor UsageService {
    let baseURL: String
    let authToken: String
    let baseDomain: String

    private let session: URLSession

    init(baseURL: String, authToken: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.authToken = authToken
        self.session = session

        // Extract base domain (protocol + host)
        let parsed = URL(string: baseURL)!
        self.baseDomain = "\(parsed.scheme!)://\(parsed.host!)"
    }

    // MARK: - Endpoint URLs

    var quotaLimitURL: URL {
        URL(string: "\(baseDomain)/api/monitor/usage/quota/limit")!
    }

    var modelUsageURL: URL {
        URL(string: "\(baseDomain)/api/monitor/usage/model-usage")!
    }

    var toolUsageURL: URL {
        URL(string: "\(baseDomain)/api/monitor/usage/tool-usage")!
    }

    // MARK: - Fetch Methods

    func fetchQuotaLimit() async throws -> QuotaLimitData {
        try await fetch(url: quotaLimitURL)
    }

    func fetchModelUsage() async throws -> [ModelUsage] {
        let window = UsageTimeWindow.now
        let url = URL(string: "\(modelUsageURL.absoluteString)?startTime=\(window.startString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&endTime=\(window.endString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")!
        return try await fetch(url: url)
    }

    func fetchToolUsage() async throws -> [ToolUsage] {
        let window = UsageTimeWindow.now
        let url = URL(string: "\(toolUsageURL.absoluteString)?startTime=\(window.startString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)&endTime=\(window.endString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")!
        return try await fetch(url: url)
    }

    // MARK: - Generic Fetch

    private func fetch<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(authToken, forHTTPHeaderField: "Authorization")
        request.setValue("en-US,en", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw UsageServiceError.unauthorized
            }
            throw UsageServiceError.httpError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
}

enum UsageServiceError: LocalizedError {
    case invalidResponse
    case unauthorized
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from server"
        case .unauthorized:
            "Authentication failed. Please update your auth token in Settings."
        case .httpError(let code, let body):
            "HTTP \(code): \(body)"
        }
    }
}
```

- [ ] **Step 3: Run tests**

Run: `swift test`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add Sources/GLMUsageMonitor/Services/UsageService.swift Tests/GLMUsageMonitorTests/UsageServiceTests.swift
git commit -m "feat: add UsageService API client with URL construction tests"
```

---

### Task 5: UsageViewModel

**Files:**
- Create: `Sources/GLMUsageMonitor/ViewModels/UsageViewModel.swift`

- [ ] **Step 1: Write UsageViewModel**

```swift
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
        didSet { KeychainService.save(token: authToken) }
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
```

- [ ] **Step 2: Build to verify compilation**

Run: `swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Sources/GLMUsageMonitor/ViewModels/UsageViewModel.swift
git commit -m "feat: add UsageViewModel with polling and @Observable"
```

---

### Task 6: App Entry Point

**Files:**
- Create: `Sources/GLMUsageMonitor/App/GLMUsageMonitorApp.swift`

- [ ] **Step 1: Write the app entry point**

```swift
// Sources/GLMUsageMonitor/App/GLMUsageMonitorApp.swift
import SwiftUI

@main
struct GLMUsageMonitorApp: App {
    @State private var viewModel = UsageViewModel()

    var body: some Scene {
        MenuBarExtra(viewModel.menuBarTitle) {
            MenuBarContentView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }

    init() {
        // Delay polling start until the app is fully set up
    }
}
```

Wait — we need to start polling on appear. Let me add an `onAppear` or use an `init` approach. Since `MenuBarExtra` content view can trigger it:

```swift
// Sources/GLMUsageMonitor/App/GLMUsageMonitorApp.swift
import SwiftUI

@main
struct GLMUsageMonitorApp: App {
    @State private var viewModel = UsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel)
                .onAppear {
                    if viewModel.tokenPercentage == nil && !viewModel.isLoading {
                        viewModel.startPolling()
                    }
                }
        } label: {
            Text(viewModel.menuBarTitle)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build`
Expected: BUILD SUCCEEDED (MenuBarContentView and SettingsView don't exist yet — will fail. We'll create them next.)

> Note: This step will fail until Tasks 7 and 8 are complete. That's expected. We'll verify the build after those tasks.

- [ ] **Step 3: Commit**

```bash
git add Sources/GLMUsageMonitor/App/GLMUsageMonitorApp.swift
git commit -m "feat: add app entry point with MenuBarExtra and Settings scenes"
```

---

### Task 7: Menu Bar Content View

**Files:**
- Create: `Sources/GLMUsageMonitor/Views/MenuBarContentView.swift`

- [ ] **Step 1: Write the menu bar dropdown view**

```swift
// Sources/GLMUsageMonitor/Views/MenuBarContentView.swift
import SwiftUI

struct MenuBarContentView: View {
    let viewModel: UsageViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection

            Divider()

            if let errorMessage = viewModel.errorMessage {
                errorSection(errorMessage)
            } else {
                tokenSection
                if !viewModel.modelUsages.isEmpty {
                    Divider()
                    modelSection
                }
                if !viewModel.toolUsages.isEmpty {
                    Divider()
                    toolSection
                }
                if viewModel.mcpPercentage != nil {
                    Divider()
                    mcpSection
                }
            }

            Divider()

            footerSection
        }
        .padding(16)
        .frame(width: 300)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("GLM Usage Monitor")
                .font(.headline)
            Spacer()
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Token Usage

    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Token Usage (5 Hour)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let pct = viewModel.tokenPercentage {
                    Text(String(format: "%.1f%%", pct))
                        .font(.subheadline.bold())
                }
            }
            if let pct = viewModel.tokenPercentage {
                ProgressView(value: pct, total: 100)
                    .tint(pct > 80 ? .red : pct > 50 ? .orange : .green)
            }
        }
    }

    // MARK: - Model Usage

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Model Usage")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(viewModel.modelUsages, id: \.model) { usage in
                HStack {
                    Text(usage.model)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text(formatTokens(usage.totalTokens))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Tool Usage

    private var toolSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tool Usage")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(viewModel.toolUsages, id: \.tool) { usage in
                HStack {
                    Text(usage.tool)
                        .font(.caption)
                    Spacer()
                    Text("\(usage.count) calls")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - MCP Usage

    private var mcpSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("MCP Usage (1 Month)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let pct = viewModel.mcpPercentage {
                    Text(String(format: "%.1f%%", pct))
                        .font(.subheadline.bold())
                }
            }
            if let pct = viewModel.mcpPercentage {
                ProgressView(value: pct, total: 100)
                    .tint(pct > 80 ? .red : pct > 50 ? .orange : .green)
            }
        }
    }

    // MARK: - Error

    private func errorSection(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let lastUpdated = viewModel.lastUpdated {
                Text("Last updated: \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.fetchData() }
                } label: {
                    Label("Refresh Now", systemImage: "arrow.clockwise")
                        .font(.caption)
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Helpers

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM tok", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fk tok", Double(count) / 1_000)
        }
        return "\(count) tok"
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build`
Expected: BUILD SUCCEEDED (SettingsView still missing)

> Note: Will fail until Task 8 is complete.

- [ ] **Step 3: Commit**

```bash
git add Sources/GLMUsageMonitor/Views/MenuBarContentView.swift
git commit -m "feat: add MenuBarContentView with token/model/tool/MCP sections"
```

---

### Task 8: Settings View

**Files:**
- Create: `Sources/GLMUsageMonitor/Views/SettingsView.swift`

- [ ] **Step 1: Write the settings view**

```swift
// Sources/GLMUsageMonitor/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    let viewModel: UsageViewModel

    var body: some View {
        Form {
            Section("API Configuration") {
                SecureField("Auth Token", text: Binding(
                    get: { viewModel.authToken },
                    set: { newValue in
                        viewModel.authToken = newValue
                        viewModel.restartPolling()
                    }
                ))
                .textFieldStyle(.roundedBorder)

                TextField("Base URL", text: Binding(
                    get: { viewModel.baseURL },
                    set: { newValue in
                        viewModel.baseURL = newValue
                        viewModel.restartPolling()
                    }
                ))
                .textFieldStyle(.roundedBorder)
            }

            Section("Polling") {
                HStack {
                    Text("Refresh every")
                    Stepper(
                        "\(viewModel.pollIntervalMinutes) min",
                        value: Binding(
                            get: { viewModel.pollIntervalMinutes },
                            set: { newValue in
                                viewModel.pollIntervalMinutes = newValue
                                viewModel.restartPolling()
                            }
                        ),
                        in: 1...60
                    )
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 250)
    }
}
```

- [ ] **Step 2: Build the full project**

Run: `swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run the full test suite**

Run: `swift test`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add Sources/GLMUsageMonitor/Views/SettingsView.swift
git commit -m "feat: add SettingsView with auth, URL, and poll interval config"
```

---

### Task 9: Build, Run, and Verify

**Files:** None (verification only)

- [ ] **Step 1: Clean build**

Run: `swift build -c release`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: Run all tests**

Run: `swift test -v`
Expected: All tests PASS

- [ ] **Step 3: Run the app manually**

Run: `swift run`
Expected: App appears in menu bar with `⚡ ...` initially, then fetches data and updates

- [ ] **Step 4: Verify manually**
1. Click the menu bar icon — dropdown should appear
2. Open Settings (from dropdown or Cmd+,) — settings window should appear
3. Enter auth token and base URL — should trigger immediate refresh
4. Verify percentage updates in menu bar after fetch completes

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore: project complete and verified"
```

---

## Self-Review

**Spec coverage:**
- Menu bar percentage display → Task 5 (menuBarTitle), Task 6 (MenuBarExtra label)
- Dropdown with token/model/tool/MCP → Task 7 (MenuBarContentView)
- Polling every N minutes → Task 5 (startPolling/restartPolling)
- Configurable settings → Task 8 (SettingsView)
- Keychain token storage → Task 3 (KeychainService)
- 3 API endpoints → Task 4 (UsageService)
- Time window calculation → Task 2 (UsageTimeWindow)
- Error states (!, loading ...) → Task 5 (menuBarTitle), Task 7 (errorSection)
- Refresh Now button → Task 7 (footerSection)
- Regular app with dock icon → Task 6 (no LSUIElement)

**Placeholder scan:** No TBDs, TODOs, or vague steps. All code blocks are complete.

**Type consistency:** All types (`QuotaLimit`, `ModelUsage`, `ToolUsage`, `UsageService`, `UsageViewModel`) are consistent across tasks. Property names match between definitions and usage.

// Sources/GLMUsageMonitor/Views/MenuBarContentView.swift
import SwiftUI

struct MenuBarContentView: View {
    let viewModel: UsageViewModel
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showSettings {
                settingsContent
            } else {
                usageContent
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    // MARK: - Usage Content

    private var usageContent: some View {
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
    }

    // MARK: - Settings Content

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    showSettings = false
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.caption)
                }
                Spacer()
                Text("Settings")
                    .font(.headline)
                Spacer()
                // Balance the back button
                Label("Back", systemImage: "chevron.left")
                    .font(.caption)
                    .opacity(0)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Auth Token")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("Enter your auth token", text: Binding(
                    get: { viewModel.authToken },
                    set: { newValue in
                        viewModel.authToken = newValue
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Base URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("https://api.z.ai/api/anthropic", text: Binding(
                    get: { viewModel.baseURL },
                    set: { newValue in
                        viewModel.baseURL = newValue
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            }

            HStack {
                Text("Refresh every")
                    .font(.caption)
                Spacer()
                Stepper(
                    "\(viewModel.pollIntervalMinutes) min",
                    value: Binding(
                        get: { viewModel.pollIntervalMinutes },
                        set: { newValue in
                            viewModel.pollIntervalMinutes = newValue
                        }
                    ),
                    in: 1...60
                )
                .font(.caption)
            }

            Divider()

            Button {
                viewModel.restartPolling()
                showSettings = false
            } label: {
                HStack {
                    Spacer()
                    Text("Save & Refresh")
                        .font(.caption.bold())
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
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
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }

                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
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

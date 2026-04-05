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

                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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

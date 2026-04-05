// Sources/GLMUsageMonitor/Views/MenuBarContentView.swift
import SwiftUI

struct MenuBarContentView: View {
    let viewModel: UsageViewModel
    @State private var showSettings = false

    var body: some View {
        ZStack {
            // Background Liquid Glass Effect
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // Vibrant Liquid Ambient Gradients for macOS aesthetic
            GeometryReader { geo in
                Circle()
                    .fill(Color.purple.opacity(0.25))
                    .frame(width: geo.size.width * 0.8, height: geo.size.width * 0.8)
                    .blur(radius: 40)
                    .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.2)

                Circle()
                    .fill(Color.blue.opacity(0.25))
                    .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                    .blur(radius: 50)
                    .offset(x: geo.size.width * 0.4, y: geo.size.height * 0.3)

                Circle()
                    .fill(Color.cyan.opacity(0.2))
                    .frame(width: geo.size.width * 0.6, height: geo.size.width * 0.6)
                    .blur(radius: 30)
                    .offset(x: geo.size.width * 0.1, y: geo.size.height * 0.6)
            }

            VStack(alignment: .leading, spacing: 16) {
                if showSettings {
                    settingsContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    usageContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .padding(18)
        }
        .frame(width: 370)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.1).blur(radius: 10)) // Additional diffusion
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: showSettings)
    }

    // MARK: - Usage Content

    private var usageContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerSection

            if let errorMessage = viewModel.errorMessage {
                glassPanel {
                    errorSection(errorMessage)
                }
            } else {
                glassPanel {
                    VStack(spacing: 12) {
                        tokenSection
                        if let timePct = viewModel.timePercentage {
                            Divider().opacity(0.5)
                            mcpUsageSection(timePct)
                        }
                        if let weeklyPct = viewModel.weeklyPercentage {
                            Divider().opacity(0.5)
                            weeklyUsageSection(weeklyPct)
                        }
                    }
                }

                if !viewModel.usageDetails.isEmpty || viewModel.totalModelCalls > 0 {
                    glassPanel {
                        VStack(spacing: 12) {
                            if !viewModel.usageDetails.isEmpty {
                                modelBreakdownSection
                            }
                            if viewModel.totalModelCalls > 0 {
                                if !viewModel.usageDetails.isEmpty { Divider().opacity(0.5) }
                                totalsSection
                            }
                        }
                    }
                }
            }

            footerSection
        }
    }

    // MARK: - Settings Content

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    withAnimation { showSettings = false }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()
                Text("Settings")
                    .font(.system(.headline, design: .rounded))
                Spacer()

                Image(systemName: "chevron.left")
                    .opacity(0)
            }

            glassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
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
                        .controlSize(.small)
                    }

                    VStack(alignment: .leading, spacing: 6) {
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
                        .controlSize(.small)
                    }

                    HStack {
                        Text("Refresh every")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                }
            }

            Button {
                viewModel.restartPolling()
                withAnimation { showSettings = false }
            } label: {
                HStack {
                    Spacer()
                    Text("Save & Refresh")
                        .font(.system(.callout, design: .rounded).bold())
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.8))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: Color.accentColor.opacity(0.3), radius: 5, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Header with Custom Glass Toggle

    private var headerSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(viewModel.isMonitoring ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: viewModel.isMonitoring ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(viewModel.isMonitoring ? .green : .secondary)
                }

                Text("GLM Usage")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(.primary)
            }

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            }

            // Custom modern macOS toggle button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if viewModel.isMonitoring {
                        viewModel.stopPolling()
                    } else {
                        viewModel.startPolling()
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(viewModel.isMonitoring ? "ON" : "OFF")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(viewModel.isMonitoring ? .green : .secondary)

                    Circle()
                        .fill(viewModel.isMonitoring ? Color.green : Color.secondary.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .shadow(color: viewModel.isMonitoring ? .green.opacity(0.5) : .clear, radius: 2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Token Usage

    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Token Usage (5 Hour)")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let pct = viewModel.tokenPercentage {
                    Text(String(format: "%.1f%%", pct))
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(colorForPercentage(pct))
                }
            }
            if let pct = viewModel.tokenPercentage {
                progressBar(pct: pct)
            } else {
                ProgressView().frame(height: 8)
            }
        }
    }

    // MARK: - Progress Bar

    private func progressBar(pct: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [colorForPercentage(pct).opacity(0.6), colorForPercentage(pct)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * CGFloat(pct / 100)))
                    .shadow(color: colorForPercentage(pct).opacity(0.4), radius: 3)
            }
        }
        .frame(height: 8)
    }

    // MARK: - MCP Usage

    private func mcpUsageSection(_ pct: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("MCP Usage (1 Month)")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(String(format: "%.1f%%", pct))
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(colorForPercentage(pct))
            }
            progressBar(pct: pct)
        }
    }

    // MARK: - Weekly Limit

    private func weeklyUsageSection(_ pct: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Weekly Limit")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(String(format: "%.1f%%", pct))
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(colorForPercentage(pct))
            }
            progressBar(pct: pct)
        }
    }

    // MARK: - Model Breakdown

    private var modelBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model Breakdown")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(viewModel.usageDetails, id: \.modelCode) { detail in
                HStack {
                    Text(detail.modelCode)
                        .font(.caption2)
                        .lineLimit(1)
                    Spacer()
                    Text("\(detail.usage) calls")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Totals

    private var totalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Totals (24h)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack {
                Text("Model Calls")
                    .font(.caption)
                Spacer()
                Text("\(viewModel.totalModelCalls)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Tokens Used")
                    .font(.caption)
                Spacer()
                Text(formatTokens(viewModel.totalTokensUsage))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
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
        HStack {
            Button {
                withAnimation { showSettings = true }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            if let lastUpdated = viewModel.lastUpdated {
                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - Liquid Glass Panel Extrusion

    @ViewBuilder
    private func glassPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.35), .white.opacity(0.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.overlay)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .white.opacity(0.1), .white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    // MARK: - Helpers

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fk", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func colorForPercentage(_ pct: Double) -> Color {
        if pct > 80 { return .red }
        if pct > 50 { return .orange }
        return .green
    }
}

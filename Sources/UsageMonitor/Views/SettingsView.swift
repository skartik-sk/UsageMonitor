// Sources/UsageMonitor/Views/SettingsView.swift
import SwiftUI
import AppKit

struct SettingsView: View {
    let viewModel: UsageViewModel

    var body: some View {
        Form {
            Section("Provider") {
                Picker("Provider", selection: Binding(
                    get: { viewModel.usageProvider },
                    set: { newValue in
                        viewModel.usageProvider = newValue
                        viewModel.restartPolling()
                    }
                )) {
                    ForEach(UsageProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("API Configuration") {
                if viewModel.usageProvider == .codex {
                    SecureField("ChatGPT Auth Headers", text: Binding(
                        get: { viewModel.codexCookie },
                        set: { newValue in
                            viewModel.codexCookie = newValue
                            viewModel.restartPolling()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    Text("Paste copied cURL, request headers, or a cookie export.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Analytics URL", text: Binding(
                        get: { viewModel.codexAnalyticsURL },
                        set: { newValue in
                            viewModel.codexAnalyticsURL = newValue
                            viewModel.restartPolling()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Button("Paste Headers from Clipboard") {
                        if let cookieText = NSPasteboard.general.string(forType: .string) {
                            viewModel.codexCookie = cookieText
                            viewModel.restartPolling()
                        }
                    }
                } else {
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
        .frame(width: 520, height: 320)
    }
}

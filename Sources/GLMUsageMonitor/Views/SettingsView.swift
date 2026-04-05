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

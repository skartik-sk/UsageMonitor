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

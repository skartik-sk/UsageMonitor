// Sources/UsageMonitor/App/UsageMonitorApp.swift
import SwiftUI

@main
struct UsageMonitorApp: App {
    @State private var viewModel = UsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel)
                .onAppear {
                    if viewModel.isMonitoring && viewModel.tokenPercentage == nil && !viewModel.isLoading {
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

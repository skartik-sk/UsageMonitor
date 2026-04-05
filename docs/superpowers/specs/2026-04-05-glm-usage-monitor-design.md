# GLM Usage Monitor — macOS Menu Bar App

## Overview

A native macOS menu bar app (Swift + SwiftUI) that displays token usage from the Z.ai API. Lives in the menu bar showing a percentage, polls on a configurable interval, and shows detailed breakdowns on click.

**Target:** macOS 26 (latest)
**Tech stack:** Swift, SwiftUI, URLSession, Keychain
**App type:** Regular app (dock icon + menu bar presence)

## Architecture

```
GLMUsageMonitor/
├── GLMUsageMonitorApp.swift       # App entry point with MenuBarExtra
├── Views/
│   ├── MenuBarView.swift           # Dropdown menu content
│   └── SettingsView.swift          # Settings window (token, URL, interval)
├── Models/
│   └── UsageData.swift             # Codable models for API responses
├── Services/
│   └── UsageService.swift          # API client (URLSession-based)
└── ViewModels/
    └── UsageViewModel.swift        # ObservableObject tying it together
```

**Lifecycle:**
1. App launches → reads saved settings (Keychain for token, UserDefaults for URL/interval)
2. Immediately fetches usage data from all 3 endpoints
3. Starts a `Timer.publish` at the configured interval (default 5 min)
4. Updates the `MenuBarExtra` title with the token usage percentage
5. On click → shows dropdown menu with full details

## Menu Bar Display

**Idle state (always visible):**
- Normal: `⚡ 42%` — lightning icon + token usage percentage
- Loading: `⚡ ...`
- Error: `⚡ !`

**Dropdown menu (on click):**

```
┌─────────────────────────────────┐
│ GLM Usage Monitor               │
│─────────────────────────────────│
│ Token Usage (5 Hour)     42.3%  │
│ ████████████░░░░░░░░░░░░        │
│─────────────────────────────────│
│ Model Usage                     │
│  claude-sonnet-4-6  12,340 tok  │
│  claude-opus-4-6     8,120 tok  │
│─────────────────────────────────│
│ Tool Usage                      │
│  Bash        145 calls          │
│  Edit         89 calls          │
│  Read         67 calls          │
│─────────────────────────────────│
│ MCP Usage (1 Month)     23.1%   │
│ ██████░░░░░░░░░░░░░░░░          │
│─────────────────────────────────│
│ Last updated: 2:34 PM           │
│─────────────────────────────────│
│ ↻ Refresh Now                   │
│ ⚙ Settings...                   │
│ Quit                            │
└─────────────────────────────────┘
```

- Token and MCP usage show SwiftUI `ProgressView` bars
- Model usage and tool usage show as simple lists
- "Last updated" timestamp for data freshness
- "Refresh Now" triggers immediate re-fetch
- "Settings..." opens the settings window

## API Integration

**Base URL:** Configurable, default `https://api.z.ai/api/anthropic`

### Endpoints (all GET)

1. **Quota Limit:** `{baseDomain}/api/monitor/usage/quota/limit`
   - No query params
   - Returns limits array with `TOKENS_LIMIT` (5hr %) and `TIME_LIMIT` (1mo %)
   - Primary data shown in menu bar title

2. **Model Usage:** `{baseDomain}/api/monitor/usage/model-usage?startTime=...&endTime=...`
   - Returns per-model token counts
   - Time window: yesterday at current hour → today at current hour

3. **Tool Usage:** `{baseDomain}/api/monitor/usage/tool-usage?startTime=...&endTime=...`
   - Returns per-tool call counts
   - Same time window as model usage

### Auth

- `Authorization` header with token from settings
- Token stored in macOS Keychain via Security framework

### Error Handling

- Network failure: show `⚡ !` in menu bar, error message in dropdown
- Invalid/expired token: specific auth error, prompt to update in settings
- All errors logged to console, retried on next poll cycle

### Polling

- Default: 5 minutes
- Configurable: 1-60 minutes
- Uses `Timer.publish` with `receive(on: RunLoop.main)`
- Changing settings triggers immediate refresh

## Settings Window

Standard macOS settings window (SwiftUI `Settings` scene):

- **Auth Token** — `SecureField`, stored in Keychain
- **Base URL** — `TextField`, default `https://api.z.ai/api/anthropic`, validates on save
- **Poll Interval** — `Stepper`, 1-60 minutes, default 5

Settings persist immediately on change. Changing token or URL triggers immediate data refresh.

## Time Window Calculation

Same logic as the existing Node.js script:
- Start: yesterday at current hour (HH:00:00)
- End: today at current hour end (HH:59:59)
- Format: `yyyy-MM-dd HH:mm:ss`
- URL-encoded as query parameters

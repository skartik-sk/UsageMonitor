# Usage Monitor

A macOS menu bar utility for tracking usage percentage from supported providers.

## Run

```bash
swift run UsageMonitor
```

## Codex Setup

1. Open ChatGPT Codex analytics in your browser.
2. Open DevTools, then the Network tab.
3. Refresh the page.
4. Find `/backend-api/wham/usage`.
5. Right click the request and copy it as cURL.
6. In the menu bar app, open Settings and select `Codex`.
7. Paste the copied cURL into `ChatGPT Auth Headers`.
8. Click `Save & Refresh`.

The app extracts the required `Cookie` and `Authorization` headers and stores them in Keychain.

## GLM Setup

1. Open Settings and select `GLM`.
2. Paste the auth token.
3. Confirm the base URL.
4. Click `Save & Refresh`.

## Display

The menu bar shows only the current used percentage, for example:

```text
⚡ 12%
```

Click the menu bar item to see 5 hour usage, weekly usage, model-specific limits, reset times, and refresh controls.

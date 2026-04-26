import Foundation

actor CodexAnalyticsService {
    let analyticsURL: URL
    let cookieHeader: String
    let authorizationHeader: String?

    private let session: URLSession

    init(analyticsURL: String, cookieHeader: String, session: URLSession = .shared) throws {
        guard let url = URL(string: analyticsURL), url.host == "chatgpt.com" else {
            throw UsageServiceError.invalidResponse
        }

        self.analyticsURL = url
        self.cookieHeader = Self.normalizedCookieHeader(cookieHeader)
        self.authorizationHeader = Self.normalizedAuthorizationHeader(cookieHeader)
        self.session = session
    }

    func fetchUsage() async throws -> CodexUsageData {
        let usageURL = try apiURL(path: "/backend-api/wham/usage")
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        if let authorizationHeader {
            request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(analyticsURL.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue("/backend-api/wham/usage", forHTTPHeaderField: "X-OpenAI-Target-Path")
        request.setValue("/backend-api/wham/usage", forHTTPHeaderField: "X-OpenAI-Target-Route")
        request.setValue("en-US", forHTTPHeaderField: "OAI-Language")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 20

        NSLog("[Codex] Fetching usage API %@", usageURL.absoluteString)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageServiceError.invalidResponse
        }

        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
        let finalURL = httpResponse.url?.absoluteString ?? analyticsURL.absoluteString
        NSLog(
            "[Codex] Response status=%d bytes=%d contentType=%@ finalURL=%@",
            httpResponse.statusCode,
            data.count,
            contentType,
            finalURL
        )

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw UsageServiceError.unauthorized
            }
            throw UsageServiceError.httpError(httpResponse.statusCode, "Codex usage request failed")
        }

        return try CodexAnalyticsParser.parseWhamUsage(data: data, diagnosticsEnabled: true)
    }

    private func apiURL(path: String) throws -> URL {
        guard var components = URLComponents(url: analyticsURL, resolvingAgainstBaseURL: false) else {
            throw UsageServiceError.invalidResponse
        }
        components.path = path
        components.query = nil
        components.fragment = nil
        guard let url = components.url else {
            throw UsageServiceError.invalidResponse
        }
        return url
    }

    static func normalizedCookieHeader(_ rawCookieText: String) -> String {
        let trimmed = rawCookieText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let header = extractHeader(named: "Cookie", from: trimmed) {
            return header
        }

        if trimmed.contains(";") && trimmed.contains("=") && !trimmed.contains("\t") {
            return trimmed
        }

        let lines = trimmed.components(separatedBy: .newlines)
        var pairs: [String] = []

        for line in lines {
            let parts = line
                .components(separatedBy: "\t")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if parts.count >= 2, parts[0].contains("=") == false {
                pairs.append("\(parts[0])=\(parts[1])")
            } else if let first = parts.first, first.contains("=") {
                pairs.append(first)
            }
        }

        return pairs.joined(separator: "; ")
    }

    static func normalizedAuthorizationHeader(_ rawText: String) -> String? {
        guard let header = extractHeader(named: "Authorization", from: rawText) else {
            return nil
        }

        let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.localizedCaseInsensitiveContains("Bearer ") else {
            return nil
        }
        return trimmed
    }

    private static func extractHeader(named headerName: String, from rawText: String) -> String? {
        let headerPrefix = "\(headerName):"

        for quotedHeader in quotedCurlHeaders(from: rawText) {
            if quotedHeader.range(of: headerPrefix, options: [.caseInsensitive, .anchored]) != nil {
                return String(quotedHeader.dropFirst(headerPrefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        for line in rawText.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.range(of: headerPrefix, options: [.caseInsensitive, .anchored]) != nil {
                return String(trimmed.dropFirst(headerPrefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    private static func quotedCurlHeaders(from text: String) -> [String] {
        let pattern = #"-H\s+(['"])(.*?)\1"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 2,
                  let valueRange = Range(match.range(at: 2), in: text)
            else {
                return nil
            }

            return String(text[valueRange])
        }
    }
}

enum CodexAnalyticsParser {
    static func parseWhamUsage(data: Data, diagnosticsEnabled: Bool = false) throws -> CodexUsageData {
        guard let rootObject = try? JSONSerialization.jsonObject(with: data),
              let payload = whamPayloadDictionary(from: rootObject)
        else {
            if diagnosticsEnabled, let text = String(data: data, encoding: .utf8) {
                NSLog("[Codex] Usage API JSON parse failed body=%@", sanitizedBodyPreview(text))
            }
            throw UsageServiceError.apiError("Could not decode Codex usage API response.")
        }

        var details: [UsageDetail] = []
        var fiveHour: Double?
        var weekly: Double?
        var fiveHourReset: String?
        var weeklyReset: String?

        let rateLimit = payload["rate_limit"] as? [String: Any]
        if let primary = rateLimit?["primary_window"] as? [String: Any] {
            let metric = metric(from: primary, labelPrefix: nil)
            if metric.window == .fiveHour {
                fiveHour = metric.used
                fiveHourReset = metric.resetLabel
            } else if metric.window == .weekly {
                weekly = metric.used
                weeklyReset = metric.resetLabel
            }
        }

        if let secondary = rateLimit?["secondary_window"] as? [String: Any] {
            let metric = metric(from: secondary, labelPrefix: nil)
            if metric.window == .fiveHour {
                fiveHour = metric.used
                fiveHourReset = metric.resetLabel
            } else if metric.window == .weekly {
                weekly = metric.used
                weeklyReset = metric.resetLabel
            }
        }

        for additional in payload["additional_rate_limits"] as? [[String: Any]] ?? [] {
            let name = (additional["limit_name"] as? String ?? "Codex")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }

            let additionalRateLimit = additional["rate_limit"] as? [String: Any]
            if let primary = additionalRateLimit?["primary_window"] as? [String: Any] {
                let metric = metric(from: primary, labelPrefix: name)
                details.append(UsageDetail(label: metric.displayLabel, percent: metric.used))
            }

            if let secondary = additionalRateLimit?["secondary_window"] as? [String: Any] {
                let metric = metric(from: secondary, labelPrefix: name)
                details.append(UsageDetail(label: metric.displayLabel, percent: metric.used))
            }
        }

        if let codeReview = payload["code_review_rate_limit"] as? [String: Any],
           let codeReviewWindow = codeReview["primary_window"] as? [String: Any] {
            let metric = metric(from: codeReviewWindow, labelPrefix: "Code review")
            details.append(UsageDetail(label: metric.displayLabel, percent: metric.used))
        }

        let credits = payload["credits"] as? [String: Any]
        let creditBalance = number(from: credits?["balance"])
        let planName = payload["plan_type"] as? String

        if diagnosticsEnabled {
            NSLog(
                "[Codex] Usage API parsed 5h used=%@ weekly used=%@ additionalLimits=%d credits=%@",
                fiveHour.map { String(format: "%.1f%%", $0) } ?? "nil",
                weekly.map { String(format: "%.1f%%", $0) } ?? "nil",
                details.count,
                creditBalance.map { String(format: "%.0f", $0) } ?? "nil"
            )
            for detail in details.prefix(8) {
                NSLog("[Codex] Usage detail %@=%d%% used", detail.modelCode, detail.usage)
            }
        }

        guard fiveHour != nil || weekly != nil || !details.isEmpty else {
            throw UsageServiceError.apiError("Codex usage API returned no rate limit windows.")
        }

        return CodexUsageData(
            fiveHourRemainingPercentage: fiveHour,
            weeklyRemainingPercentage: weekly,
            fiveHourResetLabel: fiveHourReset,
            weeklyResetLabel: weeklyReset,
            planName: planName,
            totalTasks: nil,
            creditsUsed: creditBalance.map { Int($0.rounded()) },
            details: details
        )
    }

    static func parse(data: Data, diagnosticsEnabled: Bool = false) throws -> CodexUsageData {
        var candidates: [MetricCandidate] = []
        var planName: String?
        var totalTasks: Int?
        var creditsUsed: Int?

        if let json = try? JSONSerialization.jsonObject(with: data) {
            collect(from: json, path: [], candidates: &candidates, planName: &planName, totalTasks: &totalTasks, creditsUsed: &creditsUsed)
        }

        if let text = String(data: data, encoding: .utf8) {
            if diagnosticsEnabled {
                let lowerText = text.lowercased()
                NSLog(
                    "[Codex] Body markers codex=%@ analytics=%@ remaining=%@ weekly=%@ login=%@ challenge=%@",
                    String(lowerText.contains("codex")),
                    String(lowerText.contains("analytics")),
                    String(lowerText.contains("remaining") || lowerText.contains("remain")),
                    String(lowerText.contains("weekly") || lowerText.contains("week")),
                    String(lowerText.contains("login") || lowerText.contains("sign in")),
                    String(lowerText.contains("challenge") || lowerText.contains("cloudflare"))
                )
                logDiscovery(from: text)
            }

            collectTextMetrics(text, path: "document", candidates: &candidates, planName: &planName, totalTasks: &totalTasks, creditsUsed: &creditsUsed)

            for object in extractJSONObjects(from: text) {
                collect(from: object, path: ["document"], candidates: &candidates, planName: &planName, totalTasks: &totalTasks, creditsUsed: &creditsUsed)
            }
        }

        if diagnosticsEnabled {
            logCandidates(candidates)
        }

        let fiveHour = bestMetric(for: .fiveHour, from: candidates)
        let weekly = bestMetric(for: .weekly, from: candidates)
        let details = candidates
            .filter { $0.window == .fiveHour || $0.window == .weekly }
            .sorted { $0.confidence > $1.confidence }
            .prefix(4)
            .map { UsageDetail(label: $0.label, percent: $0.remainingPercentage) }

        guard fiveHour != nil || weekly != nil else {
            throw UsageServiceError.apiError("Could not find Codex 5h or weekly limit percentages in the analytics response.")
        }

        return CodexUsageData(
            fiveHourRemainingPercentage: fiveHour,
            weeklyRemainingPercentage: weekly,
            fiveHourResetLabel: nil,
            weeklyResetLabel: nil,
            planName: planName,
            totalTasks: totalTasks,
            creditsUsed: creditsUsed,
            details: Array(details)
        )
    }

    private static func bestMetric(for window: MetricWindow, from candidates: [MetricCandidate]) -> Double? {
        candidates
            .filter { $0.window == window }
            .sorted { $0.confidence > $1.confidence }
            .first?
            .remainingPercentage
    }

    private static func collect(
        from value: Any,
        path: [String],
        candidates: inout [MetricCandidate],
        planName: inout String?,
        totalTasks: inout Int?,
        creditsUsed: inout Int?
    ) {
        if let dictionary = value as? [String: Any] {
            for (key, nestedValue) in dictionary {
                let nextPath = path + [key]
                inspect(key: key, value: nestedValue, path: nextPath, candidates: &candidates, planName: &planName, totalTasks: &totalTasks, creditsUsed: &creditsUsed)
                collect(from: nestedValue, path: nextPath, candidates: &candidates, planName: &planName, totalTasks: &totalTasks, creditsUsed: &creditsUsed)
            }
        } else if let array = value as? [Any] {
            for (index, nestedValue) in array.enumerated() {
                collect(from: nestedValue, path: path + ["[\(index)]"], candidates: &candidates, planName: &planName, totalTasks: &totalTasks, creditsUsed: &creditsUsed)
            }
        } else if let string = value as? String {
            collectTextMetrics(string, path: path.joined(separator: "."), candidates: &candidates, planName: &planName, totalTasks: &totalTasks, creditsUsed: &creditsUsed)

            if let nested = decodeJSONString(string) {
                collect(from: nested, path: path + ["jsonString"], candidates: &candidates, planName: &planName, totalTasks: &totalTasks, creditsUsed: &creditsUsed)
            }
        }
    }

    private static func inspect(
        key: String,
        value: Any,
        path: [String],
        candidates: inout [MetricCandidate],
        planName: inout String?,
        totalTasks: inout Int?,
        creditsUsed: inout Int?
    ) {
        let pathText = path.joined(separator: ".")
        let lowerPath = pathText.lowercased()

        guard !isConfigFlagPath(lowerPath) else { return }

        if planName == nil, let string = value as? String, lowerPath.contains("plan") {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed.count < 80 {
                planName = trimmed
            }
        }

        guard let number = numericValue(value) else { return }

        if totalTasks == nil, lowerPath.contains("task"), !lowerPath.contains("limit"), number >= 0 {
            totalTasks = Int(number.rounded())
        }

        if creditsUsed == nil, lowerPath.contains("credit"), (lowerPath.contains("used") || lowerPath.contains("usage")), number >= 0 {
            creditsUsed = Int(number.rounded())
        }

        guard lowerPath.contains("percent")
            || lowerPath.contains("usage")
            || lowerPath.contains("used")
            || lowerPath.contains("remaining")
            || lowerPath.contains("limit")
            || lowerPath.contains("quota")
        else {
            return
        }

        guard let window = MetricWindow(path: lowerPath) else { return }

        let rawPercent = normalizePercent(number)
        guard rawPercent >= 0, rawPercent <= 100 else { return }

        let isRemaining = lowerPath.contains("remaining") || lowerPath.contains("remain")
        let remaining = isRemaining ? rawPercent : 100 - rawPercent
        let label = window == .fiveHour ? "5h Remaining" : "Weekly Remaining"

        candidates.append(
            MetricCandidate(
                window: window,
                remainingPercentage: clampPercent(remaining),
                label: label,
                confidence: confidence(for: lowerPath, isRemaining: isRemaining),
                source: compactSource(pathText)
            )
        )
    }

    private static func collectTextMetrics(
        _ text: String,
        path: String,
        candidates: inout [MetricCandidate],
        planName: inout String?,
        totalTasks: inout Int?,
        creditsUsed: inout Int?
    ) {
        let decoded = text
            .replacingOccurrences(of: "\\u0025", with: "%")
            .replacingOccurrences(of: "\\u002D", with: "-")
            .replacingOccurrences(of: "\\/", with: "/")

        for match in regexMatches(
            pattern: #"(?i)(5\s*[- ]?\s*h(?:our)?|five\s*[- ]?\s*hour)[^0-9]{0,80}([0-9]+(?:\.[0-9]+)?)\s*%"#,
            text: decoded
        ) {
            if let raw = Double(match[2]), let context = matchContext(for: match[0], in: decoded) {
                guard context.hasLimitContext else { continue }
                let isRemaining = context.isRemainingContext
                let percent = isRemaining ? raw : 100 - raw
                candidates.append(MetricCandidate(
                    window: .fiveHour,
                    remainingPercentage: clampPercent(percent),
                    label: "5h Remaining",
                    confidence: isRemaining ? 80 : 45,
                    source: "\(path).text"
                ))
            }
        }

        for match in regexMatches(
            pattern: #"(?i)(weekly|week)[^0-9]{0,80}([0-9]+(?:\.[0-9]+)?)\s*%"#,
            text: decoded
        ) {
            if let raw = Double(match[2]), let context = matchContext(for: match[0], in: decoded) {
                guard context.hasLimitContext else { continue }
                let isRemaining = context.isRemainingContext
                let percent = isRemaining ? raw : 100 - raw
                candidates.append(MetricCandidate(
                    window: .weekly,
                    remainingPercentage: clampPercent(percent),
                    label: "Weekly Remaining",
                    confidence: isRemaining ? 80 : 45,
                    source: "\(path).text"
                ))
            }
        }

        if planName == nil,
           let match = regexMatches(pattern: #"(?i)\b(ChatGPT\s+(Plus|Pro|Team|Business|Enterprise|Edu))\b"#, text: decoded).first {
            planName = match[1]
        }

        if totalTasks == nil,
           let match = regexMatches(pattern: #"(?i)(tasks?|messages?)[^0-9]{0,40}([0-9]+)"#, text: decoded).first,
           let count = Int(match[2]) {
            totalTasks = count
        }

        if creditsUsed == nil,
           let match = regexMatches(pattern: #"(?i)(credits?)[^0-9]{0,40}([0-9]+)"#, text: decoded).first,
           let count = Int(match[2]) {
            creditsUsed = count
        }
    }

    private static func extractJSONObjects(from text: String) -> [Any] {
        let chars = Array(text)
        var objects: [Any] = []
        var index = 0

        while index < chars.count && objects.count < 40 {
            guard chars[index] == "{" || chars[index] == "[" else {
                index += 1
                continue
            }

            let opener = chars[index]
            let closer: Character = opener == "{" ? "}" : "]"
            var depth = 0
            var cursor = index
            var isInString = false
            var isEscaped = false

            while cursor < chars.count {
                let char = chars[cursor]

                if isEscaped {
                    isEscaped = false
                } else if char == "\\" {
                    isEscaped = true
                } else if char == "\"" {
                    isInString.toggle()
                } else if !isInString {
                    if char == opener {
                        depth += 1
                    } else if char == closer {
                        depth -= 1
                        if depth == 0 {
                            let snippet = String(chars[index...cursor])
                            if let data = snippet.data(using: .utf8),
                               let object = try? JSONSerialization.jsonObject(with: data) {
                                objects.append(object)
                            }
                            break
                        }
                    }
                }

                cursor += 1
            }

            index = max(cursor + 1, index + 1)
        }

        return objects
    }

    private static func decodeJSONString(_ string: String) -> Any? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{" || trimmed.first == "[" else { return nil }
        guard let data = trimmed.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func regexMatches(pattern: String, text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        return regex.matches(in: text, range: range).map { result in
            (0..<result.numberOfRanges).map { index in
                let nsRange = result.range(at: index)
                guard let range = Range(nsRange, in: text) else { return "" }
                return String(text[range])
            }
        }
    }

    private static func matchContext(for match: String, in text: String) -> (hasLimitContext: Bool, isRemainingContext: Bool)? {
        guard let range = text.range(of: match) else { return nil }
        let lowerBound = text.index(range.lowerBound, offsetBy: -160, limitedBy: text.startIndex) ?? text.startIndex
        let upperBound = text.index(range.upperBound, offsetBy: 160, limitedBy: text.endIndex) ?? text.endIndex
        let context = String(text[lowerBound..<upperBound]).lowercased()

        let hasLimitContext = context.contains("limit")
            || context.contains("remaining")
            || context.contains("remain")
            || context.contains("rate")
            || context.contains("usage")
            || context.contains("quota")
        let isRemainingContext = context.contains("remaining") || context.contains("remain")

        return (hasLimitContext, isRemainingContext)
    }

    private static func numericValue(_ value: Any) -> Double? {
        if value is Bool { return nil }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return nil
            }
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string.trimmingCharacters(in: CharacterSet(charactersIn: "% ")))
        }
        return nil
    }

    private static func isConfigFlagPath(_ path: String) -> Bool {
        path.contains("statsig")
            || path.contains("layer_config")
            || path.contains("dynamic_config")
            || path.contains("feature")
            || path.contains("experiment")
            || path.contains("rollout")
            || path.contains("enabled")
            || path.contains("disabled")
            || path.contains("cooldown_enabled")
    }

    private static func normalizePercent(_ value: Double) -> Double {
        if value > 0, value <= 1 {
            return value * 100
        }
        return value
    }

    private static func clampPercent(_ percent: Double) -> Double {
        min(100, max(0, percent))
    }

    private static func confidence(for path: String, isRemaining: Bool) -> Int {
        var score = 40
        if path.contains("percent") { score += 20 }
        if path.contains("usage") || path.contains("used") { score += 15 }
        if path.contains("remaining") || path.contains("remain") { score += 15 }
        if path.contains("limit") || path.contains("quota") { score += 10 }
        if isRemaining { score += 5 }
        return score
    }

    private static func compactSource(_ source: String) -> String {
        if source.count <= 140 {
            return source
        }

        let end = source.suffix(140)
        return "...\(end)"
    }

    private static func logCandidates(_ candidates: [MetricCandidate]) {
        let sorted = candidates.sorted { $0.confidence > $1.confidence }.prefix(12)
        NSLog("[Codex] Parser candidates count=%d", candidates.count)

        for candidate in sorted {
            let window = candidate.window == .fiveHour ? "5h" : "weekly"
            NSLog(
                "[Codex] Candidate window=%@ remaining=%.1f%% confidence=%d source=%@",
                window,
                candidate.remainingPercentage,
                candidate.confidence,
                candidate.source
            )
        }
    }

    private static func logDiscovery(from text: String) {
        let assetMatches = regexMatches(
            pattern: #"(?i)(?:src|href)="([^"]*(?:codex|analytics)[^"]*)""#,
            text: text
        )
        let assets = Array(Set(assetMatches.compactMap { $0.count > 1 ? $0[1] : nil })).sorted().prefix(20)
        NSLog("[Codex] Discovery assets count=%d", assets.count)
        for asset in assets {
            NSLog("[Codex] Discovery asset=%@", asset)
        }

        let pathMatches = regexMatches(
            pattern: #"(?i)(/(?:backend-api|api|codex|gizmo|settings)[^"' <>()\\]{0,180}(?:analytics|usage|limit|rate|codex)[^"' <>()\\]{0,180})"#,
            text: text
        )
        let paths = Array(Set(pathMatches.compactMap { $0.count > 1 ? $0[1] : nil })).sorted().prefix(30)
        NSLog("[Codex] Discovery paths count=%d", paths.count)
        for path in paths {
            NSLog("[Codex] Discovery path=%@", path)
        }

        for needle in ["5 hour usage limit", "weekly usage limit", "remaining", "rate limit"] {
            if let snippet = sanitizedSnippet(around: needle, in: text) {
                NSLog("[Codex] Discovery snippet[%@]=%@", needle, snippet)
            }
        }
    }

    private static func sanitizedSnippet(around needle: String, in text: String) -> String? {
        guard let range = text.range(of: needle, options: [.caseInsensitive]) else { return nil }
        let lowerBound = text.index(range.lowerBound, offsetBy: -120, limitedBy: text.startIndex) ?? text.startIndex
        let upperBound = text.index(range.upperBound, offsetBy: 180, limitedBy: text.endIndex) ?? text.endIndex
        let raw = String(text[lowerBound..<upperBound])
        return raw
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func metric(from window: [String: Any], labelPrefix: String?) -> (window: MetricWindow?, label: String, displayLabel: String, used: Double, resetLabel: String?) {
        let used = clampPercent(number(from: window["used_percent"]) ?? 0)
        let resetLabel = resetLabel(from: window)
        let metricWindow = MetricWindow(windowSeconds: number(from: window["limit_window_seconds"]))
        let windowLabel: String

        switch metricWindow {
        case .fiveHour:
            windowLabel = "5h"
        case .weekly:
            windowLabel = "Weekly"
        case nil:
            windowLabel = "Usage"
        }

        let label: String
        if let labelPrefix {
            label = "\(labelPrefix) \(windowLabel)"
        } else {
            label = windowLabel == "Usage" ? "Usage" : "\(windowLabel) Usage"
        }

        let displayLabel = resetLabel.map { "\(label) • \($0)" } ?? label
        return (metricWindow, label, displayLabel, used, resetLabel)
    }

    private static func sanitizedBodyPreview(_ text: String) -> String {
        String(text.prefix(800))
            .replacingOccurrences(of: #""[^"]*(token|cookie|clearance|puid|email|user_id|account_id)[^"]*"\s*:\s*"[^"]*""#, with: #""$1":"[REDACTED]""#, options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func whamPayloadDictionary(from object: Any) -> [String: Any]? {
        if let dictionary = object as? [String: Any] {
            if let data = dictionary["data"] as? [String: Any] {
                return data
            }
            return dictionary
        }
        return nil
    }

    private static func number(from value: Any?) -> Double? {
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return nil
            }
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string)
        }
        return nil
    }

    private static func resetLabel(from window: [String: Any]) -> String? {
        if let resetAt = number(from: window["reset_at"]) {
            let date = Date(timeIntervalSince1970: resetAt)
            return "resets \(date.formatted(date: .omitted, time: .shortened))"
        }

        guard let seconds = number(from: window["reset_after_seconds"]), seconds > 0 else {
            return nil
        }

        if seconds < 3_600 {
            return "resets in \(Int(ceil(seconds / 60)))m"
        }
        if seconds < 86_400 {
            return "resets in \(Int(ceil(seconds / 3_600)))h"
        }
        return "resets in \(Int(ceil(seconds / 86_400)))d"
    }
}

private enum MetricWindow {
    case fiveHour
    case weekly

    init?(path: String) {
        if path.contains("5h")
            || path.contains("5_h")
            || path.contains("five")
            || path.contains("session")
            || path.contains("short") {
            self = .fiveHour
        } else if path.contains("week") {
            self = .weekly
        } else {
            return nil
        }
    }

    init?(windowSeconds: Double?) {
        guard let windowSeconds else { return nil }

        let fiveHours = 18_000.0
        let week = 604_800.0

        if windowSeconds >= fiveHours * 0.95 && windowSeconds <= fiveHours * 1.05 {
            self = .fiveHour
        } else if windowSeconds >= week * 0.95 && windowSeconds <= week * 1.05 {
            self = .weekly
        } else {
            return nil
        }
    }
}

private struct MetricCandidate {
    let window: MetricWindow
    let remainingPercentage: Double
    let label: String
    let confidence: Int
    let source: String
}

private struct CodexWhamUsageWrappedPayload: Decodable {
    let data: CodexWhamUsagePayload
}

private struct CodexWhamUsagePayload: Decodable {
    let rateLimit: CodexWhamRateLimit?
    let codeReviewRateLimit: CodexWhamRateLimit?
    let additionalRateLimits: [CodexWhamAdditionalRateLimit]?
    let credits: CodexWhamCredits?

    enum CodingKeys: String, CodingKey {
        case rateLimit = "rate_limit"
        case codeReviewRateLimit = "code_review_rate_limit"
        case additionalRateLimits = "additional_rate_limits"
        case credits
    }
}

private struct CodexWhamRateLimit: Decodable {
    let primaryWindow: CodexWhamUsageWindow?
    let secondaryWindow: CodexWhamUsageWindow?

    enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
}

private struct CodexWhamUsageWindow: Decodable {
    let usedPercent: Double?
    let resetAfterSeconds: Double?
    let limitWindowSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case resetAfterSeconds = "reset_after_seconds"
        case limitWindowSeconds = "limit_window_seconds"
    }
}

private struct CodexWhamAdditionalRateLimit: Decodable {
    let limitName: String
    let rateLimit: CodexWhamRateLimit?

    enum CodingKeys: String, CodingKey {
        case limitName = "limit_name"
        case rateLimit = "rate_limit"
    }
}

private struct CodexWhamCredits: Decodable {
    let balance: Double?
}

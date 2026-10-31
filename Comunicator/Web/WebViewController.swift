import AppKit
import os
import WebKit

private let logger = Logger(subsystem: "com.comunicator.app", category: "WebViewController")

@MainActor
protocol WebViewControllerDelegate: AnyObject {
    func webViewController(_ controller: WebViewController, didUpdateTitle title: String?)
    func webViewController(_ controller: WebViewController, didReportUnread count: Int, title: String?)
}

/// Allowed URL schemes for external links opened via target=_blank or popups.
private let allowedExternalSchemes: Set<String> = ["http", "https", "mailto", "tel"]

/// Bridges WKScriptMessageHandler (nonisolated) into the main-actor WebViewController.
private final class UnreadMessageProxy: NSObject, WKScriptMessageHandler {
    weak var owner: WebViewController?
    let allowedHost: String?

    init(allowedHost: String?) {
        self.allowedHost = allowedHost
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == UnreadScript.messageHandlerName,
              let body = message.body as? [String: Any],
              message.frameInfo.isMainFrame
        else { return }

        if let allowedHost, !message.frameInfo.securityOrigin.host.hasSuffix(allowedHost) {
            return
        }

        let unread = body["unread"] as? Int ?? 0
        let title = body["title"] as? String

        Task { @MainActor in
            self.owner?.handleUnreadMessage(unread: unread, title: title)
        }
    }
}

@MainActor
final class WebViewController: NSObject {
    let tabId: UUID
    let profile: AccountProfile
    let webView: WKWebView
    let serviceHost: String?
    let allowedHosts: Set<String>

    weak var delegate: WebViewControllerDelegate?

    private let unreadProxy: UnreadMessageProxy
    /// Retained for safe handler removal from `deinit` without hopping to MainActor.
    private let userContentController: WKUserContentController
    private var didTeardown = false

    /// Tracks whether a process crash occurred, to prevent reload loops.
    private var crashCount = 0
    private let maxCrashRetries = 3

    /// Current load error state for UI display.
    private(set) var loadError: Error?

    init(tabId: UUID, profile: AccountProfile, service: ServiceDefinition? = nil, userAgent: String? = nil) {
        self.tabId = tabId
        self.profile = profile

        let resolvedURL = profile.resolvedURL(using: service.map { [$0] } ?? [])
        self.serviceHost = resolvedURL?.host
        self.allowedHosts = service?.allowedHostsSet ?? Set()

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore(forIdentifier: profile.id)
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences.isElementFullscreenEnabled = true

        let userContent = config.userContentController
        self.userContentController = userContent
        let script = WKUserScript(
            source: UnreadScript.source,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        userContent.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true

        let resolvedUA = userAgent
            ?? service?.preferredUserAgent
            ?? UserAgents.safariMac
        webView.customUserAgent = resolvedUA

        self.webView = webView
        self.unreadProxy = UnreadMessageProxy(allowedHost: resolvedURL?.host)
        super.init()

        unreadProxy.owner = self
        userContent.add(unreadProxy, name: UnreadScript.messageHandlerName)
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    deinit {
        // Message handler removal happens in teardown(); AppModel always calls it on close/delete.
    }

    func load(url: URL) {
        webView.load(URLRequest(url: url))
    }

    func reload() {
        webView.reload()
    }

    func handleUnreadMessage(unread: Int, title: String?) {
        delegate?.webViewController(self, didUpdateTitle: title ?? webView.title)
        delegate?.webViewController(self, didReportUnread: unread, title: title)
    }

    func clearWebsiteData(completion: (@Sendable () -> Void)? = nil) {
        let store = webView.configuration.websiteDataStore
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        store.fetchDataRecords(ofTypes: types) { records in
            store.removeData(ofTypes: types, for: records) {
                DispatchQueue.main.async { completion?() }
            }
        }
    }

    func teardown() {
        guard !didTeardown else { return }
        didTeardown = true
        webView.configuration.userContentController.removeScriptMessageHandler(forName: UnreadScript.messageHandlerName)
        unreadProxy.owner = nil
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        delegate = nil
        webView.stopLoading()
    }

    private func attachDownload(_ download: WKDownload) {
        download.delegate = self
    }
}

// MARK: - Navigation

extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadError = nil
        crashCount = 0
        delegate?.webViewController(self, didUpdateTitle: webView.title)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        loadError = error
        logger.error("Provisional navigation failed: \(error.localizedDescription)")
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        loadError = error
        logger.error("Navigation failed: \(error.localizedDescription)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        crashCount += 1
        logger.warning("Web content process terminated (crash #\(self.crashCount))")
        if crashCount <= maxCrashRetries {
            webView.reload()
        } else {
            loadError = NSError(
                domain: "com.comunicator.app",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Page crashed repeatedly. Try reloading manually."]
            )
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }

        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url,
           navigationAction.targetFrame == nil {
            openExternalURLIfAllowed(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if navigationResponse.canShowMIMEType {
            decisionHandler(.allow)
        } else {
            decisionHandler(.download)
        }
    }

    func webView(
        _ webView: WKWebView,
        navigationAction: WKNavigationAction,
        didBecome download: WKDownload
    ) {
        attachDownload(download)
    }

    func webView(
        _ webView: WKWebView,
        navigationResponse: WKNavigationResponse,
        didBecome download: WKDownload
    ) {
        attachDownload(download)
    }

    private func openExternalURLIfAllowed(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(),
              allowedExternalSchemes.contains(scheme)
        else {
            logger.warning("Blocked external URL with disallowed scheme: \(url.scheme ?? "nil")")
            return
        }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Downloads

extension WebViewController: WKDownloadDelegate {
    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedFilename
        panel.title = "Save Download"
        panel.prompt = "Save"

        let present: () -> Void = {
            guard let window = self.webView.window ?? NSApp.keyWindow else {
                // Fall back to Downloads folder when no window is available.
                let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                let dest = downloads?.appendingPathComponent(suggestedFilename)
                completionHandler(dest)
                return
            }

            panel.beginSheetModal(for: window) { result in
                if result == .OK, let url = panel.url {
                    completionHandler(url)
                } else {
                    completionHandler(nil)
                }
            }
        }

        if Thread.isMainThread {
            present()
        } else {
            DispatchQueue.main.async {
                present()
            }
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        logger.error("Download failed: \(error.localizedDescription)")
    }

    func downloadDidFinish(_ download: WKDownload) {
        logger.info("Download completed successfully")
    }
}

// MARK: - UI

extension WebViewController: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }

        if shouldOpenInBrowser(url: url, from: navigationAction) {
            openExternalURLIfAllowed(url)
            return nil
        }

        webView.load(URLRequest(url: url))
        return nil
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let origin = frame.securityOrigin.host
        showJavaScriptDialog(
            title: "Message from \(origin)",
            message: message,
            buttons: ["OK"]
        ) { _ in
            completionHandler()
        }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let origin = frame.securityOrigin.host
        showJavaScriptDialog(
            title: "Confirm from \(origin)",
            message: message,
            buttons: ["OK", "Cancel"]
        ) { response in
            completionHandler(response == .alertFirstButtonReturn)
        }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let origin = frame.securityOrigin.host
        let alert = NSAlert()
        alert.messageText = "Prompt from \(origin)"
        alert.informativeText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        textField.stringValue = defaultText ?? ""
        alert.accessoryView = textField

        if let window = webView.window {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    completionHandler(textField.stringValue)
                } else {
                    completionHandler(nil)
                }
            }
        } else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                completionHandler(textField.stringValue)
            } else {
                completionHandler(nil)
            }
        }
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.title = "Select File"
        panel.prompt = "Choose"

        let present: (NSWindow?) -> Void = { window in
            let handler: (NSApplication.ModalResponse) -> Void = { result in
                if result == .OK {
                    completionHandler(panel.urls)
                } else {
                    completionHandler(nil)
                }
            }

            if let window {
                panel.beginSheetModal(for: window, completionHandler: handler)
            } else {
                let result = panel.runModal()
                handler(result)
            }
        }

        if Thread.isMainThread {
            present(webView.window ?? NSApp.keyWindow)
        } else {
            DispatchQueue.main.async {
                present(webView.window ?? NSApp.keyWindow)
            }
        }
    }

    @available(macOS 12.0, *)
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        guard frame.isMainFrame else {
            logger.warning("Denied media capture from non-main frame: \(origin.host)")
            decisionHandler(.deny)
            return
        }

        guard isAllowedOrigin(origin.host) else {
            logger.warning("Prompting for media capture from non-service origin: \(origin.host)")
            decisionHandler(.prompt)
            return
        }

        decisionHandler(.grant)
    }

    private func isAllowedOrigin(_ host: String) -> Bool {
        if let serviceHost, host.hasSuffix(serviceHost) {
            return true
        }
        return allowedHosts.contains(where: { host.hasSuffix($0) })
    }

    private func shouldOpenInBrowser(url: URL, from action: WKNavigationAction) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return true }
        guard scheme == "http" || scheme == "https" else { return true }

        guard let host = url.host?.lowercased() else { return true }

        if let serviceHost, host.hasSuffix(serviceHost) {
            return false
        }

        if allowedHosts.contains(where: { host.hasSuffix($0) }) {
            return false
        }

        return true
    }

    private func showJavaScriptDialog(
        title: String,
        message: String,
        buttons: [String],
        completion: @escaping (NSApplication.ModalResponse) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        for button in buttons {
            alert.addButton(withTitle: button)
        }

        if let window = webView.window {
            alert.beginSheetModal(for: window, completionHandler: completion)
        } else {
            let response = alert.runModal()
            completion(response)
        }
    }
}

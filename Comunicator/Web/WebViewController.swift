import AppKit
import WebKit

@MainActor
protocol WebViewControllerDelegate: AnyObject {
    func webViewController(_ controller: WebViewController, didUpdateTitle title: String?)
    func webViewController(_ controller: WebViewController, didReportUnread count: Int, title: String?)
}

/// Bridges WKScriptMessageHandler (nonisolated) into the main-actor WebViewController.
private final class UnreadMessageProxy: NSObject, WKScriptMessageHandler {
    weak var owner: WebViewController?

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == UnreadScript.messageHandlerName,
              let body = message.body as? [String: Any]
        else { return }

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

    weak var delegate: WebViewControllerDelegate?

    private let unreadProxy = UnreadMessageProxy()
    /// Retained for safe handler removal from `deinit` without hopping to MainActor.
    private let userContentController: WKUserContentController
    private var didTeardown = false

    init(tabId: UUID, profile: AccountProfile, service: ServiceDefinition? = nil, userAgent: String? = nil) {
        self.tabId = tabId
        self.profile = profile

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
            ?? UserAgents.chromeMac
        webView.customUserAgent = resolvedUA

        self.webView = webView
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
        delegate?.webViewController(self, didUpdateTitle: webView.title)
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
            NSWorkspace.shared.open(url)
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
        print("Download failed: \(error.localizedDescription)")
    }

    func downloadDidFinish(_ download: WKDownload) {
        // Success — file was written by WebKit to the chosen destination.
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
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }

    @available(macOS 12.0, *)
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        decisionHandler(.grant)
    }
}

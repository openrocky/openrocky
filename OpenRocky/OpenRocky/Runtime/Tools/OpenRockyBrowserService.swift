//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import UIKit
import WebKit

struct BrowserResult: Sendable {
    let finalURL: String
    let pageTitle: String
}

struct BrowserContentResult: Sendable {
    let url: String
    let title: String
    let textContent: String
}

struct BrowserCookie: Codable, Sendable {
    let name: String
    let value: String
    let domain: String
}

@MainActor
final class OpenRockyBrowserService {
    static let shared = OpenRockyBrowserService()

    // MARK: - Read Content Queue

    private var readQueue: [(url: URL, continuation: CheckedContinuation<BrowserContentResult, Error>)] = []
    private var isProcessingRead = false
    private var totalQueuedCount = 0
    private var currentQueueIndex = 0

    // MARK: - Open URL (interactive, user can login)

    func openURL(_ urlString: String) async throws -> BrowserResult {
        guard let url = URL(string: urlString) else {
            throw BrowserError.invalidURL
        }
        let presenter = try getPresenter()

        return try await withCheckedThrowingContinuation { continuation in
            let vc = OpenRockyBrowserViewController(
                url: url,
                mode: .interactive,
                continuation: continuation
            )
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .pageSheet
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            }
            presenter.present(nav, animated: true)
        }
    }

    // MARK: - Read page content (queued, auto-dismiss)

    func readContent(_ urlString: String) async throws -> BrowserContentResult {
        guard let url = URL(string: urlString) else {
            throw BrowserError.invalidURL
        }

        return try await withCheckedThrowingContinuation { continuation in
            readQueue.append((url: url, continuation: continuation))
            totalQueuedCount = readQueue.count + (isProcessingRead ? 1 : 0)
            processNextRead()
        }
    }

    private func processNextRead() {
        guard !isProcessingRead, let next = readQueue.first else { return }
        readQueue.removeFirst()
        isProcessingRead = true
        currentQueueIndex = totalQueuedCount - readQueue.count

        guard let presenter = try? getPresenter() else {
            isProcessingRead = false
            next.continuation.resume(throwing: BrowserError.noPresenter)
            processNextRead()
            return
        }

        let progress = totalQueuedCount > 1
            ? "Reading \(currentQueueIndex)/\(totalQueuedCount)..."
            : "Reading..."

        let vc = OpenRockyBrowserViewController(
            url: next.url,
            mode: .readContent,
            queueProgress: progress,
            contentContinuation: next.continuation,
            onDismissed: { [weak self] in
                self?.isProcessingRead = false
                if self?.readQueue.isEmpty == true {
                    self?.totalQueuedCount = 0
                    self?.currentQueueIndex = 0
                }
                self?.processNextRead()
            }
        )
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            let compact = UISheetPresentationController.Detent.custom { context in
                context.maximumDetentValue * 0.45
            }
            sheet.detents = [compact]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.largestUndimmedDetentIdentifier = compact.identifier
        }
        presenter.present(nav, animated: true)
    }

    // MARK: - Get cookies for domain

    func getCookies(for domain: String) async throws -> [BrowserCookie] {
        let store = WKWebsiteDataStore.default().httpCookieStore
        let cookies = await store.allCookies()
        return cookies
            .filter { $0.domain.contains(domain) }
            .map { BrowserCookie(name: $0.name, value: $0.value, domain: $0.domain) }
    }

    // MARK: - Helpers

    private func getPresenter() throws -> UIViewController {
        guard let vc = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController else {
            throw BrowserError.noPresenter
        }
        var top = vc
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    enum BrowserError: Error, LocalizedError {
        case invalidURL
        case noPresenter
        case timeout
        case cancelled

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .noPresenter: return "No view controller available"
            case .timeout: return "Page load timed out"
            case .cancelled: return "Browser was cancelled"
            }
        }
    }
}

// MARK: - Browser View Controller

final class OpenRockyBrowserViewController: UIViewController, WKNavigationDelegate {
    enum Mode {
        case interactive
        case readContent
    }

    private let url: URL
    private let mode: Mode
    private let queueProgress: String?
    private var interactiveContinuation: CheckedContinuation<BrowserResult, Error>?
    private var contentContinuation: CheckedContinuation<BrowserContentResult, Error>?
    private var onDismissed: (() -> Void)?
    private let webView: WKWebView
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let statusLabel = UILabel()
    private var progressObservation: NSKeyValueObservation?
    private var extractionTimer: Timer?
    private var didResume = false

    init(
        url: URL,
        mode: Mode,
        queueProgress: String? = nil,
        continuation: CheckedContinuation<BrowserResult, Error>? = nil,
        contentContinuation: CheckedContinuation<BrowserContentResult, Error>? = nil,
        onDismissed: (() -> Void)? = nil
    ) {
        self.url = url
        self.mode = mode
        self.queueProgress = queueProgress
        self.interactiveContinuation = continuation
        self.contentContinuation = contentContinuation
        self.onDismissed = onDismissed

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        self.webView = WKWebView(frame: .zero, configuration: config)

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.tintColor = .systemBlue
        progressView.trackTintColor = .clear
        view.addSubview(progressView)

        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),

            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        progressObservation = webView.observe(\.estimatedProgress, options: .new) { [weak self] _, change in
            guard let newValue = change.newValue else { return }
            let progress = Float(newValue)
            Task { @MainActor in
                self?.progressView.setProgress(progress, animated: true)
                if progress >= 1.0 {
                    UIView.animate(withDuration: 0.2, delay: 0.2) {
                        self?.progressView.alpha = 0
                    }
                } else {
                    self?.progressView.alpha = 1
                }
            }
        }

        switch mode {
        case .interactive:
            title = url.host ?? "Browser"
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Done",
                style: .prominent,
                target: self,
                action: #selector(doneTapped)
            )
        case .readContent:
            title = queueProgress ?? "Reading..."
            statusLabel.text = "Fetching \(url.host ?? "page")..."
            statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
            statusLabel.textColor = .secondaryLabel
            statusLabel.textAlignment = .center
            navigationItem.titleView = statusLabel
        }

        webView.load(URLRequest(url: url))

        if mode == .readContent {
            extractionTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self, !self.didResume else { return }
                    self.extractContentAndDismiss()
                }
            }
        }
    }

    @objc private func doneTapped() {
        let result = BrowserResult(
            finalURL: webView.url?.absoluteString ?? url.absoluteString,
            pageTitle: webView.title ?? ""
        )
        dismiss(animated: true) { [weak self] in
            guard let self, !self.didResume else { return }
            self.didResume = true
            self.interactiveContinuation?.resume(returning: result)
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        switch mode {
        case .interactive:
            title = webView.title ?? url.host ?? "Browser"
        case .readContent:
            extractContentAndDismiss()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard case .readContent = mode, !didResume else { return }
        resumeWithError(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard case .readContent = mode, !didResume else { return }
        resumeWithError(error)
    }

    private func resumeWithError(_ error: Error) {
        didResume = true
        dismiss(animated: true) { [weak self] in
            self?.contentContinuation?.resume(throwing: error)
            self?.onDismissed?()
        }
    }

    private func extractContentAndDismiss() {
        extractionTimer?.invalidate()
        extractionTimer = nil
        guard !didResume else { return }
        statusLabel.text = "Extracting..."
        let js = """
        (function() {
            var article = document.querySelector('article') || document.querySelector('main') || document.body;
            return article ? article.innerText : document.body.innerText;
        })()
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self, !self.didResume else { return }
            self.didResume = true
            let text = (result as? String) ?? ""
            let contentResult = BrowserContentResult(
                url: self.webView.url?.absoluteString ?? self.url.absoluteString,
                title: self.webView.title ?? "",
                textContent: text
            )
            self.dismiss(animated: true) {
                self.contentContinuation?.resume(returning: contentResult)
                self.onDismissed?()
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        extractionTimer?.invalidate()
        progressObservation?.invalidate()
        guard !didResume else { return }
        didResume = true
        interactiveContinuation?.resume(throwing: OpenRockyBrowserService.BrowserError.cancelled)
        contentContinuation?.resume(throwing: OpenRockyBrowserService.BrowserError.cancelled)
        onDismissed?()
    }
}

//
//  WebViewModel.swift
//  Asobi
//
//  Created by Brian Dashore on 8/3/21.
//

import Combine
import Foundation
import SwiftUI
import WebKit

struct FindInPageResult: Codable {
    let currentIndex: Int
    let totalResultLength: Int
}

@MainActor
class WebViewModel: ObservableObject {
    let webView: WKWebView

    enum ToastType: Identifiable {
        var id: Int {
            hashValue
        }

        case info
        case error
    }

    // All Settings go here
    @AppStorage("blockAds") var blockAds = false
    @AppStorage("changeUserAgent") var changeUserAgent = false
    @AppStorage("incognitoMode") var incognitoMode = false
    @AppStorage("defaultUrl") var defaultUrl = ""
    @AppStorage("allowSwipeNavGestures") var allowSwipeNavGestures = true

    // Make a non mutable fallback URL
    private let fallbackUrl = URL(string: "https://kingbri.dev/asobi")!

    // Has the page loaded once?
    private var firstLoad: Bool = false

    // URL variable for application URL schemes
    @Published var appUrl: URL?

    // History based variables
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false

    // Cosmetic variables
    @Published var showLoadingProgress: Bool = false
    @Published var backgroundColor: UIColor?

    // Toast variables
    @Published var toastDescription: String? = nil
    @Published var showToast: Bool = false

    // Default the toast type to error since the majority of toasts are errors
    @Published var toastType: ToastType = .error

    // Zoom variables
    @Published var isZoomedOut = false
    @Published var userDidZoom = false
    @Published var previousZoomScale: CGFloat = 0

    // Find in page variables
    @Published var findInPageEnabled = true
    @Published var showFindInPage = false
    @Published var findQuery: String = ""
    @Published var currentFindResult: Int = -1
    @Published var totalFindResults: Int = -1

    init() {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs

        // For airplay options to be shown and interacted with
        config.allowsAirPlayForMediaPlayback = true
        config.allowsInlineMediaPlayback = true

        let zoomJs = """
        let viewport = document.querySelector("meta[name=viewport]");

        // Edit the existing viewport, otherwise create a new element
        if (viewport) {
            viewport.setAttribute('content', 'width=device-width, initial-scale=1.0, user-scalable=1');
        } else {
            let meta = document.createElement('meta');
            meta.name = 'viewport'
            meta.content = 'width=device-width, initial-scale=1.0'
            document.head.appendChild(meta)
        }
        """

        let pasteJs = """
        const inputs = document.querySelectorAll("input[type=text]")
        let alreadyPasted = false

        for (const input of inputs) {
          input.addEventListener("paste", (event) => {
            event.preventDefault()

            // Don't call paste event two times in a single paste command
            if (alreadyPasted) {
              alreadyPasted = false
              return
            }

            const paste = (event.clipboardData || window.clipboardData).getData("text")

            const beginningString =
              input.value.substring(0, input.selectionStart) + paste

            input.value =
              beginningString +
              input.value.substring(input.selectionEnd, input.value.length)

            alreadyPasted = true

            input.setSelectionRange(beginningString.length, beginningString.length)

            input.scrollLeft = input.scrollWidth
          })
        }
        """

        if UIDevice.current.deviceType == .mac {
            let pasteEvent = WKUserScript(source: pasteJs, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
            config.userContentController.addUserScript(pasteEvent)
        } else {
            let zoomEvent = WKUserScript(source: zoomJs, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
            config.userContentController.addUserScript(zoomEvent)
        }

        if let path = Bundle.main.path(forResource: "FindInPage", ofType: "js") {
            do {
                let jsString = try String(contentsOfFile: path, encoding: .utf8)
                let findJs = WKUserScript(source: jsString, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
                config.userContentController.addUserScript(findJs)
            } catch {
                toastDescription = "Cannot load the find in page JS code. Find in page is disabled, please try restarting the app."
                showToast = true
                findInPageEnabled = false
            }
        }

        webView = WKWebView(
            frame: .zero,
            configuration: config
        )

        if allowSwipeNavGestures {
            webView.allowsBackForwardNavigationGestures = true
        }

        // Clears the white background on webpage load
        webView.isOpaque = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        setUserAgent(changeUserAgent: changeUserAgent)

        Task {
            // Clears the disk and in-memory cache. Doesn't harm accounts.
            await WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache], modifiedSince: Date(timeIntervalSince1970: 0))

            if blockAds {
                await enableBlocker()
            }
        }

        loadUrl()
        firstLoad = false

        setupBindings()
    }

    private func setupBindings() {
        webView.publisher(for: \.canGoBack)
            .assign(to: &$canGoBack)

        webView.publisher(for: \.canGoForward)
            .assign(to: &$canGoForward)
    }

    // Loads a URL. URL built in the buildURL function
    func loadUrl(_ urlString: String? = nil) {
        let url = buildUrl(urlString)
        let urlRequest = URLRequest(url: url)

        webView.load(urlRequest)
    }

    /*
     Builds the URL from loadUrl
     If the provided string is nil, fall back to the default URL.
     Always prefix a URL with https if not present
     If the default URL is empty, return the fallback URL.
     */
    func buildUrl(_ testString: String?) -> URL {
        if testString == nil, defaultUrl.isEmpty {
            return fallbackUrl
        }

        var urlString = testString ?? defaultUrl

        if !(urlString.contains("://")) {
            urlString = "https://\(urlString)"
        }

        return URL(string: urlString)!
    }

    func goForward() {
        webView.goForward()
    }

    func goBack() {
        webView.goBack()
    }

    func goHome() {
        loadUrl()
    }

    // The user agent will be a variant of safari to enable airplay support everywhere
    func setUserAgent(changeUserAgent: Bool) {
        let mobileUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
        let desktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Safari/605.1.15"

        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            if changeUserAgent {
                webView.customUserAgent = desktopUserAgent
            } else {
                webView.customUserAgent = mobileUserAgent
            }
        case .pad:
            if changeUserAgent {
                webView.customUserAgent = mobileUserAgent
            } else {
                webView.customUserAgent = desktopUserAgent
            }
        default:
            webView.customUserAgent = nil
        }
    }

    func enableBlocker() async {
        guard let blocklistPath = Bundle.main.path(forResource: "blocklist", ofType: "json") else {
            debugPrint("Failed to find blocklist path. Continuing...")
            return
        }

        do {
            let blocklist = try String(contentsOfFile: blocklistPath, encoding: String.Encoding.utf8)

            let contentRuleList = try await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "ContentBlockingRules", encodedContentRuleList: blocklist
            )

            if let ruleList = contentRuleList {
                webView.configuration.userContentController.add(ruleList)
            }
        } catch {
            debugPrint("Blocklist loading failed. \(error.localizedDescription)")
        }

        if !firstLoad {
            webView.reload()
        }
    }

    func disableBlocker() {
        debugPrint("Disabling adblock")

        webView.configuration.userContentController.removeAllContentRuleLists()

        webView.reload()
    }

    func handleFindInPageResult(jsonString: String) {
        guard let jsonData = jsonString.data(using: .utf8) else {
            toastDescription = "Cannot convert find in page JSON into data!"
            showToast = true

            return
        }

        let decoder = JSONDecoder()

        do {
            let result = try decoder.decode(FindInPageResult.self, from: jsonData)
            currentFindResult = result.currentIndex + 1
            totalFindResults = result.totalResultLength
        } catch {
            toastDescription = error.localizedDescription
            showToast = true
        }
    }

    func executeFindInPage() {
        if findQuery.isEmpty, totalFindResults > 0 {
            resetFindInPage()
        }

        if !findQuery.isEmpty {
            webView.evaluateJavaScript("undoFindHighlights()")
            webView.evaluateJavaScript("findAndHighlightQuery(\"\(findQuery)\")")
            webView.evaluateJavaScript("scrollToFindResult(0)")
        }
    }

    func moveFindInPageResult(isIncrementing: Bool) {
        if totalFindResults <= 0 {
            return
        }

        if isIncrementing {
            currentFindResult += 1
        } else {
            currentFindResult -= 1
        }

        if currentFindResult > totalFindResults {
            currentFindResult = 1
        } else if currentFindResult < 1 {
            currentFindResult = totalFindResults
        }

        webView.evaluateJavaScript("scrollToFindResult(\(currentFindResult - 1))")
    }

    func resetFindInPage() {
        currentFindResult = -1
        totalFindResults = -1
        findQuery = ""
        webView.evaluateJavaScript("undoFindHighlights()")
    }

    func clearCookies() async {
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)

        let dataRecords = await WKWebsiteDataStore.default().dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())

        await WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: dataRecords)
    }
}

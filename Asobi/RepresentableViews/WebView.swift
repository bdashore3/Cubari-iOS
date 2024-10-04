//
//  WebView.swift
//  Asobi
//
//  Created by Brian Dashore on 8/2/21.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    @EnvironmentObject var webModel: WebViewModel
    @EnvironmentObject var navModel: NavigationViewModel
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var rootViewController: AsobiRootViewController

    @AppStorage("autoHideNavigation") var autoHideNavigation = false
    @AppStorage("persistNavigation") var persistNavigation = false
    @AppStorage("allowZoom") var allowZoom = true

    @FetchRequest(
        entity: AllowedURLScheme.entity(),
        sortDescriptors: []
    ) var allowedSchemes: FetchedResults<AllowedURLScheme>

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate, WKScriptMessageHandler, WKScriptMessageHandlerWithReply {
        let parent: WebView
        init(_ parent: WebView) {
            self.parent = parent
        }

        // JS message handler
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "blobListener":
                guard let jsonString = message.body as? String else {
                    parent.webModel.toastDescription = "Invalid blob JSON."
                    return
                }

                parent.downloadManager.blobDownloadWith(jsonString: jsonString)
            case "findListener":
                guard let jsonString = message.body as? String else {
                    parent.webModel.toastDescription = "Invalid find in page JSON."
                    return
                }

                parent.webModel.handleFindInPageResult(jsonString: jsonString)
            default:
                debugPrint("Unknown JS message from \(message.name) with body: \(message.body)")
            }
        }

        // JS message handler with replies
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) async -> (Any?, String?) {
            switch message.name {
            case "zoomUnlocker":
                return (parent.allowZoom, nil)
            default:
                debugPrint("Unknown JS message from \(message.name) with body: \(message.body)")
                return (nil, nil)
            }
        }

        // Handle popups from methods like window.open
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            parent.webModel.handlePopup(navigationAction)
            return nil
        }

        // Will check if the user manually zoomed in
        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
            let allowZoom = UserDefaults.standard.bool(forKey: "allowZoom")

            scrollView.pinchGestureRecognizer?.isEnabled = allowZoom
            if UIDevice.current.deviceType != .mac, allowZoom {
                parent.webModel.userDidZoom = true
            }
        }

        // Handle orientation changes here
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            if UIDevice.current.deviceType != .mac, UserDefaults.standard.bool(forKey: "allowZoom") {
                // If the user initiated the zoom, we don't care
                if parent.webModel.userDidZoom {
                    return
                }

                if parent.webModel.isZoomedOut {
                    scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
                } else if scrollView.zoomScale.roundToPlaces(2) > parent.webModel.previousZoomScale.roundToPlaces(2) {
                    // If the scale is zoomed in on an orientation change,
                    // revert back to the previous one saved in model
                    scrollView.setZoomScale(parent.webModel.previousZoomScale, animated: false)
                }
            }
        }

        // Check if the user is zoomed in, used for resetting the zoom level on orientation change
        // Also set the previous zoom level for possible orientation change issues
        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            if UIDevice.current.deviceType != .mac, UserDefaults.standard.bool(forKey: "allowZoom") {
                parent.webModel.userDidZoom = false

                parent.webModel.previousZoomScale = scale
                parent.webModel.isZoomedOut = scale.roundToPlaces(2) <= scrollView.minimumZoomScale.roundToPlaces(2)
            }
        }

        // Navigation delegate methods for ProgressView/errors
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.webModel.showLoadingProgress = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.webModel.showLoadingProgress = false

            parent.webModel.setStatusbarColor()

            if !UserDefaults.standard.bool(forKey: "incognitoMode") {
                parent.webModel.addToHistory()
            }

            // One-shot boolean which makes the webview opaque again
            if parent.webModel.firstLoad {
                parent.webModel.firstLoad = false
                parent.webModel.webView.isOpaque = true
            }
        }

        // Check if a page can be downloaded
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void)
        {
            if navigationResponse.canShowMIMEType {
                decisionHandler(.allow)
            } else {
                parent.downloadManager.downloadUrl = navigationResponse.response.url
                parent.downloadManager.showHttpAlert.toggle()
                decisionHandler(.cancel)
            }
        }

        // Switch based on the URL scheme. All http/https rules get allowed automatically
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
        {
            if let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() {
                switch scheme {
                case "https":
                    if navigationAction.targetFrame == nil {
                        parent.webModel.handlePopup(navigationAction)
                    }

                    decisionHandler(.allow)
                case "http":
                    if UserDefaults.standard.bool(forKey: "httpsOnlyMode") {
                        parent.webModel.toastType = .info
                        parent.webModel.toastDescription = "Https only mode is enabled! Aborting navigation according to your preferences."

                        decisionHandler(.cancel)
                    } else {
                        if navigationAction.targetFrame == nil {
                            parent.webModel.handlePopup(navigationAction)
                        }

                        decisionHandler(.allow)
                    }
                case "blob":
                    // Defer to JS handling
                    parent.downloadManager.executeBlobDownloadJS(url: url)

                    decisionHandler(.cancel)
                case "about":
                    // Usually about:blank, so ignore
                    decisionHandler(.cancel)
                default:
                    if parent.allowedSchemes.contains(where: { $0.scheme?.lowercased() == url.scheme?.lowercased() }), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        parent.webModel.toastDescription =
                            "Cannot navigate to URL with scheme \(String(describing: url.scheme)) because the scheme is not allowed or your device can't open it. \n\n" +
                            "Exceptions can be added in Settings > Allowed URL schemes."
                    }

                    decisionHandler(.cancel)
                }
            } else {
                decisionHandler(.allow)
            }
        }

        // Function for navigation errors
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let error = error as NSError

            parent.webModel.showLoadingProgress = false

            // Error 999 can be ignored since that's an error for loading a cached webpage
            if error.code == -999 {
                return
            }

            parent.webModel.toastDescription = error.localizedDescription
        }

        // Function for any provisional navigation errors
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let error = error as NSError

            parent.webModel.showLoadingProgress = false

            // Error handling switch, more errors will be added if they're unnecessary
            switch error.code {
            // Error -1022 has a special message because we don't allow insecure webpage loads
            case -1022:
                parent.webModel.toastDescription =
                    "Failed to load because this page is insecure! \n" +
                    "Please contact the website dev to fix app transport security protocols!"
            // Error 102 can be ignored since that's used for downloading files
            // Error 999 can be ignored since that's an error for loading a cached webpage
            case 102, -999:
                return
            default:
                parent.webModel.toastDescription = error.localizedDescription
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        // Don't use the async variants of these functions due to passing a completion handler between the WebViewModel
        func webView(_ webView: WKWebView,
                     runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void)
        {
            parent.webModel.webAlertMessage = message
            parent.webModel.webAlertAction = completionHandler
            parent.webModel.presentAlert(.alert)
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (Bool) -> Void)
        {
            parent.webModel.webAlertMessage = message
            parent.webModel.webConfirmAction = completionHandler
            parent.webModel.presentAlert(.confirm)
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void)
        {
            parent.webModel.webAlertMessage = prompt
            parent.webModel.webPromptAction = completionHandler
            parent.webModel.presentAlert(.prompt)
        }

        func webView(_ webView: WKWebView,
                     didReceive challenge: URLAuthenticationChallenge,
                     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
        {
            guard let hostname = webView.url?.host else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }

            let authenticationMethod = challenge.protectionSpace.authenticationMethod
            switch authenticationMethod {
            case NSURLAuthenticationMethodDefault, NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest:
                parent.webModel.webAlertMessage = "\(hostname) is asking for your credentials"
                parent.webModel.webAuthAction = completionHandler
                parent.webModel.presentAlert(.auth)
            case NSURLAuthenticationMethodServerTrust:
                completionHandler(.performDefaultHandling, nil)
            default:
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        }

        @objc func toggleNavigation(_ gestureRecognizer: UIGestureRecognizer) {
            if !parent.persistNavigation {
                parent.navModel.toggleNavigationBar()
            }
        }

        @objc func refreshWebView(_ sender: UIRefreshControl) {
            parent.webModel.webView.reload()
            sender.endRefreshing()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        webModel.webView.configuration.userContentController.add(context.coordinator, contentWorld: .page, name: "blobListener")
        webModel.webView.configuration.userContentController.add(context.coordinator, contentWorld: .page, name: "findListener")
        webModel.webView.configuration.userContentController.addScriptMessageHandler(context.coordinator, contentWorld: .page, name: "zoomUnlocker")

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.toggleNavigation))
        tapGesture.numberOfTapsRequired = (autoHideNavigation && !navModel.isKeyboardShowing) ? 1 : 3
        tapGesture.delegate = context.coordinator
        webModel.webView.addGestureRecognizer(tapGesture)

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(context.coordinator.refreshWebView), for: .valueChanged)
        webModel.webView.scrollView.addSubview(refreshControl)
        webModel.webView.scrollView.bounces = true

        webModel.webView.uiDelegate = context.coordinator
        webModel.webView.navigationDelegate = context.coordinator
        webModel.webView.scrollView.delegate = context.coordinator

        return webModel.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Tap gesture
        if let lastGestureRecognizer = uiView.gestureRecognizers?.last {
            guard let tapGesture: UITapGestureRecognizer = lastGestureRecognizer as? UITapGestureRecognizer else {
                return
            }

            tapGesture.numberOfTapsRequired = (autoHideNavigation && !navModel.isKeyboardShowing) ? 1 : 3
            tapGesture.isEnabled = !persistNavigation
        }
    }
}

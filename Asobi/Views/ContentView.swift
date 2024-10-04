//
//  ContentView.swift
//  Asobi
//
//  Created by Brian Dashore on 8/2/21.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var webModel: WebViewModel
    @EnvironmentObject var navModel: NavigationViewModel
    @EnvironmentObject var downloadManager: DownloadManager

    @AppStorage("autoHideNavigation") var autoHideNavigation = false
    @AppStorage("persistNavigation") var persistNavigation = false
    @AppStorage("useDarkTheme") var useDarkTheme = false
    @AppStorage("followSystemTheme") var followSystemTheme = true
    @AppStorage("navigationAccent") var navigationAccent: Color = .red
    @AppStorage("statusBarPinType") var statusBarPinType: StatusBarBehaviorType = .partialHide
    @AppStorage("showBottomInset") var showBottomInset = false

    var body: some View {
        ZStack {
            // Background color for orientation changes
            Rectangle()
                .fileImporter(isPresented: $downloadManager.showDefaultDirectoryPicker, allowedContentTypes: [UTType.folder]) { result in
                    switch result {
                    case let .success(path):
                        downloadManager.setDefaultDownloadDirectory(downloadPath: path)
                    case let .failure(error):
                        webModel.toastDescription = error.localizedDescription
                    }

                    navModel.currentSheet = .settings
                }
                .foregroundColor(statusBarPinType == .hide ? .clear : webModel.backgroundColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture(count: (autoHideNavigation && !navModel.isKeyboardShowing) ? 1 : 3) {
                    navModel.toggleNavigationBar()
                }
                .ignoresSafeArea()
                .zIndex(0)

            // WebView
            WebView()
                .alert("Download this file?", isPresented: $downloadManager.showHttpAlert) {
                    Button("Start") {
                        if let downloadUrl = downloadManager.downloadUrl {
                            Task {
                                await downloadManager.httpDownloadFrom(url: downloadUrl)
                            }
                        } else {
                            webModel.toastDescription = "The download URL is invalid"
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        downloadManager.downloadUrl = nil
                    }
                } message: {
                    Text("Would you like to start this download?")
                }
                .alert("Keep this file?", isPresented: $downloadManager.showBlobAlert) {
                    Button("Keep") {
                        downloadManager.completeBlobDownload()
                    }
                    Button("Delete", role: .destructive) {
                        downloadManager.deleteBlobDownload()
                    }
                } message: {
                    Text("Would you like keep this downloaded file?")
                }
                .edgesIgnoringSafeArea(statusBarPinType == .hide ? (showBottomInset ? .top : .vertical) : (showBottomInset ? [] : .bottom))
                .zIndex(1)

            Group {
                if let currentWebAlert = webModel.currentWebAlert {
                    Color(uiColor: .darkGray).opacity(0.4)

                    switch currentWebAlert {
                    case .alert:
                        WebAlertPanel()
                    case .confirm:
                        WebConfirmPanel()
                    case .prompt:
                        WebPromptPanel()
                    case .auth:
                        WebAuthPanel()
                    }
                }
            }
            .zIndex(2)

            // Error view, download bar, and find in page bar
            VStack {
                Spacer()

                // ProgressView for loading
                if webModel.showLoadingProgress {
                    VStack {
                        GroupBox {
                            Text("Loading - \(String(format: "%.0f", round(webModel.webView.estimatedProgress * 100)))%")
                                .animation(.none)
                                .font(.callout)

                            ProgressView(value: webModel.webView.estimatedProgress, total: 1.00)
                                .progressViewStyle(LinearProgressViewStyle(tint: navigationAccent))
                        }
                        .groupBoxStyle(LoadingGroupBoxStyle())
                    }
                    .padding(.bottom, 5)
                    .frame(width: 150)
                    .animation(.easeInOut(duration: 0.7))
                }

                // Error description view
                if webModel.showToast {
                    VStack {
                        Group {
                            switch webModel.toastType {
                            case .info:
                                Text(webModel.toastDescription ?? "This shouldn't be showing up... Contact the dev!")
                            case .error:
                                Text("Error: \(webModel.toastDescription ?? "This shouldn't be showing up... Contact the dev!")")
                            }
                        }
                        .font(.caption)
                        .padding(12)
                        .background(.thickMaterial)
                        .cornerRadius(10)
                    }
                    .padding()
                    .transition(AnyTransition.move(edge: .bottom))
                    .animation(.easeInOut(duration: 0.3))
                }

                switch navModel.currentPillView {
                case .findInPage:
                    FindInPageView()
                case .urlBar:
                    UrlBarView()
                case .none:
                    EmptyView()
                }

                // Download progress bar view
                if downloadManager.showDownloadProgress {
                    VStack {
                        GroupBox {
                            Text("Downloading content...")
                            HStack {
                                ProgressView(value: downloadManager.downloadProgress, total: 1.00)
                                    .progressViewStyle(LinearProgressViewStyle(tint: navigationAccent))

                                Button("Cancel") {
                                    downloadManager.currentDownload?.cancel()
                                    downloadManager.currentDownload = nil
                                    downloadManager.showDownloadProgress = false
                                }
                            }
                        }
                    }
                    .transition(AnyTransition.move(edge: .bottom))
                    .animation(.easeInOut(duration: 0.3))
                    .padding()
                }

                // Fills up navigation bar height
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(height: navModel.isKeyboardShowing ? 0 : (navModel.showNavigationBar ? (UIDevice.current.deviceType == .phone ? 35 : 60) : 0))
            }
            .zIndex(3)

            // Navigation Bar
            VStack {
                Spacer()

                if navModel.showNavigationBar {
                    NavigationBarView()
                        .onAppear {
                            if autoHideNavigation {
                                navModel.autoHideNavigationBar()
                            }
                        }
                }

                if UIDevice.current.deviceType != .phone {
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(height: UIDevice.current.hasNotch ? 20 : 0)
                }
            }
            .edgesIgnoringSafeArea(.bottom)
            .zIndex(4)
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark)
    }
}
#endif

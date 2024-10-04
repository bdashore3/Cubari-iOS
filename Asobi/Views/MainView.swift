//
//  MainView.swift
//  Asobi
//
//  Created by Brian Dashore on 1/30/22.
//

import SwiftUI

struct MainView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.managedObjectContext) var managedObjectContext

    @EnvironmentObject var webModel: WebViewModel
    @EnvironmentObject var rootViewController: AsobiRootViewController
    @EnvironmentObject var navModel: NavigationViewModel

    @StateObject var downloadManager: DownloadManager = .init()

    @AppStorage("forceSecurityCredentials") var forceSecurityCredentials = false
    @AppStorage("blurInRecents") var blurInRecents = false
    @AppStorage("useDarkTheme") var useDarkTheme = false
    @AppStorage("followSystemTheme") var followSystemTheme = true
    @AppStorage("statusBarPinType") var statusBarPinType: StatusBarBehaviorType = .partialHide
    @AppStorage("grayHomeIndicator") var grayHomeIndicator = false
    @AppStorage("useStatefulBookmarks") var useStatefulBookmarks = false
    @AppStorage("runAppOnce") var runAppOnce = false

    @State private var showIntroAlert = false

    var body: some View {
        ContentView()
            .sheet(item: $navModel.currentSheet) { item in
                switch item {
                case .library:
                    LibraryView(currentUrl: webModel.webView.url?.absoluteString ?? "No URL found")
                        .environment(\.managedObjectContext, managedObjectContext)
                        .environmentObject(navModel)
                case .settings:
                    SettingsView()
                        .environment(\.managedObjectContext, managedObjectContext)
                        .environmentObject(navModel)
                case .bookmarkEditing:
                    NavView {
                        EditBookmarkView()
                    }
                    .environment(\.managedObjectContext, managedObjectContext)
                    .environmentObject(navModel)
                }
            }
            .preferredColorScheme(followSystemTheme ? nil : (useDarkTheme ? .dark : .light))
            .onReceive(scenePhasePublisher) { phase in
                if blurInRecents {
                    if phase == .active {
                        withAnimation(.easeIn(duration: 0.15)) {
                            navModel.blurRadius = 0
                        }
                    } else {
                        navModel.blurRadius = 15
                    }
                }
            }
            .blur(radius: navModel.isUnlocked ? navModel.blurRadius : 15)
            .overlay {
                if !navModel.isUnlocked {
                    AuthOverlayView()
                }
            }
            .alert("Welcome", isPresented: $showIntroAlert) {
                Button("Guides") {
                    UIApplication.shared.open(URL(string: "https://github.com/bdashore3/Asobi/wiki")!)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "Click the Guides button if you need a guide to get started. \n\n" +
                        "These guides can be accessed later in Asobi's settings."
                )
            }
            .environmentObject(downloadManager)
            .onAppear {
                if downloadManager.webModel == nil {
                    downloadManager.webModel = webModel
                }

                if forceSecurityCredentials {
                    Task {
                        await navModel.authenticateOnStartup()
                    }
                }

                Task { @MainActor in
                    if !runAppOnce {
                        try? await Task.sleep(seconds: 1)
                        showIntroAlert.toggle()
                        runAppOnce = true
                    }
                }
            }
            .onOpenURL { url in
                var splitUrl = url.absoluteString.replacingOccurrences(of: "asobi://", with: "")
                navModel.currentSheet = nil

                if useStatefulBookmarks {
                    let historyRequest = HistoryEntry.fetchRequest()
                    historyRequest.predicate = NSPredicate(format: "url CONTAINS %@", splitUrl)
                    historyRequest.sortDescriptors = [NSSortDescriptor(keyPath: \HistoryEntry.timestamp, ascending: false)]
                    historyRequest.fetchLimit = 1

                    if let entry = try? PersistenceController.shared.backgroundContext.fetch(historyRequest).first, let url = entry.url {
                        splitUrl = url
                    }
                }

                webModel.loadUrl(splitUrl)
            }
            .onChange(of: colorScheme) { _ in
                webModel.setStatusbarColor()
            }
            .onChange(of: useDarkTheme || followSystemTheme) { _ in
                webModel.setStatusbarColor()
            }
            .onChange(of: webModel.backgroundColor) { newColor in
                rootViewController.style = newColor.isLight ? .darkContent : .lightContent
            }
            .onChange(of: statusBarPinType) { newPinType in
                switch newPinType {
                case .pin, .partialHide:
                    rootViewController.statusBarHidden = false
                case .hide:
                    rootViewController.statusBarHidden = true
                }
            }
            .onChange(of: navModel.showNavigationBar) { showing in
                if statusBarPinType == .partialHide {
                    rootViewController.statusBarHidden = !showing
                }

                if grayHomeIndicator {
                    rootViewController.grayHomeIndicator = !showing
                }
            }
            .onReceive(keyboardPublisher) { value in
                navModel.isKeyboardShowing = value
            }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}

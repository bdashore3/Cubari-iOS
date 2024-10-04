//
//  SettingsBehaviorView.swift
//  Asobi
//
//  Created by Brian Dashore on 4/9/22.
//

import SwiftUI

struct SettingsBehaviorView: View {
    @EnvironmentObject var webModel: WebViewModel
    @EnvironmentObject var navModel: NavigationViewModel

    @AppStorage("persistNavigation") var persistNavigation = false
    @AppStorage("autoHideNavigation") var autoHideNavigation = false
    @AppStorage("grayHomeIndicator") var grayHomeIndicator = false
    @AppStorage("showBottomInset") var showBottomInset = false
    @AppStorage("forceFullScreen") var forceFullScreen = false
    @AppStorage("clearCacheAtStart") var clearCacheAtStart = false
    @AppStorage("useStatefulBookmarks") var useStatefulBookmarks = false

    @AppStorage("allowSwipeNavGestures") var allowSwipeNavGestures = true
    @AppStorage("allowZoom") var allowZoom = true

    @AppStorage("statusBarPinType") var statusBarPinType: StatusBarBehaviorType = .partialHide

    @State private var showForceFullScreenAlert: Bool = false
    @State private var showZoomAlert: Bool = false

    var body: some View {
        // MARK: Browser behavior settings

        Section(
            header: Text("Behavior"),
            footer: VStack(alignment: .leading, spacing: 8) {
                Text("The clear cache option clears browser cache on app launch.")
                Text("The allow browser swipe gestures option toggles the webview's navigation gestures.")
                Text("Smart bookmarks will remember the last page you visited for that website.")
            }
        ) {
            Toggle(isOn: $persistNavigation) {
                Text("Lock navigation bar")
            }
            .onChange(of: persistNavigation) { changed in
                if changed {
                    autoHideNavigation = false
                }

                navModel.setNavigationBar(true)
            }

            Toggle(isOn: $autoHideNavigation) {
                Text("Auto hide navigation bar")
            }
            .onChange(of: autoHideNavigation) { changed in
                // Immediately hide the navbar to force autohide functionality
                if changed {
                    navModel.setNavigationBar(false)
                }
            }
            .disabledAppearance(persistNavigation)
            .disabled(persistNavigation)

            if UIDevice.current.hasNotch, UIDevice.current.deviceType != .mac {
                Toggle(isOn: $grayHomeIndicator) {
                    Text("Gray out home indicator")
                }

                Toggle(isOn: $showBottomInset) {
                    Text("Show bottom inset")
                }
            }

            if UIDevice.current.deviceType != .mac {
                NavigationLink(
                    destination: StatusBarBehaviorPicker(),
                    label: {
                        HStack {
                            Text("Status bar behavior")
                            Spacer()
                            Group {
                                switch statusBarPinType {
                                case .hide:
                                    Text("Hidden")
                                case .partialHide:
                                    Text("Partially hidden")
                                case .pin:
                                    Text("Pinned")
                                }
                            }
                            .foregroundColor(.gray)
                        }
                    }
                )
                .onChange(of: statusBarPinType) { _ in
                    webModel.setStatusbarColor()
                }
            }

            Toggle(isOn: $forceFullScreen) {
                Text("Force fullscreen video")
            }
            .onChange(of: forceFullScreen) { _ in
                showForceFullScreenAlert.toggle()
            }
            .alert(
                Text(forceFullScreen ? "Fullscreen enabled" : "Fullscreen disabled"),
                isPresented: $showForceFullScreenAlert
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Changing this setting requires an app restart")
            }

            Toggle(isOn: $allowZoom) {
                Text("Allow zooming")
            }
            .onChange(of: allowZoom) { _ in
                webModel.webView.reload()
                showZoomAlert.toggle()
            }
            .alert(
                Text(allowZoom ? "Zooming enabled" : "Zooming disabled"),
                isPresented: $showZoomAlert
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The page will refresh when you exit settings")
            }

            Toggle(isOn: $clearCacheAtStart) {
                Text("Clear cache on app launch")
            }

            Toggle(isOn: $allowSwipeNavGestures) {
                Text("Allow browser swipe gestures")
            }
            .onChange(of: allowSwipeNavGestures) { changed in
                if changed {
                    webModel.webView.allowsBackForwardNavigationGestures = true
                } else {
                    webModel.webView.allowsBackForwardNavigationGestures = false
                }
            }

            Toggle(isOn: $useStatefulBookmarks) {
                Text("Smart bookmarks")
            }
        }
    }
}

struct SettingsBehaviorView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsBehaviorView()
    }
}

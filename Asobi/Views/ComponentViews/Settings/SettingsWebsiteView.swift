//
//  SettingsWebsiteView.swift
//  Asobi
//
//  Created by Brian Dashore on 4/9/22.
//

import SwiftUI

struct SettingsWebsiteView: View {
    @EnvironmentObject var webModel: WebViewModel

    @AppStorage("changeUserAgent") var changeUserAgent = false
    @AppStorage("loadLastHistory") var loadLastHistory = false
    @AppStorage("browserModeEnabled") var browserModeEnabled = false

    @AppStorage("defaultUrl") var defaultUrl = ""

    @AppStorage("defaultSearchEngine") var defaultSearchEngine: DefaultSearchEngine = .google

    @State private var showUrlChangeAlert: Bool = false
    @State private var showUrlBarAlert: Bool = false

    var body: some View {
        // MARK: Website settings (settings that can alter website content)

        Section("Website settings") {
            Toggle(isOn: $changeUserAgent) {
                Text("Request \(UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac ? "mobile" : "desktop") website")
            }
            .onChange(of: changeUserAgent) { changed in
                webModel.setUserAgent(changeUserAgent: changed)
                webModel.webView.reload()
            }
        }

        // MARK: Default URL setting

        Section(
            header: Text("Default URL"),
            footer: VStack(alignment: .leading, spacing: 8) {
                Text("Sets the default URL when the app is launched. Https will be automatically added if you don't provide it.")
                Text("The load most recent URL option loads the last URL from history on app launch.")
            }
        ) {
            // Auto capitalization modifier will be deprecated at some point
            TextField("https://...", text: $defaultUrl, onEditingChanged: { begin in
                if !begin, UIDevice.current.deviceType != .mac {
                    showUrlChangeAlert.toggle()
                    webModel.loadUrl()
                }
            }, onCommit: {
                if UIDevice.current.deviceType == .mac {
                    showUrlChangeAlert.toggle()
                    webModel.loadUrl()
                }
            })
            .clearButtonMode(.whileEditing)
            .textCase(.lowercase)
            .disableAutocorrection(true)
            .keyboardType(.URL)
            .autocapitalization(.none)
            .alert("The default URL was changed", isPresented: $showUrlChangeAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your page should have refreshed to the new URL")
            }
            .disabledAppearance(loadLastHistory)

            Toggle(isOn: $loadLastHistory) {
                Text("Load most recent URL")
            }
        }

        Section(
            header: Text("Browser mode"),
            footer: Text("Browser mode changes Asobi to work more like a mobile browser as opposed to a PWA companion.")
        ) {
            Toggle(isOn: $browserModeEnabled) {
                Text("Enable browser mode")
            }
            .onChange(of: browserModeEnabled) { changed in
                if changed {
                    showUrlBarAlert.toggle()
                }
            }
            .alert("Browser mode enabled", isPresented: $showUrlBarAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The navigation bar should have a link icon now. \n\n" +
                    "The homepage button is located in the library context menu. \n\n" +
                    "If this interferes with PWAs, please disable the setting.")
            }

            if browserModeEnabled {
                NavigationLink(
                    destination: BrowserSearchEnginePicker(),
                    label: {
                        HStack {
                            Text("Search engine")
                            Spacer()
                            Group {
                                switch defaultSearchEngine {
                                case .google:
                                    Text("Google")
                                case .brave:
                                    Text("Brave")
                                case .bing:
                                    Text("Bing")
                                case .duckduckgo:
                                    Text("DuckDuckGo")
                                case .startpage:
                                    Text("Startpage")
                                case .custom:
                                    Text("Custom")
                                }
                            }
                            .foregroundColor(.gray)
                        }
                    }
                )
            }
        }
    }
}

struct SettingsWebsiteView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsWebsiteView()
    }
}

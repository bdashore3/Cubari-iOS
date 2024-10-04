//
//  SettingsPrivacyView.swift
//  Asobi
//
//  Created by Brian Dashore on 4/9/22.
//

import LocalAuthentication
import SwiftUI

struct SettingsPrivacyView: View {
    @EnvironmentObject var webModel: WebViewModel
    @EnvironmentObject var navModel: NavigationViewModel

    @AppStorage("incognitoMode") var incognitoMode = false
    @AppStorage("blockAds") var blockAds = false
    @AppStorage("blockPopups") var blockPopups = false
    @AppStorage("blurInRecents") var blurInRecents = false
    @AppStorage("forceSecurityCredentials") var forceSecurityCredentials = false

    @AppStorage("httpsOnlyMode") var httpsOnlyMode = true

    @State private var showAdblockAlert: Bool = false
    @State private var alreadyAuthenticated: Bool = false
    @State private var presentAlert: Bool = false

    var body: some View {
        // MARK: Privacy settings

        Section(
            header: Text("Privacy and security"),
            footer: Text("The adblocker blocks in-page ads and the popup blocker blocks popups. Make sure to enable what you need.")
        ) {
            Toggle(isOn: $incognitoMode) {
                Text("Incognito mode")
            }

            Toggle(isOn: $httpsOnlyMode) {
                Text("Https only mode")
            }

            Toggle(isOn: $blockAds) {
                Text("Block ads")
            }
            .onChange(of: blockAds) { changed in
                if changed {
                    Task {
                        await webModel.enableBlocker()
                    }
                } else {
                    webModel.disableBlocker()
                }

                showAdblockAlert.toggle()
            }
            .alert(
                Text(blockAds ? "Adblock enabled" : "Adblock disabled"),
                isPresented: $showAdblockAlert
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The page will refresh when you exit settings")
            }

            Toggle(isOn: $blockPopups) {
                Text("Block popups")
            }

            if blockPopups {
                NavigationLink("Popup exceptions", destination: PopupExceptionView())
            }

            NavigationLink("Allowed URL schemes", destination: AllowedURLSchemeView())

            if UIDevice.current.deviceType != .mac {
                Toggle(isOn: $blurInRecents) {
                    Text("Blur in recents menu")
                }
            }

            if navModel.authenticationPresent() {
                Toggle(isOn: $forceSecurityCredentials) {
                    Text("Force authentication")
                }
                .onChange(of: forceSecurityCredentials) { changed in
                    // To prevent looping of authentication prompts
                    if alreadyAuthenticated {
                        alreadyAuthenticated = false
                        return
                    }

                    let context = LAContext()

                    Task {
                        do {
                            let result = try await context.evaluatePolicy(
                                .deviceOwnerAuthentication,
                                localizedReason: "Authentication is required to change this setting"
                            )

                            forceSecurityCredentials = result ? changed : !changed
                        } catch {
                            // Ignore and log the error
                            debugPrint("Settings authentication error!: \(error)")

                            await MainActor.run {
                                alreadyAuthenticated = true

                                forceSecurityCredentials = !changed
                            }
                        }
                    }
                }
            }
        }
    }
}

struct SettingsPrivacyView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPrivacyView()
    }
}

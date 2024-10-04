//
//  LibraryActionsView.swift
//  Asobi
//
//  Created by Brian Dashore on 1/5/22.
//

import Alamofire
import SwiftUI

struct LibraryActionsView: View {
    @EnvironmentObject var webModel: WebViewModel
    @EnvironmentObject var navModel: NavigationViewModel
    @EnvironmentObject var downloadManager: DownloadManager

    @AppStorage("useUrlBar") var useUrlBar = false

    @Binding var currentUrl: String
    @State private var isCopiedButton = false
    @State private var alertText = ""
    @State private var showLibraryActionProgress = false

    // MARK: Alerts

    @State private var showRepairHistoryAlert: Bool = false
    @State private var showCacheAlert: Bool = false
    @State private var showCookiesAlert: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var showErrorAlert: Bool = false

    var body: some View {
        Form {
            Section(
                header: Text("Current URL"),
                footer: Text("Tap the textbox to copy the URL!")
            ) {
                HStack {
                    Text(currentUrl)
                        .lineLimit(1)

                    Spacer()

                    Text(isCopiedButton ? "Copied!" : "Copy")
                        .opacity(0.6)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    isCopiedButton = true

                    UIPasteboard.general.string = currentUrl

                    Task {
                        try await Task.sleep(seconds: 2)

                        isCopiedButton = false
                    }
                }
            }

            Section {
                Button("Refresh page") {
                    webModel.webView.reload()
                    navModel.currentSheet = nil
                }

                Button("Find in page") {
                    navModel.currentPillView = .findInPage
                    navModel.currentSheet = nil
                }

                if useUrlBar {
                    Button("Show URL bar") {
                        navModel.currentPillView = .urlBar
                        navModel.currentSheet = nil
                    }

                    Button("Go to homepage") {
                        webModel.goHome()
                    }
                }

                // Group all buttons tied to one alert
                Group {
                    Button("Save website icon") {
                        Task {
                            do {
                                try await downloadManager.downloadFavicon()

                                alertText = "Image saved in the \(UIDevice.current.deviceType == .mac ? "downloads" : "favicons") folder"
                                showSuccessAlert.toggle()
                            } catch {
                                alertText = "Cannot get the apple touch icon URL for the website"
                                showErrorAlert.toggle()
                            }
                        }
                    }

                    Button("Repair history") {
                        showRepairHistoryAlert.toggle()
                    }

                    Button("Clear all cookies") {
                        showCookiesAlert.toggle()
                    }
                    .accentColor(.red)

                    Button("Clear browser cache") {
                        showCacheAlert.toggle()
                    }
                    .accentColor(.red)
                }
                .alert("Are you sure?", isPresented: $showRepairHistoryAlert) {
                    Button("Yes") {
                        showLibraryActionProgress = true
                        let repairedCount = webModel.repairZombieHistory()
                        showLibraryActionProgress = false

                        alertText = "A total of \(repairedCount) history entries have been re-associated. \n\nIf you still have problems, consider clearing browsing data."
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will attempt to re-link any leftover (zombie) history entries. Do you want to proceed?")
                }
                .alert("Are you sure?", isPresented: $showCacheAlert) {
                    Button("Yes", role: .destructive) {
                        Task {
                            await webModel.clearCache()

                            alertText = "Browser cache has been cleared"
                            showSuccessAlert.toggle()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Clearing browser cache is an irreversible action!")
                }
                .alert("Are you sure?", isPresented: $showCookiesAlert) {
                    Button("Yes", role: .destructive) {
                        Task {
                            await webModel.clearCookies()

                            alertText = "Cookies have been cleared"
                            showSuccessAlert.toggle()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Clearing cookies is an irreversible action!")
                }
                .alert("Success!", isPresented: $showSuccessAlert) {
                    Button("OK") {
                        alertText = ""
                    }
                } message: {
                    Text(alertText.isEmpty ? "No description given" : alertText)
                }
                .alert("Error!", isPresented: $showErrorAlert) {
                    Button("OK") {
                        alertText = ""
                    }
                } message: {
                    Text(alertText.isEmpty ? "No description given" : alertText)
                }

                HistoryActionView(labelText: "Clear browsing data")
            }
        }
        .overlay {
            if showLibraryActionProgress {
                GroupBox {
                    VStack {
                        ProgressView()
                            .progressViewStyle(.circular)

                        Text("Working...")
                    }
                }
                .shadow(radius: 10)
            }
        }
    }
}

struct LibraryActionsView_Previews: PreviewProvider {
    static var previews: some View {
        LibraryActionsView(currentUrl: .constant(""))
    }
}

//
//  SettingsDownloadsView.swift
//  Asobi
//
//  Created by Brian Dashore on 4/9/22.
//

import SwiftUI

struct SettingsDownloadsView: View {
    @EnvironmentObject var navModel: NavigationViewModel
    @EnvironmentObject var downloadManager: DownloadManager

    @AppStorage("overwriteDownloadedFiles") var overwriteDownloadedFiles = true

    @AppStorage("defaultDownloadDirectory") var defaultDownloadDirectory = ""
    @AppStorage("downloadDirectoryBookmark") var downloadDirectoryBookmark: Data?

    @State private var showDownloadResetAlert: Bool = false
    @State private var backgroundColor: Color = .clear

    var body: some View {
        // MARK: Downloads directory (for iDevices)

        if UIDevice.current.deviceType != .mac {
            Section(
                header: Text("Download options"),
                footer: Text("If a downloaded file has the same name as a local file, the local file will be overwritten if the toggle is on.")
            ) {
                HStack {
                    Text("Downloads")

                    Spacer()

                    Group {
                        Text(defaultDownloadDirectory.isEmpty ? "Downloads" : defaultDownloadDirectory)
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.gray)
                }
                .lineLimit(0)
                .background(backgroundColor)
                .contentShape(Rectangle())
                .onTapGesture {
                    Task {
                        navModel.currentSheet = nil

                        try await Task.sleep(seconds: 0.5)

                        downloadManager.showDefaultDirectoryPicker.toggle()
                    }
                }

                Toggle(isOn: $overwriteDownloadedFiles) {
                    Text("Overwrite files on download")
                }

                Button("Reset download directory") {
                    downloadDirectoryBookmark = nil
                    defaultDownloadDirectory = ""

                    showDownloadResetAlert.toggle()
                }
                .foregroundColor(.red)
                .alert("Success", isPresented: $showDownloadResetAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("The downloads directory has been reset to Asobi's documents folder")
                }
            }
        }
    }
}

struct SettingsDownloadsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsDownloadsView()
    }
}

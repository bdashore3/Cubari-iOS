//
//  DownloadManager.swift
//  Asobi
//
//  Created by Brian Dashore on 12/14/21.
//

import Alamofire
import CoreServices
import Foundation
import SwiftUI

struct BlobComponents: Codable {
    let url: String
    let mimeType: String
    let size: Int64
    let dataString: String
}

@MainActor
class DownloadManager: ObservableObject {
    var webModel: WebViewModel?

    @AppStorage("overwriteDownloadedFiles") private var overwriteDownloadedFiles = true
    @AppStorage("defaultDownloadDirectory") private var defaultDownloadDirectory = ""
    @AppStorage("downloadDirectoryBookmark") private var downloadDirectoryBookmark: Data?

    // Download handling variables
    @Published var downloadUrl: URL? = nil
    @Published var showHttpAlert: Bool = false
    @Published var showBlobAlert: Bool = false
    @Published var currentDownload: DownloadTask<URL>? = nil
    @Published var downloadProgress: Double = 0.0
    @Published var showDownloadProgress: Bool = false

    // Settings variables
    @Published var showDefaultDirectoryPicker: Bool = false

    // So DownloadProgress can work in an async context without races
    actor DownloadProgressTimer {
        var lastTime = Date()

        func setTime(newDate: Date) {
            lastTime = newDate
        }
    }

    // Download file from page
    func httpDownloadFrom(url downloadUrl: URL) async {
        // Always shut down any current requests, clear the download queue, and set the parent download URL to nil
        defer {
            self.downloadUrl = nil
            currentDownload?.cancel()
            currentDownload = nil
        }

        if currentDownload != nil {
            webModel?.toastDescription = "Cannot download this file. A download is already in progress."
            return
        }

        let progressTimer = DownloadProgressTimer()

        let destination: DownloadRequest.Destination = { _, response in
            let suggestedName = response.suggestedFilename ?? "unknown"

            // Download into the temporary download directory
            let defaultDownloadPath = self.getFallbackDownloadDirectory(isFavicon: false)

            let fileURL = defaultDownloadPath.appendingPathComponent(suggestedName)

            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }

        showDownloadProgress = true

        let downloadRequest = AF.download(downloadUrl, to: destination)

        Task {
            for await progress in downloadRequest.downloadProgress() {
                if await Date().timeIntervalSince(progressTimer.lastTime) > 1.5 {
                    await progressTimer.setTime(newDate: Date())

                    self.downloadProgress = progress.fractionCompleted
                }
            }
        }

        // Set as a UI callback if the download needs to be cancelled
        currentDownload = downloadRequest.serializingDownloadedFileURL()

        let response = await downloadRequest.serializingDownloadedFileURL().response

        try? await Task.sleep(seconds: 0.5)

        showDownloadProgress = false
        downloadProgress = 0.0

        if let error = response.error {
            webModel?.toastDescription = "Download could not be completed. \(error)"
            return
        }

        // MacOS uses the user's downloads folder by default
        if UIDevice.current.deviceType == .mac {
            webModel?.toastType = .info
            webModel?.toastDescription = "File successfully downloaded to your downloads directory"
            return
        }

        guard let tempUrl = response.value else {
            // The file is in the user's documents directory, break out
            webModel?.toastDescription = "Could not get the URL for your downloads directory, so the file was downloaded to Asobi's downloads directory"
            return
        }

        if let bookmarkData = downloadDirectoryBookmark, !defaultDownloadDirectory.isEmpty {
            moveToDownloadsDirectory(tempUrl: tempUrl, bookmarkData: bookmarkData)
        } else {
            webModel?.toastType = .info
            webModel?.toastDescription = "File successfully downloaded to Asobi's downloads directory"
        }
    }

    // Import blob URL
    func blobDownloadWith(jsonString: String) {
        guard let jsonData = jsonString.data(using: .utf8) else {
            webModel?.toastDescription = "Cannot convert blob JSON into data!"
            return
        }

        let decoder = JSONDecoder()

        do {
            let file = try decoder.decode(BlobComponents.self, from: jsonData)

            guard let data = Data(base64Encoded: file.dataString),
                  let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, file.mimeType as CFString, nil),
                  let ext = UTTypeCopyPreferredTagWithClass(uti.takeRetainedValue(), kUTTagClassFilenameExtension)
            else {
                webModel?.toastDescription = "Could not get blob data or extension!"
                return
            }

            let fileName = file.url.components(separatedBy: "/").last ?? "unknown"
            let path = getFallbackDownloadDirectory(isFavicon: false)
            let url = path.appendingPathComponent("blobDownload-\(fileName).\(ext.takeRetainedValue())")

            try data.write(to: url)
            downloadUrl = url

            showBlobAlert.toggle()
        } catch {
            webModel?.toastDescription = error.localizedDescription
            return
        }
    }

    // Wrapper function for blob download script
    func executeBlobDownloadJS(url: URL) {
        webModel?.webView.evaluateJavaScript(
            """
            function blobToDataURL(blob, callback) {
                var a = new FileReader();
                a.onload = function(e) {callback(e.target.result.split(",")[1]);}
                a.readAsDataURL(blob);
            }

            async function run() {
                const url = "\(url)"
                const blob = await fetch(url).then(r => r.blob());

                blobToDataURL(blob, datauri => {
                    const responseObj = {
                        url: url,
                        mimeType: blob.type,
                        size: blob.size,
                        dataString: datauri
                    }
                    window.webkit.messageHandlers.blobListener.postMessage(JSON.stringify(responseObj))
                });
            }

            run()
            """)
    }

    func completeBlobDownload() {
        defer {
            downloadUrl = nil
        }

        // MacOS uses the user's downloads folder by default
        if UIDevice.current.deviceType == .mac {
            webModel?.toastType = .info
            webModel?.toastDescription = "File successfully downloaded to your downloads directory"
            return
        }

        guard let tempUrl = downloadUrl else {
            webModel?.toastDescription = "Could not get the download URL! Your file is still saved in Asobi's downloads directory"
            return
        }

        if let bookmarkData = downloadDirectoryBookmark, !defaultDownloadDirectory.isEmpty {
            moveToDownloadsDirectory(tempUrl: tempUrl, bookmarkData: bookmarkData)
        } else {
            webModel?.toastType = .info
            webModel?.toastDescription = "File successfully downloaded to Asobi's downloads directory"
        }
    }

    func deleteBlobDownload() {
        if let tempUrl = downloadUrl {
            do {
                try FileManager.default.removeItem(at: tempUrl)
            } catch {
                webModel?.toastDescription = error.localizedDescription
            }
        } else {
            webModel?.toastDescription = "Could not get the downloaded file's location! You will have to manually delete it from Asobi's downloads directory"
        }

        downloadUrl = nil
    }

    func moveToDownloadsDirectory(tempUrl: URL, bookmarkData: Data) {
        var isStale = false

        do {
            let downloadsUrl = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)

            guard !isStale else {
                // The file is in the user's documents directory, error and break out
                UserDefaults.standard.set(nil, forKey: "downloadDirectoryBookmark")
                UserDefaults.standard.set("", forKey: "defaultDownloadDirectory")

                webModel?.toastType = .info
                webModel?.toastDescription = "The download successfully completed, but Asobi couldn't access your downloads folder. \nThe directory has been reset to Asobi's documents folder. You can change this in settings."
                return
            }

            let directorySecured = downloadsUrl.startAccessingSecurityScopedResource()

            defer {
                if directorySecured {
                    downloadsUrl.stopAccessingSecurityScopedResource()
                }
            }

            let fileManager = FileManager.default
            let newFileUrl = downloadsUrl.appendingPathComponent(tempUrl.lastPathComponent)

            if overwriteDownloadedFiles {
                try? fileManager.removeItem(at: newFileUrl)
            }

            try fileManager.moveItem(at: tempUrl, to: newFileUrl)

            webModel?.toastType = .info
            webModel?.toastDescription = "File successfully downloaded to your selected downloads directory"
        } catch {
            let error = error as NSError

            // Our bookmark is invalid and the downloads directory is reset
            if error.code == 257 {
                UserDefaults.standard.set(nil, forKey: "downloadDirectoryBookmark")
                UserDefaults.standard.set("", forKey: "defaultDownloadDirectory")

                webModel?.toastType = .info
                webModel?.toastDescription = "The download successfully completed, but Asobi couldn't access your downloads folder. \nThe directory has been reset to the Documents folder. You can change this in settings."
            } else {
                webModel?.toastDescription = error.localizedDescription
            }
        }
    }

    func downloadFavicon() async throws {
        let urlString = try await webModel?.webView.evaluateJavaScript("document.querySelector(`link[rel='apple-touch-icon']`).href") as! String

        let destination: DownloadRequest.Destination = { _, response in
            let documentsURL = self.getFallbackDownloadDirectory(isFavicon: true)
            let suggestedName = response.suggestedFilename ?? "favicon"
            let pathComponent = UIDevice.current.deviceType == .mac ? suggestedName : "favicons/\(suggestedName)"

            let fileURL = documentsURL.appendingPathComponent(pathComponent)

            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }

        // Download to favicons folder
        _ = try await AF.download(URL(string: urlString)!, to: destination).serializingDownloadedFileURL().value
    }

    func setDefaultDownloadDirectory(downloadPath: URL) {
        guard downloadPath.startAccessingSecurityScopedResource() else {
            webModel?.toastDescription = "Cannot access the provided URL, aborting process"
            return
        }

        defer { downloadPath.stopAccessingSecurityScopedResource() }

        do {
            // Set the bookmark for further file access
            let bookmarkData = try downloadPath.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "downloadDirectoryBookmark")

            // Set the download directory string for settings
            UserDefaults.standard.set(downloadPath.lastPathComponent, forKey: "defaultDownloadDirectory")
        } catch {
            webModel?.toastDescription = error.localizedDescription
        }
    }

    func getFallbackDownloadDirectory(isFavicon: Bool) -> URL {
        let fileManager = FileManager.default

        if UIDevice.current.deviceType == .mac {
            return fileManager.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        } else if isFavicon {
            return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        } else {
            return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Downloads")
        }
    }
}

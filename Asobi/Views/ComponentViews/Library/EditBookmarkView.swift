//
//  AddBookmarkView.swift
//  Asobi
//
//  Created by Brian Dashore on 10/16/21.
//

import CoreData
import SwiftUI

struct EditBookmarkView: View {
    @Environment(\.presentationMode) var presentationMode

    @EnvironmentObject var webModel: WebViewModel
    @EnvironmentObject var navModel: NavigationViewModel

    let backgroundContext = PersistenceController.shared.backgroundContext

    @State var bookmark: Bookmark? = nil

    @State private var bookmarkName = ""
    @State private var bookmarkUrl = ""
    @State private var showUrlError = false

    var body: some View {
        Form {
            // Because onAppear doesn't work properly with sheet + form
            Section {
                TextField("Enter title", text: $bookmarkName)
                    .clearButtonMode(.whileEditing)

                TextField("Enter URL", text: $bookmarkUrl)
                    .clearButtonMode(.whileEditing)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }
            .onAppear {
                bookmarkName = bookmark?.name ?? webModel.webView.title ?? ""
                bookmarkUrl = bookmark?.url ?? webModel.webView.url?.absoluteString ?? ""

                if !(bookmarkUrl.hasPrefix("http://") || bookmarkUrl.hasPrefix("https://")) {
                    bookmarkUrl = "https://\(bookmarkUrl)"
                }
            }
        }
        .alert("Empty fields", isPresented: $showUrlError) {
            Button("OK") {}
        } message: {
            Text("The bookmark title and URL cannot be empty. Please input the valid fields")
        }
        .navigationBarTitle("Editing Bookmark", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if navModel.currentSheet != .library {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    if bookmarkUrl == "" || bookmarkName == "" {
                        showUrlError.toggle()

                        return
                    }

                    if let unwrappedBookmark = bookmark {
                        // Update an existing bookmark
                        unwrappedBookmark.name = bookmarkName.trimmingCharacters(in: .whitespaces)
                        unwrappedBookmark.url = bookmarkUrl.trimmingCharacters(in: .whitespaces)
                    } else {
                        // If called from a context menu, we need to upsert the bookmark
                        let tempName = bookmarkName.trimmingCharacters(in: .whitespaces)

                        let bookmarkRequest = Bookmark.fetchRequest()
                        bookmarkRequest.predicate = NSPredicate(format: "name == %@", tempName)
                        bookmarkRequest.fetchLimit = 1

                        if let existingBookmark = try? backgroundContext.fetch(bookmarkRequest).first {
                            PersistenceController.shared.delete(existingBookmark, context: backgroundContext)
                        }

                        // Set a new bookmark
                        let bookmark = Bookmark(context: backgroundContext)
                        bookmark.name = tempName
                        bookmark.url = bookmarkUrl.trimmingCharacters(in: .whitespaces)
                    }

                    PersistenceController.shared.save(backgroundContext)

                    presentationMode.wrappedValue.dismiss()

                    bookmark = nil
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .blur(radius: UIDevice.current.deviceType == .mac ? 0 : navModel.blurRadius)
    }
}

struct EditBookmarkView_Previews: PreviewProvider {
    static var previews: some View {
        EditBookmarkView(bookmark: nil)
    }
}

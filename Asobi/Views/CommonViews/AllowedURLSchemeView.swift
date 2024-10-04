//
//  AllowedURLSchemeView.swift
//  Asobi
//
//  Created by Brian Dashore on 1/21/23.
//

import SwiftUI

struct AllowedURLSchemeView: View {
    @EnvironmentObject var webModel: WebViewModel

    let backgroundContext = PersistenceController.shared.backgroundContext

    @FetchRequest(
        entity: AllowedURLScheme.entity(),
        sortDescriptors: []
    ) var allowedSchemes: FetchedResults<AllowedURLScheme>

    @State private var showErrorAlert = false
    @State private var errorMessage: String = ""
    @State private var newSchemeUrl: String = ""

    var body: some View {
        Form {
            Section(
                header: Text("Add a website"),
                footer: Text("When adding a scheme, it must have :// included")
            ) {
                HStack {
                    TextField("Enter URL or scheme", text: $newSchemeUrl)
                        .clearButtonMode(.whileEditing)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .lineLimit(1)

                    Spacer()

                    Button("Add") {
                        guard let newScheme = URL(string: newSchemeUrl)?.scheme else {
                            errorMessage = "Cannot add the scheme because the URL is invalid. Maybe you forgot :// after the scheme name?"
                            showErrorAlert.toggle()

                            return
                        }

                        if newScheme == "http" || newScheme == "https" {
                            errorMessage = "Cannot add http or https schemes because they are allowed by default"
                            showErrorAlert.toggle()

                            return
                        }

                        let schemeRequest = AllowedURLScheme.fetchRequest()
                        schemeRequest.predicate = NSPredicate(format: "scheme == %@", newScheme)
                        schemeRequest.fetchLimit = 1

                        guard let count = try? backgroundContext.count(for: schemeRequest) else {
                            errorMessage = "Cannot add this scheme because it already exists"
                            showErrorAlert.toggle()

                            return
                        }

                        if count < 1 {
                            let newAllowedScheme = AllowedURLScheme(context: backgroundContext)
                            newAllowedScheme.scheme = newScheme

                            PersistenceController.shared.save(backgroundContext)
                        } else {
                            errorMessage = "Cannot add this scheme because it already exists"
                            showErrorAlert.toggle()
                        }
                    }
                }
            }

            Section("Allowed schemes") {
                if allowedSchemes.isEmpty {
                    Text("There are no allowed URL schemes (https and http are always allowed)")
                } else {
                    ForEach(allowedSchemes, id: \.self) { allowedScheme in
                        Text(allowedScheme.scheme ?? "No scheme present")
                    }
                    .onDelete(perform: removeItem)
                }
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .navigationTitle("Allowed URL Schemes")
        .navigationBarTitleDisplayMode(.inline)
    }

    func removeItem(at offsets: IndexSet) {
        for index in offsets {
            if let allowedScheme = allowedSchemes[safe: index] {
                PersistenceController.shared.delete(allowedScheme, context: backgroundContext)
            }
        }
    }
}

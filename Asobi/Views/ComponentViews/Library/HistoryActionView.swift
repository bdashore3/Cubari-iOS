//
//  HistoryActionView.swift
//  Asobi
//
//  Created by Brian Dashore on 11/13/21.
//

import SwiftUI

struct HistoryActionView: View {
    @State var labelText: String

    @State private var showWarnAlert = false
    @State private var showErrorAlert = false
    @State private var showSuccessAlert = false

    @State private var showActionSheet = false
    @State private var historyDeleteRange: HistoryDeleteRange = .day
    @State private var successAlertRange: String = ""
    @State private var errorMessage: String?

    var body: some View {
        Button {
            showActionSheet.toggle()
        } label: {
            Text(labelText)
                .foregroundColor(.red)
        }
        .confirmationDialog(
            "Clear browsing data",
            isPresented: $showActionSheet,
            titleVisibility: .visible
        ) {
            Button("Past day", role: .destructive) {
                historyDeleteRange = .day
                successAlertRange = "day"
                showWarnAlert.toggle()
            }
            Button("Past week", role: .destructive) {
                historyDeleteRange = .week
                successAlertRange = "week"
                showWarnAlert.toggle()
            }
            Button("Past 4 weeks", role: .destructive) {
                historyDeleteRange = .month
                successAlertRange = "4 weeks"
                showWarnAlert.toggle()
            }
            Button("All time", role: .destructive) {
                historyDeleteRange = .allTime
                showWarnAlert.toggle()
            }
        } message: {
            Text("This will delete your browsing history! Be careful.")
        }
        .alert("Are you sure?", isPresented: $showWarnAlert) {
            Button("Yes", role: .destructive) {
                do {
                    try PersistenceController.shared.batchDeleteHistory(range: historyDeleteRange)
                    showSuccessAlert.toggle()
                } catch {
                    errorMessage = error.localizedDescription
                    showErrorAlert.toggle()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deleting browser history is an irreversible action!")
        }
        .alert("Error when clearing data!", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "This alert popped up by accident, send feedback to the dev.")
        }
        .alert("Success!", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your browsing data \(successAlertRange.isEmpty ? "" : "from the past \(successAlertRange)") has been cleared")
        }
    }
}

struct HistoryActionView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryActionView(labelText: "Clear")
    }
}

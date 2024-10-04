//
//  AppIconButtonView.swift
//  Asobi
//
//  Created by Brian Dashore on 12/26/21.
//

import SwiftUI

struct AppIconButtonView: View {
    @Environment(\.colorScheme) var colorScheme

    @AppStorage("selectedIconKey") var selectedIconKey = "AppImage"
    @AppStorage("navigationAccent") var navigationAccent: Color = .red

    @State private var showErrorAlert = false
    @State private var errorAlertText = ""

    let imageKey: String
    let iconKey: String?
    let iconName: String
    let author: String

    var body: some View {
        VStack {
            Button(action: {
                Task {
                    do {
                        try await UIApplication.shared.setAlternateIconName(iconKey)
                        selectedIconKey = imageKey
                    } catch {
                        errorAlertText = error.localizedDescription
                        showErrorAlert.toggle()
                    }
                }
            }, label: {
                Image(imageKey)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .cornerRadius(10)
            })

            VStack {
                Text(iconName)
                Text("-\(author)")
            }
            .foregroundColor(selectedIconKey == imageKey ? navigationAccent : (colorScheme == .light ? .black : .white))
            .font(
                .caption2
                    .weight(selectedIconKey == imageKey ? .bold : .regular)
            )
        }
        .alert("Error!", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("App icon error: \(errorAlertText)")
        }
    }
}

struct AppIconButtonView_Previews: PreviewProvider {
    static var previews: some View {
        AppIconButtonView(imageKey: "AppImage", iconKey: nil, iconName: "Default", author: "kingbri")
    }
}

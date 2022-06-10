//
//  UrlBarView.swift
//  Asobi
//
//  Created by Brian Dashore on 6/9/22.
//

import SwiftUI

struct UrlBarView: View {
    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject var webModel: WebViewModel
    @EnvironmentObject var navModel: NavigationViewModel

    @AppStorage("useUrlBar") var useUrlBar = false
    @AppStorage("navigationAccent") var navigationAccent: Color = .red

    @State private var currentUrl: String = ""

    var body: some View {
        HStack {
            TextField(
                "https://...",
                text: $currentUrl,
                onCommit: {
                    webModel.loadUrl(currentUrl)
                }
            )
            .clearButtonMode(.whileEditing)
            .textCase(.lowercase)
            .disableAutocorrection(true)
            .keyboardType(.URL)
            .autocapitalization(.none)

            Button(action: {
                webModel.showUrlBar.toggle()
                navModel.isKeyboardShowing = false
            }, label: {
                Image(systemName: "xmark")
                    .padding(.horizontal, 4)
            })
            .keyboardShortcut(.cancelAction)
        }
        .onAppear {
            currentUrl = webModel.webView.url?.absoluteString ?? ""
        }
        .onChange(of: webModel.webView.url) { url in
            currentUrl = url?.absoluteString ?? ""
        }
        .padding(10)
        .accentColor(navigationAccent)
        .background(colorScheme == .light ? .white : .black)
        .cornerRadius(10)
        .transition(AnyTransition.move(edge: .bottom))
        .animation(.easeInOut(duration: 0.3))
        .padding(.horizontal, 4)
    }
}

struct UrlBarView_Previews: PreviewProvider {
    static var previews: some View {
        UrlBarView()
    }
}
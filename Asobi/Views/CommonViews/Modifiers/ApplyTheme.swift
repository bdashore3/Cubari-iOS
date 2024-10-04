//
//  ApplyTheme.swift
//  Asobi
//
//  Created by Brian Dashore on 1/9/23.
//

import SwiftUI
import SwiftUIIntrospect

struct ApplyTheme: ViewModifier {
    let colorScheme: ColorScheme?

    func body(content: Content) -> some View {
        content
            .introspect(.viewController, on: .iOS(.v15, .v16, .v17, .v18)) { UIViewController in
                switch colorScheme {
                case .dark:
                    UIViewController.overrideUserInterfaceStyle = .dark
                case .light:
                    UIViewController.overrideUserInterfaceStyle = .light
                default:
                    UIViewController.overrideUserInterfaceStyle = .unspecified
                }
            }
    }
}

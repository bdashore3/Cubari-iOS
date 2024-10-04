//
//  TextFieldClearMode.swift
//  Asobi
//
//  Created by Brian Dashore on 1/9/23.
//

import SwiftUI
import SwiftUIIntrospect

struct TextFieldClearMode: ViewModifier {
    let clearButtonMode: UITextField.ViewMode

    func body(content: Content) -> some View {
        content
            .introspect(.textField, on: .iOS(.v15, .v16, .v17, .v18)) { textField in
                textField.clearButtonMode = clearButtonMode
            }
    }
}

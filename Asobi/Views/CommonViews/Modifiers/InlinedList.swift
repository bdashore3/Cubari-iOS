//
//  InlinedList.swift
//  Asobi
//
//  Created by Brian Dashore on 1/9/23.
//
//  Removes the top padding on unsectioned lists
//  If a list is sectioned, see InlineHeader
//

import SwiftUI
import SwiftUIIntrospect

struct InlinedList: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content
                .introspect(.list, on: .iOS(.v16, .v17, .v18)) { collectionView in
                    collectionView.contentInset.top = -20
                }
        } else {
            content
                .introspect(.list, on: .iOS(.v15)) { tableView in
                    tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 20))
                }
        }
    }
}

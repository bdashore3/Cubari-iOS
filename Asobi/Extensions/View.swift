//
//  View.swift
//  Asobi
//
//  Created by Brian Dashore on 12/27/21.
//

import Combine
import SwiftUI

extension View {
    // MARK: Custom combine publishers

    // Modified from https://stackoverflow.com/questions/65784294/how-to-detect-if-keyboard-is-present-in-swiftui
    // Uses keyboardWillHide to properly track when to adjust the height for the pill view buffer
    var keyboardPublisher: AnyPublisher<Bool, Never> {
        Publishers
            .Merge(
                NotificationCenter
                    .default
                    .publisher(for: UIResponder.keyboardWillShowNotification)
                    .map { _ in true },
                NotificationCenter
                    .default
                    .publisher(for: UIResponder.keyboardWillHideNotification)
                    .map { _ in false }
            )
            .eraseToAnyPublisher()
    }

    var scenePhasePublisher: AnyPublisher<ScenePhase, Never> {
        Publishers
            .Merge3(
                NotificationCenter
                    .default
                    .publisher(for: UIApplication.willResignActiveNotification)
                    .map { _ in .inactive },
                NotificationCenter
                    .default
                    .publisher(for: UIApplication.didBecomeActiveNotification)
                    .map { _ in .active },
                NotificationCenter
                    .default
                    .publisher(for: UIApplication.didEnterBackgroundNotification)
                    .map { _ in .background }
            )
            .eraseToAnyPublisher()
    }

    // MARK: Modifiers

    func applyTheme(_ colorScheme: ColorScheme?) -> some View {
        modifier(ApplyTheme(colorScheme: colorScheme))
    }

    func disabledAppearance(_ disabled: Bool = false) -> some View {
        modifier(DisabledAppearance(disabled: disabled))
    }

    func onWillDisappear(_ perform: @escaping () -> Void) -> some View {
        modifier(WillDisappearModifier(callback: perform))
    }

    func dynamicContextMenu(buttons: [ContextMenuButton], title: String? = nil, willEnd: (() -> Void)? = nil, willDisplay: (() -> Void)? = nil) -> some View {
        modifier(DynamicContextMenu(buttons: buttons, title: title, willDisplay: willDisplay, willEnd: willEnd))
    }

    func inlinedList() -> some View {
        modifier(InlinedList())
    }

    func conditionalListStyle() -> some View {
        modifier(ConditionalListStyle())
    }
}

//
//  IconButton.swift
//  TCL Remote
//
//  Created by Hung Nguyen on 5/30/26.
//

import SwiftUI

struct LuxeIconButtonStyle: ButtonStyle {
    var foregroundColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(
                LinearGradient(
                    colors: configuration.isPressed
                        ? [Color(red: 0.05, green: 0.36, blue: 0.58), Color(red: 0.03, green: 0.20, blue: 0.34)]
                        : [Color.white.opacity(0.28), Color.white.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(configuration.isPressed ? 0.75 : 0.45), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.15 : 0.28), radius: configuration.isPressed ? 4 : 10, x: 0, y: configuration.isPressed ? 2 : 6)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct PressedScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.0 : 0.9)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

//
//  Palette.swift
//  Drake
//
//  The window's colours, in one place. Drake is always dark: a neutral
//  near-black body, a quiet grey for selected rows, and one darker blue used
//  sparingly as the accent (selection checkmarks, drop highlight, pins).
//

import AppKit
import SwiftUI

enum Palette {
    /// Window body and list background.
    static let background = Color(red: 0.078, green: 0.078, blue: 0.086)
    /// Footer and search bars, a step lighter than the body.
    static let bar = Color(red: 0.110, green: 0.110, blue: 0.122)

    /// Selected row fill: neutral, not blue.
    static let selection = Color.white.opacity(0.075)
    /// The one accent colour, darker than the system blue.
    static let accent = Color(red: 0.24, green: 0.43, blue: 0.78)

    static let nsBackground = NSColor(background)
    static let appearance = NSAppearance(named: .darkAqua)
}

extension View {
    /// Fill for a selected row or tile.
    func selectionBackground(_ isSelected: Bool, cornerRadius: CGFloat) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(isSelected ? Palette.selection : .clear)
        }
    }
}

/// Footer buttons: plain text that brightens on hover, with a soft pill
/// behind it, instead of the stock bordered push button.
struct FooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        FooterButton(configuration: configuration)
    }

    private struct FooterButton: View {
        let configuration: ButtonStyleConfiguration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.callout)
                .foregroundStyle(isHovered ? .primary : .secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(configuration.isPressed ? 0.12 : isHovered ? 0.07 : 0))
                }
                .contentShape(RoundedRectangle(cornerRadius: 6))
                .onHover { isHovered = $0 }
        }
    }
}

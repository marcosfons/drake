//
//  Theme.swift
//  Drake
//
//  Colours and type, in one place. Drake is always dark: a near-black body,
//  white text, and one cool blue (the AccentColor asset) for selection, focus
//  and the drop highlight. Chrome stays out of the way; content carries the
//  window.
//

import AppKit
import SwiftUI

enum Palette {
    /// Window body. Near black rather than pure black, so shadows and the
    /// window edge still read.
    static let background = Color(nsColor: nsBackground)
    static let nsBackground = NSColor(white: 0.04, alpha: 1)

    /// The accent, from the asset catalog so AppKit and SwiftUI share it.
    static let accent = Color(.accent)
    static let nsAccent = NSColor(resource: .accent)

    /// Selected row fill.
    static let selection = accent.opacity(0.22)
    /// Hovered row fill.
    static let hover = Color.white.opacity(0.05)
    /// Tiles, the drop zone and text fields: a step up from the body.
    static let raised = Color.white.opacity(0.06)
    /// Thin outlines on raised surfaces.
    static let hairline = Color.white.opacity(0.09)
}

enum Typography {
    /// File and entry names: medium weight keeps them crisp on black.
    static let name = Font.system(size: 13, weight: .medium)
    /// The size-and-location line under a name.
    static let detail = Font.system(size: 11).monospacedDigit()
    /// History section headers.
    static let sectionHeader = Font.system(size: 11, weight: .semibold)
}

extension View {
    /// Fill for a row or tile: accent when selected, a faint lift on hover.
    func rowBackground(isSelected: Bool, isHovered: Bool = false, cornerRadius: CGFloat = Metrics.rowCornerRadius) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isSelected ? Palette.selection : isHovered ? Palette.hover : .clear)
        }
    }
}

/// A borderless symbol button that brightens on hover, for inline row actions.
struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        IconButton(configuration: configuration)
    }

    private struct IconButton: View {
        let configuration: ButtonStyleConfiguration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isHovered ? .primary : .tertiary)
                .frame(width: 24, height: 24)
                .background {
                    Circle().fill(.white.opacity(configuration.isPressed ? 0.14 : isHovered ? 0.08 : 0))
                }
                .contentShape(.circle)
                .onHover { isHovered = $0 }
        }
    }
}

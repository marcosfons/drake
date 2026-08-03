//
//  Metrics.swift
//  Drake
//
//  One source of truth for window and row geometry, so the views lay out to
//  exactly the size the window is given: the list is as tall as its rows, and
//  only starts scrolling past `maxVisibleRows`.
//

import Foundation

nonisolated enum Metrics {
    // MARK: - Window widths

    static let sourceWidth: CGFloat = 380
    static let historyWidth: CGFloat = 460
    static let targetWidth: CGFloat = 380
    static let minWidth: CGFloat = 300
    static let maxWidth: CGFloat = 640

    // MARK: - Rows

    /// Rows beyond this scroll instead of growing the window.
    static let maxVisibleRows = 9
    static let rowSpacing: CGFloat = 4
    /// Side padding around the list. Vertical is tighter so one item stays snug.
    static let listPadding: CGFloat = 10
    static let listPaddingVertical: CGFloat = 5
    static let footerHeight: CGFloat = 30
    static let dividerHeight: CGFloat = 1
    static let dragAllTileHeight: CGFloat = 54
    static let dragAllTileSpacing: CGFloat = 8

    /// Tall enough for a two-line label, or for the icon when it is bigger.
    static func rowHeight(iconSize: CGFloat) -> CGFloat {
        max(iconSize, 32) + 10
    }

    /// Exact height of a list holding `rowCount` rows.
    static func listHeight(rowCount: Int, iconSize: CGFloat) -> CGFloat {
        guard rowCount > 0 else { return listPaddingVertical * 2 }
        let rows = CGFloat(rowCount)
        return rows * rowHeight(iconSize: iconSize)
            + (rows - 1) * rowSpacing
            + listPaddingVertical * 2
    }

    /// Height the list is actually given: fits its rows, capped at
    /// `maxVisibleRows` after which it scrolls.
    static func visibleListHeight(rowCount: Int, iconSize: CGFloat) -> CGFloat {
        listHeight(rowCount: min(rowCount, maxVisibleRows), iconSize: iconSize)
    }

    /// Number of grid rows for `count` icons at `iconSize` in `width`.
    static func gridRows(count: Int, iconSize: CGFloat, width: CGFloat) -> Int {
        let cell = iconSize + 20
        let columns = max(Int((width - listPadding * 2) / cell), 1)
        return max((count + columns - 1) / columns, 1)
    }
}

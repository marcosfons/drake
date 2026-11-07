//
//  Metrics.swift
//  Drake
//
//  One source of truth for window and row geometry. The views lay themselves
//  out from these numbers and `contentSize` sizes the window from the same
//  ones, so the two cannot drift: the list is exactly as tall as its rows and
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

    // MARK: - Fixed heights

    static let historyHeight: CGFloat = 520
    static let dropZoneHeight: CGFloat = 150
    /// Space around the drop zone and the compact drag-all tile.
    static let panelPadding: CGFloat = 12
    static let emptyStateHeight: CGFloat = 180
    static let compactTileHeight: CGFloat = 72
    static let dividerHeight: CGFloat = 1
    static let dragAllTileHeight: CGFloat = 54
    static let dragAllTileSpacing: CGFloat = 8

    // MARK: - Rows

    /// Rows beyond this scroll instead of growing the window.
    static let maxVisibleRows = 9
    /// Icon grid rows beyond this scroll (`--icon-only`).
    static let maxVisibleGridRows = 4
    static let rowSpacing: CGFloat = 2
    /// Side padding around the list. Vertical is tighter so one item stays snug.
    static let listPadding: CGFloat = 8
    static let listPaddingVertical: CGFloat = 6
    static let rowCornerRadius: CGFloat = 7

    static let keptItemIconSize: CGFloat = 28
    static let historyIconSize: CGFloat = 28
    static let historyItemIconSize: CGFloat = 22

    /// Rows stay compact; `--thumb-size` only blows up the icon-only grid, as in dragon.
    static func rowIconSize(thumbSize: CGFloat) -> CGFloat {
        min(max(thumbSize / 3, 24), 64)
    }

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

    /// Height of the `--icon-only` grid, capped at `maxVisibleGridRows`.
    static func visibleGridHeight(count: Int, iconSize: CGFloat, width: CGFloat) -> CGFloat {
        let rows = gridRows(count: count, iconSize: iconSize, width: width)
        return listHeight(rowCount: min(rows, maxVisibleGridRows), iconSize: iconSize)
    }

    // MARK: - Window

    /// The smallest content height: a single row.
    static var minContentHeight: CGFloat {
        listHeight(rowCount: 1, iconSize: 24)
    }

    /// Content size for a mode. Heights are exact: the list is as tall as its
    /// rows and only scrolls past `maxVisibleRows`. `existingWidth` keeps the
    /// width the user has chosen; nil uses the mode's default.
    static func contentSize(
        mode: AppModel.Mode,
        itemCount: Int,
        options: Options,
        width existingWidth: CGFloat? = nil
    ) -> CGSize {
        switch mode {
        case .history:
            return CGSize(width: existingWidth ?? historyWidth, height: historyHeight)

        case .target:
            let width = existingWidth ?? targetWidth
            let dropZone = dropZoneHeight + panelPadding * 2
            guard options.keep, itemCount > 0 else {
                return CGSize(width: width, height: dropZone)
            }
            let list = visibleListHeight(rowCount: itemCount, iconSize: keptItemIconSize)
            return CGSize(width: width, height: dropZone + dividerHeight + list)

        case .source:
            let width = existingWidth ?? sourceWidth
            guard itemCount > 0 else {
                return CGSize(width: width, height: emptyStateHeight)
            }
            if options.allCompact {
                return CGSize(width: width, height: compactTileHeight + panelPadding * 2)
            }
            var height: CGFloat = 0
            if options.dragAll {
                height += listPadding + dragAllTileHeight + dragAllTileSpacing
            }
            if options.iconOnly {
                height += visibleGridHeight(count: itemCount, iconSize: options.thumbSize, width: width)
            } else {
                height += visibleListHeight(
                    rowCount: itemCount,
                    iconSize: rowIconSize(thumbSize: options.thumbSize)
                )
            }
            return CGSize(width: width, height: height)
        }
    }
}

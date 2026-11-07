//
//  MetricsTests.swift
//  DrakeTests
//

import AppKit
import Foundation
import Testing

@testable import Drake

struct MetricsTests {
    @Test func listGrowsWithRowCountUpToTheCap() {
        let icon: CGFloat = 32
        let one = Metrics.visibleListHeight(rowCount: 1, iconSize: icon)
        let two = Metrics.visibleListHeight(rowCount: 2, iconSize: icon)
        let nine = Metrics.visibleListHeight(rowCount: 9, iconSize: icon)
        let twenty = Metrics.visibleListHeight(rowCount: 20, iconSize: icon)

        #expect(two - one == Metrics.rowHeight(iconSize: icon) + Metrics.rowSpacing)
        #expect(nine == twenty, "past 9 rows the list scrolls instead of growing")
        #expect(one == Metrics.rowHeight(iconSize: icon) + Metrics.listPaddingVertical * 2)
    }

    @Test func gridRowsFollowTheAvailableWidth() {
        #expect(Metrics.gridRows(count: 4, iconSize: 96, width: 380) == 2)
        #expect(Metrics.gridRows(count: 1, iconSize: 96, width: 380) == 1)
        #expect(Metrics.gridRows(count: 0, iconSize: 96, width: 380) == 1)
    }
}

@MainActor
struct MarqueeSelectionTests {
    private func makeView(rowCount: Int, scrollOffset: CGFloat = 0) -> MarqueeSelectionNSView {
        let view = MarqueeSelectionNSView()
        view.rowCount = rowCount
        view.rowHeight = 42
        view.rowSpacing = 4
        view.topInset = 10
        view.scrollOffsetBox.value = scrollOffset
        return view
    }

    @Test func sweepPicksUpTheRowsItCrosses() {
        let view = makeView(rowCount: 5)
        // Rows start at y=10 and repeat every 46pt.
        #expect(view.rowIndices(in: CGRect(x: 0, y: 12, width: 300, height: 4)) == [0])
        // Rows 0 and 1 span y=10...98; row 2 only begins at y=102.
        #expect(view.rowIndices(in: CGRect(x: 0, y: 12, width: 300, height: 90)) == [0, 1])
        #expect(view.rowIndices(in: CGRect(x: 0, y: 12, width: 300, height: 95)) == [0, 1, 2])
        #expect(view.rowIndices(in: CGRect(x: 0, y: 0, width: 300, height: 400)) == [0, 1, 2, 3, 4])
    }

    @Test func sweepBelowTheLastRowSelectsNothing() {
        let view = makeView(rowCount: 2)
        #expect(view.rowIndices(in: CGRect(x: 0, y: 200, width: 300, height: 50)).isEmpty)
    }

    @Test func sweepAccountsForScrollPosition() {
        let scrolled = makeView(rowCount: 10, scrollOffset: 92)
        // Two rows have scrolled off the top, so the top of the view is row 2.
        #expect(scrolled.rowIndices(in: CGRect(x: 0, y: 12, width: 300, height: 4)) == [2])
    }

    @Test func emptyListSweepsNothing() {
        #expect(makeView(rowCount: 0).rowIndices(in: CGRect(x: 0, y: 0, width: 300, height: 300)).isEmpty)
    }
}

struct WindowSizeTests {
    private func options(_ argv: [String] = ["a"]) -> Options {
        (try? Options.parse(argv)) ?? Options()
    }

    @Test func oneItemMakesAOneRowWindow() {
        let size = Metrics.contentSize(mode: .source, itemCount: 1, options: options())
        let icon = Metrics.rowIconSize(thumbSize: 96)
        #expect(size.width == Metrics.sourceWidth)
        #expect(size.height == Metrics.listHeight(rowCount: 1, iconSize: icon), "no footer, no minimum floor")
    }

    @Test func manyItemsScrollPastTheCap() {
        let icon = Metrics.rowIconSize(thumbSize: 96)
        let size = Metrics.contentSize(mode: .source, itemCount: 40, options: options())
        #expect(size.height == Metrics.listHeight(rowCount: Metrics.maxVisibleRows, iconSize: icon))
    }

    @Test func refittingKeepsTheUsersWidth() {
        let size = Metrics.contentSize(mode: .source, itemCount: 3, options: options(), width: 512)
        #expect(size.width == 512)
    }

    @Test func dragAllAddsTheTileAboveTheList() {
        let plain = Metrics.contentSize(mode: .source, itemCount: 3, options: options(["a"]))
        let all = Metrics.contentSize(mode: .source, itemCount: 3, options: options(["-a", "a"]))
        #expect(all.height - plain.height == Metrics.listPadding + Metrics.dragAllTileHeight + Metrics.dragAllTileSpacing)
    }

    @Test func targetGrowsOnlyWhenKeepingDrops() {
        let empty = Metrics.contentSize(mode: .target, itemCount: 0, options: options(["-t"]))
        let notKept = Metrics.contentSize(mode: .target, itemCount: 3, options: options(["-t"]))
        let kept = Metrics.contentSize(mode: .target, itemCount: 3, options: options(["-t", "-k"]))
        #expect(empty.height == Metrics.dropZoneHeight + Metrics.panelPadding * 2)
        #expect(notKept == empty)
        #expect(kept.height > empty.height)
    }

    @Test func historyHasAFixedHeight() {
        let size = Metrics.contentSize(mode: .history, itemCount: 0, options: options([]))
        #expect(size == CGSize(width: Metrics.historyWidth, height: Metrics.historyHeight))
    }

    @Test func rowIconsStayCompact() {
        #expect(Metrics.rowIconSize(thumbSize: 16) == 24)
        #expect(Metrics.rowIconSize(thumbSize: 96) == 32)
        #expect(Metrics.rowIconSize(thumbSize: 512) == 64)
    }
}

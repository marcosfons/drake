//
//  RootView.swift
//  Drake
//

import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            switch model.mode {
            case .source:
                SourceView()
            case .target:
                TargetView()
            case .history:
                HistoryView()
            }
        }
        .frame(minWidth: 360, minHeight: 200)
    }
}

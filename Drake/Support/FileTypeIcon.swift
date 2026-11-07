//
//  FileTypeIcon.swift
//  Drake
//
//  Finder's document icon is the same grey page for most extensions, which makes
//  a list of mixed files hard to scan. Each type gets a distinct symbol and
//  colour instead, classified by UTType so it covers far more than a list of
//  extensions would, with a few overrides where the type tree is vague.
//
//  Precedence in the UI: Quick Look thumbnail, then this, then Finder's icon.
//

import SwiftUI
import UniformTypeIdentifiers

struct FileTypeIcon: Equatable {
    let symbol: String
    let color: Color
}

enum FileTypeIcons {
    /// Extensions whose UTType is missing, too generic, or shared with something
    /// that deserves a different symbol.
    private static let overrides: [String: FileTypeIcon] = [
        "csv": FileTypeIcon(symbol: "tablecells", color: .green),
        "tsv": FileTypeIcon(symbol: "tablecells", color: .green),
        "log": FileTypeIcon(symbol: "list.bullet.rectangle", color: .secondary),
        "md": FileTypeIcon(symbol: "text.alignleft", color: .blue),
        "markdown": FileTypeIcon(symbol: "text.alignleft", color: .blue),
        "torrent": FileTypeIcon(symbol: "arrow.down.circle", color: .green),
        "iso": FileTypeIcon(symbol: "opticaldiscdrive", color: .secondary),
        "sqlite": FileTypeIcon(symbol: "cylinder.split.1x2", color: .blue),
        "sqlite3": FileTypeIcon(symbol: "cylinder.split.1x2", color: .blue),
        "db": FileTypeIcon(symbol: "cylinder.split.1x2", color: .blue),
        "env": FileTypeIcon(symbol: "key", color: .orange),
        "lock": FileTypeIcon(symbol: "lock", color: .secondary),
        "srt": FileTypeIcon(symbol: "captions.bubble", color: .indigo),
        "vtt": FileTypeIcon(symbol: "captions.bubble", color: .indigo),
        "ics": FileTypeIcon(symbol: "calendar", color: .red),
        "vcf": FileTypeIcon(symbol: "person.crop.square", color: .blue),
        "eml": FileTypeIcon(symbol: "envelope", color: .blue),
        "sh": FileTypeIcon(symbol: "terminal", color: .green),
        "bash": FileTypeIcon(symbol: "terminal", color: .green),
        "zsh": FileTypeIcon(symbol: "terminal", color: .green),
        "fish": FileTypeIcon(symbol: "terminal", color: .green),
        "command": FileTypeIcon(symbol: "terminal", color: .green),
        "apk": FileTypeIcon(symbol: "shippingbox", color: .green),
        "deb": FileTypeIcon(symbol: "shippingbox", color: .brown),
        "rpm": FileTypeIcon(symbol: "shippingbox", color: .brown),
    ]

    /// Ordered most specific first; the first conforming type wins.
    private static let byType: [(UTType, FileTypeIcon)] = [
        (.pdf, FileTypeIcon(symbol: "doc.richtext", color: .red)),
        (.spreadsheet, FileTypeIcon(symbol: "tablecells", color: .green)),
        (.presentation, FileTypeIcon(symbol: "rectangle.on.rectangle", color: .orange)),
        (.audio, FileTypeIcon(symbol: "music.note", color: .pink)),
        (.movie, FileTypeIcon(symbol: "film", color: .indigo)),
        (.image, FileTypeIcon(symbol: "photo", color: .teal)),
        (.font, FileTypeIcon(symbol: "textformat", color: .purple)),
        (.epub, FileTypeIcon(symbol: "book", color: .brown)),
        (.diskImage, FileTypeIcon(symbol: "externaldrive", color: .secondary)),
        (.archive, FileTypeIcon(symbol: "doc.zipper", color: .brown)),
        (.database, FileTypeIcon(symbol: "cylinder.split.1x2", color: .blue)),
        (.json, FileTypeIcon(symbol: "curlybraces", color: .orange)),
        (.yaml, FileTypeIcon(symbol: "curlybraces", color: .orange)),
        (.propertyList, FileTypeIcon(symbol: "curlybraces", color: .orange)),
        (.html, FileTypeIcon(symbol: "globe", color: .blue)),
        (.xml, FileTypeIcon(symbol: "chevron.left.slash.chevron.right", color: .orange)),
        (.script, FileTypeIcon(symbol: "chevron.left.slash.chevron.right", color: .blue)),
        (.sourceCode, FileTypeIcon(symbol: "chevron.left.slash.chevron.right", color: .blue)),
        (.rtf, FileTypeIcon(symbol: "doc.richtext", color: .blue)),
        (.plainText, FileTypeIcon(symbol: "doc.text", color: .secondary)),
        (.text, FileTypeIcon(symbol: "doc.text", color: .secondary)),
        (.unixExecutable, FileTypeIcon(symbol: "gearshape", color: .secondary)),
    ]

    private static let remoteIcon = FileTypeIcon(symbol: "globe", color: .blue)
    private static let missingIcon = FileTypeIcon(symbol: "questionmark.square.dashed", color: .orange)

    /// The symbol to draw, or nil when Finder's own icon is the better choice
    /// (folders, apps and other bundles carry real artwork).
    static func icon(for item: DrakeItem, info: FileInfo) -> FileTypeIcon? {
        guard let url = item.fileURL else { return remoteIcon }
        if !info.exists { return missingIcon }

        let type = info.contentType

        // Folders, apps and packages have distinctive icons of their own.
        if let type, type.conforms(to: .directory) || type.conforms(to: .package)
            || type.conforms(to: .application) || type.conforms(to: .bundle) {
            return nil
        }

        let extensionKey = url.pathExtension.lowercased()
        if let override = overrides[extensionKey] { return override }

        guard let type else { return nil }
        return byType.first { type.conforms(to: $0.0) }?.1
    }
}

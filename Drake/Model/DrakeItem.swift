//
//  DrakeItem.swift
//  Drake
//
//  A single draggable thing: either a file on disk or a bare URI.
//

import Foundation

nonisolated struct DrakeItem: Identifiable, Hashable, Codable {
    let id: UUID
    /// Exactly what was passed on the command line, dropped, or restored.
    let raw: String
    /// `file://` URI for files, the URI itself otherwise. This is what goes on
    /// the pasteboard and what target mode prints.
    let uri: String
    /// Non-nil for files; `nil` for remote URIs such as `https://…`.
    let fileURL: URL?

    var isFile: Bool { fileURL != nil }

    init(id: UUID = UUID(), raw: String, uri: String, fileURL: URL?) {
        self.id = id
        self.raw = raw
        self.uri = uri
        self.fileURL = fileURL
    }

    // MARK: - Construction

    /// Classifies a command-line argument as a URI or a filesystem path.
    static func fromArgument(_ argument: String, relativeTo base: URL) -> DrakeItem {
        if let url = URL(string: argument), url.scheme != nil, Self.looksLikeURI(argument) {
            if url.isFileURL {
                return file(at: url.standardizedFileURL, raw: argument)
            }
            return DrakeItem(raw: argument, uri: argument, fileURL: nil)
        }

        let expanded = (argument as NSString).expandingTildeInPath
        // The base has to be a directory URL, or relative resolution would
        // replace its last path component instead of appending to it. And
        // .absoluteURL folds the base in, so `path` is not left relative.
        let directory = base.hasDirectoryPath ? base : URL(fileURLWithPath: base.path, isDirectory: true)
        let url = URL(fileURLWithPath: expanded, relativeTo: directory).absoluteURL.standardizedFileURL
        return file(at: url, raw: argument)
    }

    static func file(at url: URL, raw: String? = nil) -> DrakeItem {
        DrakeItem(raw: raw ?? url.path, uri: url.absoluteString, fileURL: url)
    }

    static func uri(_ string: String) -> DrakeItem {
        DrakeItem(raw: string, uri: string, fileURL: nil)
    }

    /// `scheme://…` or one of the common schemeless-authority URIs.
    /// A bare Unix path never matches, so `./a:b` stays a filename.
    private static func looksLikeURI(_ string: String) -> Bool {
        guard let colon = string.firstIndex(of: ":") else { return false }
        let scheme = string[string.startIndex..<colon]
        guard scheme.count > 1, let first = scheme.first, first.isLetter else { return false }
        let valid = scheme.allSatisfy { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "." || $0 == "-" }
        guard valid else { return false }
        if string[colon...].hasPrefix("://") { return true }
        return ["mailto", "magnet", "tel", "sms", "data", "about"].contains(scheme.lowercased())
    }

    // MARK: - Presentation

    /// Checks the disk. For acting on a file; views read `FileInfoCache`.
    var exists: Bool {
        guard let fileURL else { return true }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    func label(style: NameStyle, relativeTo base: URL) -> String {
        guard let fileURL else { return raw }
        switch style {
        case .basename:
            return fileURL.lastPathComponent
        case .fullPath:
            return PathFormatting.abbreviate(fileURL.path, limit: 44)
        case .relative:
            guard let relative = Self.relativePath(of: fileURL, under: base) else {
                return PathFormatting.abbreviate(fileURL.path, limit: 44)
            }
            return PathFormatting.abbreviate(relative, limit: 44, keepingLast: 1)
        }
    }

    /// Whether two URLs name the same directory. Compared as normalised
    /// components so a trailing slash or an unresolved symlink (`/tmp` against
    /// `/private/tmp`) does not make one folder look like two.
    static func isSameDirectory(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL.resolvingSymlinksInPath().pathComponents
            == rhs.standardizedFileURL.resolvingSymlinksInPath().pathComponents
    }

    /// Path relative to `base`, or nil when the file is not under it.
    static func relativePath(of url: URL, under base: URL) -> String? {
        let target = url.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let root = base.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        guard target.count > root.count, Array(target.prefix(root.count)) == root else { return nil }
        return target.dropFirst(root.count).joined(separator: "/")
    }

    /// Secondary line under the name: size or kind, then the containing folder
    /// when the file lives somewhere other than the working directory. Files in
    /// the working directory say nothing about their location, and an unknown
    /// size says nothing at all rather than showing a bare separator.
    func detail(_ info: FileInfo, relativeTo base: URL) -> String {
        guard let fileURL else { return uri }

        let lead: String
        if !info.exists {
            lead = "missing"
        } else if info.isDirectory {
            lead = "Folder"
        } else {
            lead = info.sizeDescription
        }

        let folder = fileURL.deletingLastPathComponent()
        let location = Self.isSameDirectory(folder, base)
            ? ""
            : PathFormatting.abbreviate(folder.path, limit: 38)

        return [lead, location].filter { !$0.isEmpty }.joined(separator: " - ")
    }

    /// What a plain-text drop target receives. Paths are more useful than
    /// percent-encoded URIs when dropping into an editor or a terminal.
    var dragText: String { fileURL?.path ?? uri }

    /// The URL a drag hands over. For a file it is the real file, with every
    /// symlink resolved: a sandboxed target such as WhatsApp is only granted
    /// the exact path it receives, so a link pointing elsewhere (say
    /// ~/notes.md -> ~/Dropbox/notes.md) would be unreadable and the drop
    /// refused. realpath rather than resolvingSymlinksInPath,
    /// which turns /private/tmp/… back into /tmp/…, itself a symlink.
    var dragURI: String {
        guard let fileURL, let resolved = realpath(fileURL.path, nil) else { return uri }
        defer { free(resolved) }
        return URL(fileURLWithPath: String(cString: resolved), isDirectory: fileURL.hasDirectoryPath)
            .absoluteString
    }

    /// What target mode prints on standard output.
    func outputLine(printPath: Bool) -> String {
        if printPath, let path = fileURL?.path { return path }
        return uri
    }
}

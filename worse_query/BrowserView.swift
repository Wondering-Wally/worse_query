//
//  BrowserView.swift
//  worse_query
//

import SwiftUI

struct FileEntry: Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let isDir: Bool
    let size: Int64?
    let bundleID: String?
}

// Reads the container-manager bundle identifier xattr off a directory.
func bundleID(at path: String) -> String? {
    var buf = [CChar](repeating: 0, count: 512)
    guard getxattr(path, "com.apple.containermanager.identifier", &buf, 511, 0, 0) > 0 else {
        return nil
    }
    return String(cString: buf)
}

struct BrowserView: View {
    @StateObject private var model = BrowserModel()
    @EnvironmentObject private var store: ExtensionStore
    @State private var searchText = ""

    private var filteredApps: [AppContainer] {
        if searchText.isEmpty { return model.apps }
        return model.apps.filter {
            $0.bundleID.localizedCaseInsensitiveContains(searchText)
                || ($0.name?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var userApps: [AppContainer] {
        filteredApps.filter { !$0.bundleID.hasPrefix("com.apple.") && !$0.isUUID }
    }

    private var appleApps: [AppContainer] {
        filteredApps.filter { $0.bundleID.hasPrefix("com.apple.") }
    }

    private var unknownApps: [AppContainer] {
        filteredApps.filter { $0.isUUID }
    }

    var body: some View {
        NavigationStack {
            List {
                if !userApps.isEmpty {
                    Section("Apps") {
                        ForEach(userApps, content: appRow)
                    }
                }
                if !appleApps.isEmpty {
                    Section("Apple") {
                        ForEach(appleApps, content: appRow)
                    }
                }
                if !unknownApps.isEmpty {
                    Section("Other") {
                        ForEach(unknownApps, content: appRow)
                    }
                }

                Section {
                    Button {
                        model.discoverApps()
                    } label: {
                        HStack {
                            Text(model.isScanning ? model.scanStatus : "Scan for Apps")
                            if model.isScanning {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(model.isScanning)
                    if !model.isScanning && !model.scanStatus.isEmpty {
                        Text(model.scanStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Roots") {
                    ForEach(model.roots) { root in
                        NavigationLink(root.title) {
                            DirectoryView(path: root.path, title: root.title)
                        }
                    }
                }

                Section("This App") {
                    NavigationLink("App Sandbox") {
                        DirectoryView(path: NSHomeDirectory(), title: "Sandbox")
                    }
                    Button("Release All Extensions") {
                        store.releaseAll()
                    }
                }
            }
            .navigationTitle("worse_query")
            .searchable(text: $searchText, prompt: "Filter by name or bundle ID")
        }
    }

    private func appRow(_ app: AppContainer) -> some View {
        NavigationLink {
            DirectoryView(path: app.path, title: app.name ?? app.bundleID)
        } label: {
            VStack(alignment: .leading) {
                Text(app.name ?? app.bundleID)
                Text(app.isUUID ? (app.path as NSString).lastPathComponent : app.bundleID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct DirectoryView: View {
    let path: String
    let title: String
    @EnvironmentObject private var store: ExtensionStore
    @State private var entries: [FileEntry] = []
    @State private var error: String?

    var body: some View {
        Group {
            if let error {
                ContentUnavailableView(
                    "Access Denied",
                    systemImage: "lock.fill",
                    description: Text(error)
                )
            } else {
                List(entries) { entry in
                    NavigationLink {
                        if entry.isDir {
                            DirectoryView(path: entry.path, title: entry.name)
                        } else {
                            FileDetailView(path: entry.path)
                        }
                    } label: {
                        entryRow(entry)
                    }
                }
                .overlay {
                    if entries.isEmpty {
                        ContentUnavailableView(
                            "Empty",
                            systemImage: "folder",
                            description: Text("Nothing here (or unreadable).")
                        )
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { open() }
    }

    private func entryRow(_ entry: FileEntry) -> some View {
        HStack {
            Image(systemName: entry.isDir ? "folder" : "doc")
                .foregroundStyle(entry.isDir ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading) {
                Text(entry.name)
                    .lineLimit(1)
                if let bundleID = entry.bundleID {
                    Text(bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let size = entry.size {
                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func open() {
        if !store.isUnlocked(path) {
            let handle = store.consume(path)
            if handle < 0 {
                error = ExtensionStore.describe(handle)
                return
            }
        }
        load()
    }

    private func load() {
        let url = URL(fileURLWithPath: path)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey]
        ) else {
            error = "Couldn't list directory."
            return
        }
        entries = urls.map { fileURL in
            let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            let isDir = values?.isDirectory == true
            return FileEntry(
                name: fileURL.lastPathComponent,
                path: fileURL.path,
                isDir: isDir,
                size: isDir ? nil : values?.fileSize.map(Int64.init),
                bundleID: isDir ? bundleID(at: fileURL.path) : nil
            )
        }.sorted {
            ($0.isDir ? 0 : 1, $0.name.lowercased()) < ($1.isDir ? 0 : 1, $1.name.lowercased())
        }
    }
}

//
//  FileDetailView.swift
//  worse_query
//

import SwiftUI
import UniformTypeIdentifiers

struct FileDetailView: View {
    let path: String
    @State private var preview: String?
    @State private var isText = false
    @State private var copied = false

    private var url: URL { URL(fileURLWithPath: path) }

    private var attrs: [FileAttributeKey: Any]? {
        try? FileManager.default.attributesOfItem(atPath: path)
    }

    var body: some View {
        List {
            Section("Info") {
                LabeledContent("Name", value: url.lastPathComponent)
                if let size = attrs?[.size] as? Int64 {
                    LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                }
                if let date = attrs?[.modificationDate] as? Date {
                    LabeledContent("Modified", value: date.formatted())
                }
                if let posix = attrs?[.posixPermissions] as? Int {
                    LabeledContent("Permissions", value: String(posix, radix: 8))
                }
                if let owner = attrs?[.ownerAccountName] as? String {
                    LabeledContent("Owner", value: owner)
                }
                if let type = UTType(filenameExtension: url.pathExtension) {
                    LabeledContent("Type", value: type.localizedDescription ?? type.identifier)
                }
                Button(copied ? "Copied!" : "Copy Path") {
                    UIPasteboard.general.string = path
                    copied = true
                }
            }

            Section("Preview") {
                if isText, let preview {
                    ScrollView {
                        Text(preview)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 400)
                } else {
                    Text("No text preview available.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ShareLink(item: url) {
                    Label("Share / Export", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle(url.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .task { loadPreview() }
    }

    private func loadPreview() {
        // Property lists get a decoded, pretty-printed view (binary or XML).
        if url.pathExtension.lowercased() == "plist",
           let plist = (NSDictionary(contentsOf: url) ?? NSArray(contentsOf: url)) {
            preview = "\(plist)"
            isText = true
            return
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 65_536), !data.isEmpty else { return }
        if let string = String(data: data, encoding: .utf8) {
            preview = string
            isText = true
        } else if let string = String(data: data, encoding: .isoLatin1) {
            preview = string
            isText = true
        }
    }
}

//
//  BrowserModel.swift
//  worse_query
//

import Foundation
import Combine

struct AppContainer: Identifiable, Codable {
    var id: String { path }
    let path: String
    let bundleID: String
    let name: String?

    // True when we couldn't resolve a bundle ID and stored the UUID instead.
    var isUUID: Bool {
        bundleID == (path as NSString).lastPathComponent
    }
}

class BrowserModel: ObservableObject {
    struct Root: Identifiable {
        var id: String { path }
        let title: String
        let path: String
    }

    let roots: [Root] = [
        Root(title: "App Groups", path: "/private/var/mobile/Containers/Shared/AppGroup"),
        Root(title: "App Containers", path: "/private/var/mobile/Containers/Data/Application"),
        Root(title: "PluginKit Plugins", path: "/private/var/mobile/Containers/Data/PluginKitPlugin"),
        Root(title: "Internal Daemons", path: "/private/var/mobile/Containers/Data/InternalDaemon"),
        Root(title: "System Groups", path: "/private/var/containers/Shared/SystemGroup"),
        Root(title: "System Data", path: "/private/var/containers/Data/System"),
    ]

    @Published var apps: [AppContainer] = []
    @Published var isScanning = false
    @Published var scanStatus = ""

    private let cacheKey = "discoveredAppContainers"

    init() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([AppContainer].self, from: data) {
            apps = cached
        }
    }

    // Slow but reliable: brute-forces inodes under the app container
    // directory via pathleak, then resolves each container's bundle
    // identifier by briefly consuming an extension to read its xattr.
    func discoverApps() {
        guard !isScanning else { return }
        isScanning = true
        scanStatus = "Getting baseline inode…"

        let files = FileManager.default
        let baselineURL = files.temporaryDirectory.appendingPathComponent(".baseline_\(UUID().uuidString)")
        var maxInode: UInt64 = 0
        do {
            try "helloworld".write(to: baselineURL, atomically: true, encoding: .utf8)
            var info = stat()
            if stat(baselineURL.path, &info) == 0 {
                maxInode = info.st_ino
            }
            try files.removeItem(at: baselineURL)
        } catch {
            isScanning = false
            scanStatus = "Baseline failed."
            print("baseline failed: \(error)")
            return
        }
        guard maxInode > 0 else {
            isScanning = false
            scanStatus = "Couldn't get baseline inode."
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.scanStatus = "Scanning inodes…"
            }
            print("scanning inodes (max \(maxInode))…")

            let scanDir = "/private/var/mobile/Containers/Data/Application"
            let found = pathleak(scanDir, maxInode) ?? []
            var discovered: [AppContainer] = []

            for (index, path) in found.enumerated() {
                DispatchQueue.main.async {
                    self.scanStatus = "Resolving \(index + 1)/\(found.count)…"
                }
                let handle = worse_query(path, ExtensionStore.groupID, false, false)
                if handle > 0 {
                    var buf = [CChar](repeating: 0, count: 512)
                    var bundleID = (path as NSString).lastPathComponent
                    if getxattr(path, "com.apple.containermanager.identifier", &buf, 511, 0, 0) > 0 {
                        bundleID = String(cString: buf)
                    }

                    // While we hold the extension, grab the display name
                    // out of the container's metadata plist.
                    var name: String? = nil
                    let metaPath = path + "/.com.apple.mobile_container_manager.metadata.plist"
                    if let meta = NSDictionary(contentsOfFile: metaPath) as? [String: Any],
                       let info = meta["MCMMetadataInfo"] as? [String: Any] {
                        name = info["CFBundleDisplayName"] as? String
                            ?? info["CFBundleName"] as? String
                    }

                    discovered.append(AppContainer(path: path, bundleID: bundleID, name: name))
                    worse_query_release(handle)
                }
            }

            discovered.sort { ($0.name ?? $0.bundleID).lowercased() < ($1.name ?? $1.bundleID).lowercased() }
            DispatchQueue.main.async {
                self.apps = discovered
                self.isScanning = false
                self.scanStatus = discovered.isEmpty
                    ? "No containers found."
                    : "\(discovered.count) containers."
                if let data = try? JSONEncoder().encode(discovered) {
                    UserDefaults.standard.set(data, forKey: self.cacheKey)
                }
                print("found \(discovered.count) app containers")
            }
        }
    }
}

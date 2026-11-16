//
//  ExtensionStore.swift
//  worse_query
//

import Foundation
import Combine
import Security

// Shared sandbox extension state for the Browser and Tools tabs.
// Tracks which root paths we've consumed extensions on so the browser
// knows what it's allowed to read.
class ExtensionStore: ObservableObject {
    // Reads the App Group this build was actually signed with, so the same
    // binary works regardless of whose account provisioned it.
    static var groupID: String {
        if let task = SecTaskCreateFromSelf(kCFAllocatorDefault)?.takeRetainedValue(),
           let value = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString),
           let groups = value.takeRetainedValue() as? [String],
           let first = groups.first {
            return first
        }
        return "group.cc.forcequit.worse-query"
    }

    private var handles: [String: Int64] = [:]

    func handle(for path: String) -> Int64 {
        handles[path] ?? -255
    }

    // Consumes a sandbox extension for a path via the worse_query exploit.
    // Returns the extension handle, or a negative error code.
    func consume(_ path: String) -> Int64 {
        if let handle = handles[path], handle > 0 {
            return handle
        }

        var alt = false
        if path.contains("/var/mobile/Containers/Shared/AppGroup") &&
            ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26 {
            alt = true
        }
        let handle = worse_query(path, Self.groupID, alt, false)
        print(Self.describe(handle))
        if handle > 0 {
            handles[path] = handle
        }
        return handle
    }

    func release(_ path: String) {
        guard let handle = handles[path] else { return }
        worse_query_release(handle)
        handles.removeValue(forKey: path)
        print("released extension for \(path)")
    }

    func release(handle: Int64) {
        guard let path = handles.first(where: { $0.value == handle })?.key else { return }
        release(path)
    }

    func releaseAll() {
        for (path, handle) in handles {
            worse_query_release(handle)
            print("released extension for \(path)")
        }
        handles.removeAll()
    }

    // True if the path is inside our own sandbox or under a consumed root.
    func isUnlocked(_ path: String) -> Bool {
        if path.hasPrefix(NSHomeDirectory()) {
            return true
        }
        return handles.keys.contains { path.hasPrefix($0) }
    }

    static func describe(_ handle: Int64) -> String {
        switch handle {
        case -1:
            return "failed to access group!"
        case -2:
            return "failed to resolve functions!"
        case -3:
            return "failed to create query!"
        case -4:
            return "failed to create symlink!"
        case -5:
            return "query rejected!"
        case -6:
            return "kernel refused extension issue!"
        case -255:
            return "target doesn't exist!"
        default:
            return "handle: \(handle)"
        }
    }
}

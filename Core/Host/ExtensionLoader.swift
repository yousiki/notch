import AppKit
import Foundation
import NotchKit

/// Discovers `.notchext` bundles, loads them, and activates each on the
/// supplied host. Failures are logged and skipped — one bad extension does
/// not abort loading.
final class ExtensionLoader {

    struct LoadFailure {
        let bundleURL: URL
        let reason: String
    }

    private(set) var failures: [LoadFailure] = []

    func load(into host: ExtensionHost) {
        let urls = scanBundles()
        NSLog("[ExtensionLoader] Discovered %d .notchext bundle(s): %@",
              urls.count, urls.map(\.lastPathComponent).joined(separator: ", "))
        for url in urls {
            loadBundle(url: url, into: host)
        }
        if failures.isEmpty {
            NSLog("[ExtensionLoader] All bundles loaded successfully")
        } else {
            for f in failures {
                NSLog("[ExtensionLoader] FAILED: %@ — %@", f.bundleURL.lastPathComponent, f.reason)
            }
        }
        NSLog("[ExtensionLoader] Registered tabs: %@",
              host.tabs.map(\.identifier).joined(separator: ", "))
    }

    private func scanBundles() -> [URL] {
        var urls: [URL] = []

        if let plugInsURL = Bundle.main.builtInPlugInsURL {
            urls.append(contentsOf: scan(directory: plugInsURL))
        }

        if let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first {
            let userDir = appSupport
                .appendingPathComponent("Notch", isDirectory: true)
                .appendingPathComponent("Extensions", isDirectory: true)
            urls.append(contentsOf: scan(directory: userDir))
        }
        return urls
    }

    private func scan(directory: URL) -> [URL] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil) else { return [] }
        return entries.filter { $0.pathExtension == "notchext" }
    }

    private func loadBundle(url: URL, into host: ExtensionHost) {
        guard let bundle = Bundle(url: url) else {
            failures.append(.init(bundleURL: url, reason: "Bundle(url:) returned nil"))
            return
        }
        do {
            try bundle.loadAndReturnError()
        } catch {
            failures.append(.init(bundleURL: url, reason: "loadAndReturnError: \(error)"))
            return
        }
        guard let principalClass = bundle.principalClass as? NSObject.Type,
              let extType = principalClass as? NotchExtension.Type else {
            failures.append(.init(bundleURL: url, reason: "principalClass is not NotchExtension"))
            return
        }

        let ext = extType.make()
        NSLog("[ExtensionLoader] Activating extension: %@ (%@)", ext.displayName, ext.identifier)
        let exception = ObjCExceptionCatcher.try {
            ext.activate(host: host)
        }
        if let exception {
            failures.append(.init(bundleURL: url,
                reason: "activate threw NSException: \(exception)"))
            host.logger.log(level: .error,
                message: "Extension \(ext.identifier) threw during activate: \(exception)")
        }
    }
}

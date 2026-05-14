//
//  SkyLightPrivateAPI.swift
//  boringNotch
//
//  Created by Codex on 2026-05-14.
//

import AppKit
import Foundation

enum SkyLightPrivateAPIError: Error, CustomStringConvertible {
    case frameworkUnavailable(String)
    case symbolUnavailable(String)

    var description: String {
        switch self {
        case .frameworkUnavailable(let path):
            "Could not load SkyLight framework at \(path)"
        case .symbolUnavailable(let symbol):
            "Could not load SkyLight symbol \(symbol)"
        }
    }
}

final class SkyLightPrivateAPI: @unchecked Sendable {
    private typealias RemoveWindowsFromSpaces = @convention(c) (Int32, CFArray, CFArray) -> Int32

    nonisolated(unsafe) static let shared = SkyLightPrivateAPI()

    private let removeWindowsFromSpaces: RemoveWindowsFromSpaces?

    private init() {
        do {
            removeWindowsFromSpaces = try Self.loadRemoveWindowsFromSpaces()
        } catch {
            removeWindowsFromSpaces = nil
            AppLogger.log("SkyLight unavailable: \(error)", category: .warning)
        }
    }

    @MainActor func remove(window: NSWindow, fromSpace space: Int32, connection: Int32) {
        guard let removeWindowsFromSpaces else { return }

        _ = removeWindowsFromSpaces(
            connection,
            [window.windowNumber] as CFArray,
            [space] as CFArray
        )
    }

    private static func loadRemoveWindowsFromSpaces() throws -> RemoveWindowsFromSpaces {
        let path = "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight"
        guard let handle = dlopen(path, RTLD_NOW) else {
            throw SkyLightPrivateAPIError.frameworkUnavailable(path)
        }

        guard let symbol = dlsym(handle, "SLSRemoveWindowsFromSpaces") else {
            throw SkyLightPrivateAPIError.symbolUnavailable("SLSRemoveWindowsFromSpaces")
        }

        return unsafeBitCast(symbol, to: RemoveWindowsFromSpaces.self)
    }
}

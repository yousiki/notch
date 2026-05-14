//
//  MediaRemoteClient.swift
//  boringNotch
//
//  Created by Codex on 2026-05-14.
//

import Foundation

enum MediaRemoteClientError: Error, CustomStringConvertible {
    case missingFramework
    case missingSymbol(String)

    var description: String {
        switch self {
        case .missingFramework:
            "Could not load MediaRemote.framework"
        case .missingSymbol(let symbol):
            "Could not load MediaRemote symbol \(symbol)"
        }
    }
}

struct MediaRemoteClient {
    private typealias SendCommand = @convention(c) (Int, AnyObject?) -> Void
    private typealias SetElapsedTime = @convention(c) (Double) -> Void
    private typealias SetMode = @convention(c) (Int) -> Void

    private let sendCommand: SendCommand
    private let setElapsedTime: SetElapsedTime
    private let setShuffleMode: SetMode
    private let setRepeatMode: SetMode

    init() throws {
        guard
            let bundle = CFBundleCreate(
                kCFAllocatorDefault,
                URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework") as CFURL)
        else {
            throw MediaRemoteClientError.missingFramework
        }

        sendCommand = try Self.loadSymbol("MRMediaRemoteSendCommand", from: bundle, as: SendCommand.self)
        setElapsedTime = try Self.loadSymbol(
            "MRMediaRemoteSetElapsedTime", from: bundle, as: SetElapsedTime.self)
        setShuffleMode = try Self.loadSymbol(
            "MRMediaRemoteSetShuffleMode", from: bundle, as: SetMode.self)
        setRepeatMode = try Self.loadSymbol(
            "MRMediaRemoteSetRepeatMode", from: bundle, as: SetMode.self)
    }

    func play() {
        sendCommand(0, nil)
    }

    func pause() {
        sendCommand(1, nil)
    }

    func togglePlay() {
        sendCommand(2, nil)
    }

    func nextTrack() {
        sendCommand(4, nil)
    }

    func previousTrack() {
        sendCommand(5, nil)
    }

    func seek(to time: Double) {
        setElapsedTime(time)
    }

    func setShuffleMode(_ mode: Int) {
        setShuffleMode(mode)
    }

    func setRepeatMode(_ mode: Int) {
        setRepeatMode(mode)
    }

    private static func loadSymbol<T>(_ name: String, from bundle: CFBundle, as type: T.Type) throws -> T {
        guard let pointer = CFBundleGetFunctionPointerForName(bundle, name as CFString) else {
            throw MediaRemoteClientError.missingSymbol(name)
        }
        return unsafeBitCast(pointer, to: type)
    }
}

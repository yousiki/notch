//
//  PrivateFrameworkLoader.swift
//  BoringNotchXPCHelper
//
//  Created by Codex on 2026-05-14.
//

import CoreGraphics
import Foundation
import OSLog

enum PrivateFrameworkLoadError: Error, CustomStringConvertible {
    case frameworkUnavailable([String])
    case classUnavailable(String)
    case methodUnavailable(String)
    case symbolUnavailable(String)

    var description: String {
        switch self {
        case .frameworkUnavailable(let paths):
            "Could not load private framework from: \(paths.joined(separator: ", "))"
        case .classUnavailable(let className):
            "Could not load private framework class: \(className)"
        case .methodUnavailable(let methodName):
            "Could not load private framework method: \(methodName)"
        case .symbolUnavailable(let symbol):
            "Could not load private framework symbol: \(symbol)"
        }
    }
}

enum XPCHelperLog {
    static let privateAPI = Logger(
        subsystem: "theboringteam.boringnotch.BoringNotchXPCHelper",
        category: "PrivateAPI"
    )
}

struct DynamicLibrary {
    let handle: UnsafeMutableRawPointer

    init(paths: [String]) throws {
        for path in paths {
            if let handle = dlopen(path, RTLD_LAZY) {
                self.handle = handle
                return
            }
        }

        throw PrivateFrameworkLoadError.frameworkUnavailable(paths)
    }

    func symbol<T>(_ name: String, as type: T.Type) throws -> T {
        guard let pointer = dlsym(handle, name) else {
            throw PrivateFrameworkLoadError.symbolUnavailable(name)
        }

        return unsafeBitCast(pointer, to: type)
    }
}

final class KeyboardBrightnessClient: @unchecked Sendable {
    private static let keyboardID: UInt64 = 1
    private typealias BrightnessGetter = @convention(c) (NSObject, Selector, UInt64) -> Float
    private typealias BrightnessSetter = @convention(c) (NSObject, Selector, Float, UInt64) -> ObjCBool

    private let clientInstance: NSObject
    private let getSelector = NSSelectorFromString("brightnessForKeyboard:")
    private let setSelector = NSSelectorFromString("setBrightness:forKeyboard:")
    private let getBrightness: BrightnessGetter
    private let setBrightnessValue: BrightnessSetter

    init?() {
        do {
            try Self.loadCoreBrightness()
            guard let cls = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type else {
                throw PrivateFrameworkLoadError.classUnavailable("KeyboardBrightnessClient")
            }

            let instance = cls.init()
            clientInstance = instance
            getBrightness = try Self.methodIMP(
                on: instance,
                selector: getSelector,
                as: BrightnessGetter.self)
            setBrightnessValue = try Self.methodIMP(
                on: instance,
                selector: setSelector,
                as: BrightnessSetter.self)
        } catch {
            XPCHelperLog.privateAPI.warning(
                "CoreBrightness unavailable: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    func currentBrightness() -> Float {
        getBrightness(clientInstance, getSelector, Self.keyboardID)
    }

    func setBrightness(_ value: Float) -> Bool {
        setBrightnessValue(clientInstance, setSelector, value, Self.keyboardID).boolValue
    }

    private static func loadCoreBrightness() throws {
        let bundlePaths = [
            "/System/Library/PrivateFrameworks/CoreBrightness.framework",
            "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",
        ]

        for path in bundlePaths {
            if Bundle(path: path)?.load() == true {
                return
            }
        }

        throw PrivateFrameworkLoadError.frameworkUnavailable(bundlePaths)
    }

    private static func methodIMP<T>(on object: NSObject, selector: Selector, as type: T.Type) throws -> T {
        guard let cls = object_getClass(object),
            let method = class_getInstanceMethod(cls, selector)
        else {
            throw PrivateFrameworkLoadError.methodUnavailable(NSStringFromSelector(selector))
        }

        let imp = method_getImplementation(method)
        return unsafeBitCast(imp, to: type)
    }
}

final class DisplayServicesClient: @unchecked Sendable {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let getBrightness: GetBrightness
    private let setBrightness: SetBrightness

    init?() {
        do {
            let library = try DynamicLibrary(paths: [
                "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
                "/System/Library/PrivateFrameworks/DisplayServices.framework/Versions/Current/DisplayServices",
            ])
            getBrightness = try library.symbol("DisplayServicesGetBrightness", as: GetBrightness.self)
            setBrightness = try library.symbol("DisplayServicesSetBrightness", as: SetBrightness.self)
        } catch {
            XPCHelperLog.privateAPI.warning(
                "DisplayServices unavailable: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    func currentBrightness(displayID: CGDirectDisplayID) -> Float? {
        var brightness: Float = 0
        guard getBrightness(displayID, &brightness) == 0 else { return nil }
        return brightness
    }

    func setBrightness(_ value: Float, displayID: CGDirectDisplayID) -> Bool {
        setBrightness(displayID, value) == 0
    }
}

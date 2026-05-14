//
//  BoringNotchXPCHelper.swift
//  BoringNotchXPCHelper
//
//  Created by Alexander on 2025-11-16.
//

import ApplicationServices
import CoreGraphics
import Foundation
import IOKit

private final class BoolXPCReply: @unchecked Sendable {
    private let reply: (Bool) -> Void

    init(_ reply: @escaping (Bool) -> Void) {
        self.reply = reply
    }

    func callAsFunction(_ value: Bool) {
        reply(value)
    }
}

class BoringNotchXPCHelper: NSObject, BoringNotchXPCHelperProtocol {

    @objc func isAccessibilityAuthorized(with reply: @escaping (Bool) -> Void) {
        reply(AXIsProcessTrusted())
    }

    @objc func requestAccessibilityAuthorization() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    @objc func ensureAccessibilityAuthorization(_ promptIfNeeded: Bool, with reply: @escaping (Bool) -> Void) {
        if AXIsProcessTrusted() {
            reply(true)
            return
        }

        if promptIfNeeded {
            requestAccessibilityAuthorization()
        }

        let delayedReply = BoolXPCReply(reply)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            delayedReply(AXIsProcessTrusted())
        }
    }

    private static let keyboardClient = KeyboardBrightnessClient()
    private static let displayServicesClient = DisplayServicesClient()

    @objc func isKeyboardBrightnessAvailable(with reply: @escaping (Bool) -> Void) {
        reply(Self.keyboardClient != nil)
    }

    @objc func currentKeyboardBrightness(with reply: @escaping (NSNumber?) -> Void) {
        reply(Self.keyboardClient.map { NSNumber(value: $0.currentBrightness()) })
    }

    @objc func setKeyboardBrightness(_ value: Float, with reply: @escaping (Bool) -> Void) {
        reply(Self.keyboardClient?.setBrightness(value) ?? false)
    }
    // MARK: - Screen Brightness (moved from client app into helper)

    @objc func isScreenBrightnessAvailable(with reply: @escaping (Bool) -> Void) {
        reply(
            Self.displayServicesClient?.currentBrightness(displayID: CGMainDisplayID()) != nil
                || ioServiceFor(displayID: CGMainDisplayID()) != nil
        )
    }

    @objc func currentScreenBrightness(with reply: @escaping (NSNumber?) -> Void) {
        if let brightness = Self.displayServicesClient?.currentBrightness(displayID: CGMainDisplayID()) {
            reply(NSNumber(value: brightness))
            return
        }
        if let io = ioServiceFor(displayID: CGMainDisplayID()) {
            var level: Float = 0
            if IODisplayGetFloatParameter(io, 0, kIODisplayBrightnessKey as CFString, &level) == kIOReturnSuccess {
                IOObjectRelease(io)
                reply(NSNumber(value: level))
                return
            }
            IOObjectRelease(io)
        }
        reply(nil)
    }

    @objc func setScreenBrightness(_ value: Float, with reply: @escaping (Bool) -> Void) {
        let clamped = max(0, min(1, value))
        if Self.displayServicesClient?.setBrightness(clamped, displayID: CGMainDisplayID()) == true {
            reply(true)
            return
        }
        if let io = ioServiceFor(displayID: CGMainDisplayID()) {
            let ok = IODisplaySetFloatParameter(io, 0, kIODisplayBrightnessKey as CFString, clamped) == kIOReturnSuccess
            IOObjectRelease(io)
            reply(ok)
            return
        }
        reply(false)
    }

    // MARK: - Private helpers for DisplayServices / IOKit access
    private func ioServiceFor(displayID: CGDirectDisplayID) -> io_service_t? {
        var iterator: io_iterator_t = 0
        guard
            IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator)
                == kIOReturnSuccess
        else { return nil }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            let info = IODisplayCreateInfoDictionary(service, 0).takeRetainedValue() as NSDictionary
            if let vendorID = info[kDisplayVendorID] as? UInt32,
                let productID = info[kDisplayProductID] as? UInt32,
                vendorID == CGDisplayVendorNumber(displayID),
                productID == CGDisplayModelNumber(displayID)
            {
                return service
            }
            IOObjectRelease(service)
        }
        return nil
    }
}

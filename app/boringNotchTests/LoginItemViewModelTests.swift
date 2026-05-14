//
//  LoginItemViewModelTests.swift
//  boringNotchTests
//
//  Created by Codex on 2026-05-14.
//

import XCTest

@testable import boringNotch

@MainActor
final class LoginItemViewModelTests: XCTestCase {
    func testInitialStateReflectsService() {
        let service = FakeLoginItemService(isEnabled: true)

        let viewModel = LoginItemViewModel(service: service)

        XCTAssertTrue(viewModel.isEnabled)
        XCTAssertNil(viewModel.errorDescription)
    }

    func testSetEnabledDelegatesToServiceAndRefreshesState() {
        let service = FakeLoginItemService(isEnabled: false)
        let viewModel = LoginItemViewModel(service: service)

        viewModel.setEnabled(true)

        XCTAssertTrue(viewModel.isEnabled)
        XCTAssertEqual(service.requestedValues, [true])
        XCTAssertNil(viewModel.errorDescription)
    }

    func testSetEnabledRollsBackWhenServiceFails() {
        let service = FakeLoginItemService(isEnabled: false)
        service.errorToThrow = FakeLoginItemError.denied
        let viewModel = LoginItemViewModel(service: service)

        viewModel.setEnabled(true)

        XCTAssertFalse(viewModel.isEnabled)
        XCTAssertEqual(service.requestedValues, [true])
        XCTAssertEqual(viewModel.errorDescription, FakeLoginItemError.denied.localizedDescription)
    }
}

private final class FakeLoginItemService: LoginItemServiceProtocol {
    private(set) var requestedValues: [Bool] = []
    var errorToThrow: Error?
    var isEnabled: Bool

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    func setEnabled(_ enabled: Bool) throws {
        requestedValues.append(enabled)

        if let errorToThrow {
            throw errorToThrow
        }

        isEnabled = enabled
    }
}

private enum FakeLoginItemError: LocalizedError {
    case denied

    var errorDescription: String? {
        "Login item update denied"
    }
}

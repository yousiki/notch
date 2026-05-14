//
//  LoginItemManager.swift
//  boringNotch
//
//  Created by Codex on 2026-05-14.
//

import Foundation
import ServiceManagement
import SwiftUI

protocol LoginItemServiceProtocol {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

struct MainAppLoginItemService: LoginItemServiceProtocol {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp

        if enabled {
            guard service.status != .enabled else { return }
            try service.register()
        } else {
            guard service.status == .enabled else { return }
            try service.unregister()
        }
    }
}

@MainActor
final class LoginItemViewModel: ObservableObject {
    @Published private(set) var errorDescription: String?
    @Published var isEnabled: Bool

    private let service: LoginItemServiceProtocol

    init(service: LoginItemServiceProtocol = MainAppLoginItemService()) {
        self.service = service
        self.isEnabled = service.isEnabled
    }

    func refresh() {
        isEnabled = service.isEnabled
        errorDescription = nil
    }

    func setEnabled(_ enabled: Bool) {
        let previousValue = isEnabled
        isEnabled = enabled
        errorDescription = nil

        do {
            try service.setEnabled(enabled)
            isEnabled = service.isEnabled
        } catch {
            isEnabled = previousValue
            errorDescription = error.localizedDescription
            AppLogger.log("Failed to update login item: \(error)", category: .error)
        }
    }
}

struct LoginItemToggle: View {
    @StateObject private var viewModel: LoginItemViewModel

    init(service: LoginItemServiceProtocol = MainAppLoginItemService()) {
        _viewModel = StateObject(wrappedValue: LoginItemViewModel(service: service))
    }

    var body: some View {
        Toggle(
            isOn: Binding(
                get: { viewModel.isEnabled },
                set: { viewModel.setEnabled($0) }
            )
        ) {
            Text("Launch at login")
        }
        .tint(.effectiveAccent)
        .help(viewModel.errorDescription ?? "")
        .onAppear {
            viewModel.refresh()
        }
    }
}

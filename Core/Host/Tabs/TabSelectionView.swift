//
//  TabSelectionView.swift
//  Capsule
//
//  Created by Hugo Persson on 2024-08-25.
//

import Defaults
import SwiftUI

struct TabModel: Identifiable {
    let id: String
    let label: String
    let icon: String
}

struct TabSelectionView: View {
    @ObservedObject var coordinator = CapsuleViewCoordinator.shared
    @StateObject private var shelfState = ShelfStateViewModel.shared
    @Default(.capsuleShelf) private var capsuleShelf
    @State private var extensionLoadRevision = 0
    @Namespace var animation

    private var tabs: [TabModel] {
        _ = extensionLoadRevision

        var result = [
            TabModel(id: CapsuleTabIdentifier.home, label: "Home", icon: "house.fill")
        ]

        if capsuleShelf && (!shelfState.isEmpty || coordinator.alwaysShowTabs) {
            result.append(TabModel(id: CapsuleTabIdentifier.shelf, label: "Shelf", icon: "tray.fill"))
        }

        result.append(contentsOf: ExtensionHost.shared.tabs.compactMap { tab in
            guard tab.identifier != CapsuleTabIdentifier.home,
                  tab.identifier != CapsuleTabIdentifier.shelf
            else { return nil }
            return TabModel(id: tab.identifier, label: tab.title, icon: tab.systemImage)
        })

        return result
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                TabButton(
                    label: tab.label,
                    icon: tab.icon,
                    selected: coordinator.currentTabIdentifier == tab.id
                ) {
                    withAnimation(.smooth) {
                        coordinator.showTab(tab.id)
                    }
                }
                .frame(height: 26)
                .foregroundStyle(coordinator.currentTabIdentifier == tab.id ? .white : .gray)
                .background {
                    Capsule()
                        .fill(coordinator.currentTabIdentifier == tab.id ? Color(nsColor: .secondarySystemFill) : Color.clear)
                        .matchedGeometryEffect(id: "capsule", in: animation)
                        .opacity(coordinator.currentTabIdentifier == tab.id ? 1 : 0)
                }
            }
        }
        .clipShape(Capsule())
        .onReceive(NotificationCenter.default.publisher(for: ExtensionHost.didLoadExtensionsNotification)) { _ in
            extensionLoadRevision += 1
        }
    }
}

#Preview {
    CapsuleHeader().environmentObject(CapsuleViewModel())
}

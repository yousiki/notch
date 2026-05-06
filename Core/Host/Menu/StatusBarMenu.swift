import Cocoa
import CapsuleKit

class CapsuleStatusMenu: NSMenu {
    
    var statusItem: NSStatusItem!
    
    override init() {
        super.init()
        
        // Initialize the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Capsule")
            button.action = #selector(showMenu)
        }
        
        // Set up the menu
        let menu = NSMenu()
        let extensionItems = ExtensionHost.shared.menuBarItems
        if !extensionItems.isEmpty {
            for item in extensionItems {
                let mi = NSMenuItem(title: item.title, action: nil, keyEquivalent: item.keyEquivalent)
                mi.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: item.keyEquivalentModifiers)
                mi.target = MenuItemBox.shared
                mi.action = #selector(MenuItemBox.invoke(_:))
                mi.representedObject = MenuItemAction(block: item.action)
                menu.addItem(mi)
            }
            menu.addItem(NSMenuItem.separator())
        }
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitAction), keyEquivalent: "q"))
        statusItem.menu = menu
    }

}

private final class MenuItemAction: NSObject {
    let block: @convention(block) () -> Void
    init(block: @escaping @convention(block) () -> Void) { self.block = block }
}

private final class MenuItemBox: NSObject {
    static let shared = MenuItemBox()
    @objc func invoke(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? MenuItemAction else { return }
        action.block()
    }
}

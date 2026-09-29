import AppKit
import Foundation

func text(_ value: String, _ size: CGFloat = 13, _ weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
    let view = NSTextField(labelWithString: value)
    view.font = .systemFont(ofSize: size, weight: weight); view.textColor = color
    view.lineBreakMode = .byTruncatingTail
    return view
}
func symbol(_ name: String, color: NSColor = Product.accent, size: CGFloat = 18) -> NSImageView {
    let view = NSImageView(image: NSImage(systemSymbolName: name, accessibilityDescription: name) ?? NSImage())
    view.contentTintColor = color
    view.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
    return view
}
func vertical(_ views: [NSView], spacing: CGFloat = 12) -> NSStackView {
    let stack = NSStackView(views: views); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = spacing
    return stack
}
func horizontal(_ views: [NSView], spacing: CGFloat = 12) -> NSStackView {
    let stack = NSStackView(views: views); stack.orientation = .horizontal; stack.alignment = .centerY; stack.spacing = spacing
    return stack
}
func fill(_ view: NSView, in parent: NSView, inset: CGFloat = 0) {
    parent.addSubview(view); view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([view.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: inset), view.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -inset), view.topAnchor.constraint(equalTo: parent.topAnchor, constant: inset), view.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -inset)])
}
func fullWidth(_ view: NSView, _ stack: NSStackView) { view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
func spacer() -> NSView { let view = NSView(); view.setContentHuggingPriority(.defaultLow, for: .horizontal); return view }
func button(_ title: String, _ image: String? = nil, target: AnyObject, action: Selector, primary: Bool = false) -> NSButton {
    let view = NSButton(title: title, target: target, action: action); view.bezelStyle = .rounded
    if let image { view.image = NSImage(systemSymbolName: image, accessibilityDescription: title); view.imagePosition = .imageLeading }
    if primary { view.bezelColor = Product.accent }
    return view
}
final class Surface: NSView {
    let content: NSView
    init(_ content: NSView, padding: CGFloat = 18) { self.content = content; super.init(frame: .zero); fill(content, in: self, inset: padding) }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill(); NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12).fill()
        NSColor.separatorColor.withAlphaComponent(0.22).setStroke(); let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12); border.lineWidth = 1; border.stroke()
    }
}
final class Metric: NSView {
    let value: NSTextField
    init(_ title: String, value initial: String, icon: String) {
        value = text(initial, 28, .semibold)
        super.init(frame: .zero)
        let heading = horizontal([symbol(icon, size: 13), text(title, 11, .medium, color: .secondaryLabelColor)], spacing: 7)
        let stack = vertical([heading, value], spacing: 10); let surface = Surface(stack)
        fill(surface, in: self); heightAnchor.constraint(equalToConstant: 96).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }
}
func makeTable(_ columns: [(String,String,CGFloat)]) -> NSTableView {
    let table = NSTableView(); table.rowHeight = 42; table.intercellSpacing = NSSize(width: 12, height: 6)
    table.style = .fullWidth; table.usesAlternatingRowBackgroundColors = false; table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
    for (id,title,width) in columns { let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id)); column.title = title; column.width = width; column.minWidth = min(width, 90); table.addTableColumn(column) }
    return table
}
func scroll(_ table: NSTableView) -> NSScrollView {
    let view = NSScrollView(); view.documentView = table; view.hasVerticalScroller = true; view.autohidesScrollers = true; view.borderType = .noBorder
    return view
}
func cell(_ value: String, color: NSColor = .labelColor, bold: Bool = false) -> NSTableCellView {
    let cell = NSTableCellView(); let label = text(value, 13, bold ? .medium : .regular, color: color); cell.textField = label; cell.toolTip = value
    cell.addSubview(label); label.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8), label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8), label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
    return cell
}
class ProductAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var isDemo: Bool { CommandLine.arguments.contains("--demo") }
    var snapshotPath: String? { CommandLine.arguments.first(where: { $0.hasPrefix("--snapshot=") }).map { String($0.dropFirst(11)) } }
    func buildWindow() {}
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu(); let root = NSMenuItem(); let appMenu = NSMenu(title: Product.name)
        appMenu.addItem(withTitle: "About \(Product.name)", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(.separator()); appMenu.addItem(withTitle: "Quit \(Product.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        root.submenu = appMenu; menu.addItem(root)
        let edit = NSMenu(title: "Edit"); for (name, action, key) in [("Undo", "undo:", "z"),("Cut", "cut:", "x"),("Copy", "copy:", "c"),("Paste", "paste:", "v"),("Select All", "selectAll:", "a")] { edit.addItem(withTitle: name, action: Selector(action), keyEquivalent: key) }
        let editRoot = NSMenuItem(); editRoot.submenu = edit; menu.addItem(editRoot)
        let view = NSMenu(title: "Appearance")
        for mode in ["System", "Light", "Dark"] { let item = NSMenuItem(title: mode, action: #selector(theme(_:)), keyEquivalent: ""); item.target = self; view.addItem(item) }
        let viewRoot = NSMenuItem(); viewRoot.submenu = view; menu.addItem(viewRoot); NSApp.mainMenu = menu
        let appearance = CommandLine.arguments.contains("--light") ? "Light" : CommandLine.arguments.contains("--dark") ? "Dark" : UserDefaults.standard.string(forKey: "appearance") ?? "System"
        applyTheme(appearance)
        buildWindow(); window.delegate = self; window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        if CommandLine.arguments.contains("--minimum") { window.setFrame(NSRect(origin: window.frame.origin, size: window.minSize), display: true) }
        if let path = snapshotPath { window.makeFirstResponder(nil); DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            do { try self?.capture(path); print("SNAPSHOT_OK \(Product.name)"); exit(0) } catch { fputs("Snapshot failed: \(error)\n", stderr); exit(1) }
        } }
    }
    func makeWindow(width: CGFloat, height: CGFloat, minWidth: CGFloat, minHeight: CGFloat) {
        window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: width,height: height), styleMask: [.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView], backing: .buffered, defer: false)
        window.title = Product.name; window.titlebarAppearsTransparent = true; window.toolbarStyle = .unified
        window.minSize = NSSize(width: minWidth, height: minHeight); window.isReleasedWhenClosed = false
        if snapshotPath == nil { window.setFrameAutosaveName("MainWindow") }
    }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(options: [.applicationName: Product.name, .applicationVersion: Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "1.1.0", .credits: NSAttributedString(string: "A native Mac utility by leonsuv.\nMIT License · Local processing.")]) }
    @objc func theme(_ sender: NSMenuItem) { applyTheme(sender.title); if !isDemo { UserDefaults.standard.set(sender.title, forKey: "appearance") } }
    func applyTheme(_ mode: String) { NSApp.appearance = mode == "System" ? nil : NSAppearance(named: mode == "Dark" ? .darkAqua : .aqua) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func capture(_ path: String) throws {
        guard let view = window.contentView?.superview else { throw CocoaError(.fileWriteUnknown) }
        view.layoutSubtreeIfNeeded(); window.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw CocoaError(.fileWriteUnknown) }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: URL(fileURLWithPath: path)); print("RENDER \(bitmap.pixelsWide)×\(bitmap.pixelsHigh)")
    }
    func alert(_ title: String, _ message: String) { let alert = NSAlert(); alert.messageText = title; alert.informativeText = message; alert.addButton(withTitle: "OK"); alert.beginSheetModal(for: window) }
}

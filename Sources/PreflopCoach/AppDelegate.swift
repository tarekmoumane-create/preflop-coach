import AppKit
import Carbon.HIToolbox
import PreflopCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let client = VisionClient()
    private let overlay = Overlay()
    private let defaults = UserDefaults.standard
    private var hotKey: HotKey?
    private var timer: Timer?

    private var chart = Chart.builtIn
    private var isOn = false
    private var busy = false
    private var lastSignature: [UInt8]?
    private var nextReadAllowed = Date.distantPast
    private var lastReadAt: Date?
    private var reads = 0
    private var sessionCost = 0.0

    /// What the menu bar and the top of the menu currently show.
    private var title = "♠︎"
    private var titleColor: NSColor?
    private var lines: [String] = ["Off"]

    // MARK: Settings

    /// Seconds between automatic reads. 0 means only when the hotkey is pressed.
    private var interval: Double {
        get { defaults.object(forKey: "interval") as? Double ?? 3 }
        set { defaults.set(newValue, forKey: "interval") }
    }

    private var model: VisionModel {
        get { VisionModel.all.first { $0.id == defaults.string(forKey: "model") } ?? VisionModel.all[0] }
        set { defaults.set(newValue.id, forKey: "model") }
    }

    private var target: WatchTarget {
        get { defaults.string(forKey: "watchApp").map(WatchTarget.app) ?? .screen }
        set {
            if case .app(let name) = newValue {
                defaults.set(name, forKey: "watchApp")
            } else {
                defaults.removeObject(forKey: "watchApp")
            }
            lastSignature = nil
        }
    }

    private var rangesFile: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PreflopCoach", isDirectory: true)
        return folder.appendingPathComponent("ranges.json")
    }

    // MARK: Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEditMenu()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        loadRanges(complain: true)
        show("♠︎", lines: ["Off", "Click ♠︎ in the menu bar to turn on"])
        if !defaults.bool(forKey: "overlayHidden") { overlay.show() }
        Log.write("launched · screen permission: \(ScreenGrabber.hasPermission) · key: \(APIKeyStore.load() != nil) · model: \(model.id) · watch: \(target) · every \(interval)s")

        // `notifyutil`-style remote trigger for debugging: post this distributed notification to force a read.
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("local.preflopcoach.read"),
                                                            object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                Log.write("read requested from outside")
                await self.readTable(manual: true)
            }
        }

        // Control-Option-P reads the table once, whether or not automatic reading is on.
        hotKey = HotKey(keyCode: kVK_ANSI_P, modifiers: controlKey | optionKey) { [weak self] in
            guard let self else { return }
            Task { @MainActor in await self.readTable(manual: true) }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tick() }
        }
    }

    /// A menu bar app has no visible main menu, but text fields still route
    /// Command-V and friends through it, so the API key can be pasted.
    private func installEditMenu() {
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let item = NSMenuItem()
        item.submenu = edit
        let main = NSMenu()
        main.addItem(item)
        NSApp.mainMenu = main
    }

    // MARK: Reading the table

    private func tick() {
        guard isOn, interval > 0, !busy, Date() >= nextReadAllowed else { return }
        Task { await readTable(manual: false) }
    }

    private enum Shot {
        case failed
        case unchanged
        case taken(jpeg: Data, signature: [UInt8])
    }

    private func readTable(manual: Bool) async {
        guard !busy else { return }
        guard let key = APIKeyStore.load(), !key.isEmpty else {
            Log.write("read skipped: no API key")
            if manual { setAPIKey() }
            return
        }
        guard ScreenGrabber.hasPermission else {
            Log.write("read skipped: no screen recording permission")
            if manual { askForScreenPermission() }
            return
        }

        busy = true
        defer { busy = false }
        nextReadAllowed = Date().addingTimeInterval(interval)

        let target = self.target
        let previous = manual ? nil : lastSignature
        let menuBarHeight = NSScreen.screens.first.map { $0.frame.maxY - $0.visibleFrame.maxY } ?? 24
        let shot = await Task.detached(priority: .userInitiated) { () -> Shot in
            guard let image = ScreenGrabber.capture(target, menuBarHeight: menuBarHeight) else { return .failed }
            let signature = ScreenGrabber.signature(image)
            if let previous, !ScreenGrabber.changed(previous, signature) { return .unchanged }
            // A single window fills the frame, so it needs fewer pixels than a whole screen.
            guard let jpeg = ScreenGrabber.jpeg(image, maxEdge: target == .screen ? 2000 : 1568) else { return .failed }
            return .taken(jpeg: jpeg, signature: signature)
        }.value

        switch shot {
        case .unchanged:
            Log.write("screen unchanged, skipped")
            return
        case .failed:
            Log.write("capture failed for \(target)")
            if case .app(let name) = target {
                show("♠︎ ?", lines: ["Can't find a \(name) window. Pick another under Watch."])
            } else {
                show("♠︎ ?", lines: ["Couldn't capture the screen."])
            }
        case .taken(let jpeg, let signature):
            let started = Date()
            Log.write("sending \(jpeg.count / 1024) KB screenshot to \(model.id)")
            do {
                let result = try await client.read(jpeg: jpeg, model: model, apiKey: key)
                lastSignature = signature
                lastReadAt = Date()
                reads += 1
                sessionCost += result.cost
                Log.write(String(format: "reply in %.1fs, $%.4f: %@", Date().timeIntervalSince(started), result.cost, result.raw))
                present(result.read)
                Log.write("showing: \(title) — \(lines.joined(separator: " | "))")
            } catch let error as VisionError {
                Log.write("API error: \(error.message)")
                show("♠︎ ⚠", lines: [error.message])
                nextReadAllowed = Date().addingTimeInterval(15)
                if error.badKey { isOn = false }
            } catch {
                Log.write("error: \(error)")
                show("♠︎ ⚠", lines: [error.localizedDescription])
                nextReadAllowed = Date().addingTimeInterval(15)
            }
        }
    }

    private func present(_ read: TableRead) {
        switch interpret(read) {
        case .noTable:
            show(isOn ? "♠︎ no table" : "♠︎", lines: ["Watching…", "No poker table on screen."])
            // Nothing to coach, so look less often until a table shows up.
            nextReadAllowed = Date().addingTimeInterval(max(interval, 8))
        case .noHand:
            show("♠︎ waiting", lines: ["Waiting for the next hand."])
        case .postflop(let street):
            show("♠︎ \(street.capitalized)", lines: ["On the \(street)", "The chart covers preflop only."])
            nextReadAllowed = Date().addingTimeInterval(max(interval, 8))
        case .noCards:
            show("♠︎ waiting", lines: ["No hole cards to read. You've folded, or they aren't dealt yet."])
        case .unclear(let why):
            show("♠︎ ?", lines: ["Read the table but \(why).", "Press ⌃⌥P to try again."])
        case .ready(let situation):
            let advice = advise(situation, chart: chart)
            let seat = position(seat: situation.heroSeat, players: situation.players)
            // The menu bar gets the short form: "RAISE to 2.5bb (250)" becomes "RAISE 2.5bb".
            var short = advice.headline.replacingOccurrences(of: " to ", with: " ")
            if let cut = short.range(of: " (") { short = String(short[..<cut.lowerBound]) }
            let unsure = read.confidence == "low"

            var detail = [
                advice.headline,
                "\(situation.hero.pretty)  ·  \(seat.name), \(situation.players)-handed",
                advice.spot,
            ]
            if !read.heroToAct { detail.append("Not your turn yet. This is for the action so far.") }
            if let note = advice.note { detail.append(note) }
            if unsure { detail.append("Low-confidence read. Check the cards above match yours.") }

            let color: NSColor?
            switch advice.kind {
            case .raise, .allIn: color = .systemGreen
            case .call: color = .systemOrange
            case .fold: color = .systemRed
            case .check, .wait: color = nil
            }
            show("\(read.heroToAct ? "" : "next: ")\(short)\(unsure ? "?" : "")  \(situation.hero.pretty)", color: color, lines: detail)
        }
    }

    private func show(_ title: String, color: NSColor? = nil, lines: [String]) {
        self.title = title
        self.titleColor = color
        self.lines = lines
        overlay.update(headline: lines.first ?? "", color: color, detail: Array(lines.dropFirst().prefix(2)))
        render()
    }

    private func render() {
        var attributes: [NSAttributedString.Key: Any] = [.font: NSFont.menuBarFont(ofSize: 0)]
        if let titleColor {
            attributes[.foregroundColor] = titleColor
            attributes[.font] = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        }
        statusItem.button?.attributedTitle = NSAttributedString(string: title, attributes: attributes)
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        for (index, line) in lines.enumerated() {
            let item = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            if index == 0 {
                item.attributedTitle = NSAttributedString(string: line, attributes: [.font: NSFont.boldSystemFont(ofSize: 14)])
            }
            menu.addItem(item)
        }
        if let lastReadAt, isOn {
            let seconds = Int(Date().timeIntervalSince(lastReadAt))
            menu.addItem(NSMenuItem(title: "Read \(seconds)s ago", action: nil, keyEquivalent: ""))
        }
        menu.addItem(.separator())

        menu.addItem(action(isOn ? "Turn Off" : "Turn On", #selector(toggle)))
        let readNow = action("Read Now", #selector(readNow))
        readNow.keyEquivalent = "p"
        readNow.keyEquivalentModifierMask = [.control, .option]
        menu.addItem(readNow)
        let overlayItem = action("Show Overlay", #selector(toggleOverlay))
        overlayItem.state = overlay.isShown ? .on : .off
        menu.addItem(overlayItem)
        menu.addItem(.separator())

        let watch = NSMenu()
        watch.addItem(choice("Whole Screen", #selector(pickTarget(_:)), selected: target == .screen, value: nil))
        watch.addItem(.separator())
        var apps = ScreenGrabber.appsWithWindows()
        if case .app(let current) = target, !apps.contains(current) { apps.insert(current, at: 0) }
        for app in apps {
            watch.addItem(choice(app, #selector(pickTarget(_:)), selected: target == .app(app), value: app))
        }
        menu.addItem(submenu("Watch", watch))

        let pace = NSMenu()
        for seconds in [2.0, 3.0, 5.0, 10.0] {
            pace.addItem(choice("Every \(Int(seconds)) seconds", #selector(pickInterval(_:)), selected: interval == seconds, value: seconds))
        }
        pace.addItem(choice("Only when I press ⌃⌥P", #selector(pickInterval(_:)), selected: interval == 0, value: 0.0))
        menu.addItem(submenu("Check", pace))

        let models = NSMenu()
        for option in VisionModel.all {
            models.addItem(choice(option.name, #selector(pickModel(_:)), selected: option == model, value: option.id))
        }
        menu.addItem(submenu("Model", models))
        menu.addItem(.separator())

        menu.addItem(action(APIKeyStore.load() == nil ? "Set API Key…" : "Change API Key…", #selector(setAPIKey)))
        menu.addItem(action("Edit Ranges…", #selector(editRanges)))
        menu.addItem(action("Reload Ranges", #selector(reloadRanges)))
        menu.addItem(action("Show Log", #selector(showLog)))
        let login = action("Launch at Login", #selector(toggleLaunchAtLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        if reads > 0 {
            let summary = "This session: \(reads) read\(reads == 1 ? "" : "s"), about $\(String(format: "%.2f", sessionCost))"
            menu.addItem(NSMenuItem(title: summary, action: nil, keyEquivalent: ""))
        }
        menu.addItem(NSMenuItem(title: "Quit Preflop Coach", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    private func choice(_ title: String, _ selector: Selector, selected: Bool, value: Any?) -> NSMenuItem {
        let item = action(title, selector)
        item.state = selected ? .on : .off
        item.representedObject = value
        return item
    }

    private func submenu(_ title: String, _ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    // MARK: Actions

    @objc private func toggle() {
        if isOn {
            isOn = false
            Log.write("turned off")
            show("♠︎", lines: ["Off", "Click ♠︎ in the menu bar to turn on"])
            return
        }
        guard APIKeyStore.load() != nil || promptForAPIKey() else { return }
        // The first request shows macOS's own prompt and returns false until the app is relaunched.
        guard ScreenGrabber.hasPermission || CGRequestScreenCaptureAccess() else {
            Log.write("turn on refused: no screen recording permission")
            askForScreenPermission()
            return
        }
        isOn = true
        Log.write("turned on · watch: \(target) · every \(interval)s · model \(model.id)")
        lastSignature = nil
        nextReadAllowed = .distantPast
        show("♠︎ watching", lines: ["Watching…", interval > 0 ? "Looking for a table every \(Int(interval))s" : "Press ⌃⌥P to read the table"])
    }

    @objc private func toggleOverlay() {
        if overlay.isShown {
            overlay.hide()
        } else {
            overlay.show()
        }
        defaults.set(!overlay.isShown, forKey: "overlayHidden")
    }

    @objc private func readNow() {
        Task { await readTable(manual: true) }
    }

    @objc private func pickTarget(_ sender: NSMenuItem) {
        target = (sender.representedObject as? String).map(WatchTarget.app) ?? .screen
    }

    @objc private func pickInterval(_ sender: NSMenuItem) {
        interval = sender.representedObject as? Double ?? 3
    }

    @objc private func pickModel(_ sender: NSMenuItem) {
        if let chosen = VisionModel.all.first(where: { $0.id == sender.representedObject as? String }) { model = chosen }
    }

    @objc private func setAPIKey() {
        _ = promptForAPIKey()
    }

    private func promptForAPIKey() -> Bool {
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = "sk-ant-…"
        let alert = NSAlert()
        alert.messageText = "Anthropic API key"
        alert.informativeText = "Preflop Coach uses Claude to read the table. Create a key at console.anthropic.com under API Keys. It's stored in your Mac's keychain."
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return false }
        if !APIKeyStore.save(key) {
            warn("Couldn't save the key", "The keychain refused the item.")
            return false
        }
        return true
    }

    private func askForScreenPermission() {
        let alert = NSAlert()
        alert.messageText = "Allow screen recording"
        alert.informativeText = "To see the table, Preflop Coach needs permission under System Settings → Privacy & Security → Screen & System Audio Recording. Switch it on there, then quit and reopen Preflop Coach."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            warn("Couldn't change the login item", error.localizedDescription)
        }
    }

    // MARK: Ranges

    @objc private func editRanges() {
        writeDefaultRangesIfMissing()
        let textEdit = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        NSWorkspace.shared.open([rangesFile], withApplicationAt: textEdit, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func showLog() {
        if !FileManager.default.fileExists(atPath: Log.file.path) { Log.write("log started") }
        NSWorkspace.shared.open(Log.file)
    }

    @objc private func reloadRanges() {
        if loadRanges(complain: true) {
            lastSignature = nil
            let alert = NSAlert()
            alert.messageText = "Ranges reloaded"
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    private func writeDefaultRangesIfMissing() {
        let file = rangesFile
        guard !FileManager.default.fileExists(atPath: file.path) else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data(defaultChartJSON.utf8).write(to: file)
    }

    /// Loads ranges.json, keeping the chart already in use if the file has a mistake in it.
    @discardableResult
    private func loadRanges(complain: Bool) -> Bool {
        writeDefaultRangesIfMissing()
        do {
            chart = try Chart(json: Data(contentsOf: rangesFile))
            return true
        } catch {
            if complain { warn("Problem in ranges.json", "\(error)\n\nStill using the previous ranges.") }
            return false
        }
    }

    private func warn(_ title: String, _ detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = detail
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

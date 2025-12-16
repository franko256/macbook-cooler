import SwiftUI
import AppKit
import ServiceManagement

@main
struct MacBookCoolerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(AppState.shared)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var menu: NSMenu?
    var eventMonitor: Any?
    
    private let popoverWidth: CGFloat = 320
    private let popoverHeight: CGFloat = 480
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        AppState.shared.checkHomebrewStatus()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateStatusBarIcon(temperature: AppState.shared.currentTemperature)
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
        
        setupPopover()
        setupMenu()
        
        AppState.shared.startMonitoring { [weak self] in
            DispatchQueue.main.async {
                self?.updateStatusBarIcon(temperature: AppState.shared.currentTemperature)
            }
        }
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover?.isShown == true {
                self?.popover?.performClose(nil)
            }
        }
        
        if !AppState.shared.hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showPopover()
            }
        }
    }
    
    private func setupPopover() {
        let contentView = MenuBarView()
            .environmentObject(AppState.shared)
            .frame(width: popoverWidth, height: popoverHeight)
        
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: popoverWidth, height: popoverHeight)
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: popoverWidth, height: popoverHeight)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = hostingController
    }
    
    private func setupMenu() {
        menu = NSMenu()
        
        let tempItem = NSMenuItem(title: "Temperature: --°C", action: nil, keyEquivalent: "")
        tempItem.isEnabled = false
        tempItem.tag = 100
        menu?.addItem(tempItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let serviceItem = NSMenuItem(title: "Service Running", action: #selector(toggleService), keyEquivalent: "")
        serviceItem.state = AppState.shared.isServiceRunning ? .on : .off
        serviceItem.tag = 101
        menu?.addItem(serviceItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.state = UserDefaults.standard.bool(forKey: "launchAtLogin") ? .on : .off
        launchItem.tag = 102
        menu?.addItem(launchItem)
        
        menu?.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        
        menu?.addItem(NSMenuItem.separator())
        
        menu?.addItem(NSMenuItem(title: "About MacBook Cooler", action: #selector(showAbout), keyEquivalent: ""))
        menu?.addItem(NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: ""))
        
        menu?.addItem(NSMenuItem.separator())
        
        menu?.addItem(NSMenuItem(title: "Quit MacBook Cooler", action: #selector(quitApp), keyEquivalent: "q"))
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseUp {
            updateMenuItems()
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            togglePopover()
        }
    }
    
    private func updateMenuItems() {
        if let tempItem = menu?.item(withTag: 100) {
            let displayTemp = AppState.shared.displayTemperature(AppState.shared.currentTemperature)
            let unit = AppState.shared.temperatureUnit.symbol
            tempItem.title = String(format: "Temperature: %.0f%@", displayTemp, unit)
        }
        if let serviceItem = menu?.item(withTag: 101) {
            serviceItem.state = AppState.shared.isServiceRunning ? .on : .off
            serviceItem.title = AppState.shared.isServiceRunning ? "Service Running" : "Service Stopped"
        }
        if let launchItem = menu?.item(withTag: 102) {
            launchItem.state = UserDefaults.standard.bool(forKey: "launchAtLogin") ? .on : .off
        }
    }
    
    func updateStatusBarIcon(temperature: Double) {
        guard let button = statusItem?.button else { return }
        
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        
        // Determine icon based on temperature (in Celsius)
        let symbolName: String
        if temperature >= 90 {
            symbolName = "thermometer.sun.fill"
        } else if temperature >= 75 {
            symbolName = "thermometer.high"
        } else if temperature >= 50 {
            symbolName = "thermometer.medium"
        } else {
            symbolName = "thermometer.low"
        }
        
        // Create image - always use template mode for consistent menu bar appearance
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Temperature")?.withSymbolConfiguration(config) {
            image.isTemplate = true  // Always template for proper menu bar adaptation
            button.image = image
            button.contentTintColor = nil  // Let system handle the color
        }
        
        // Update temperature text
        let displayTemp = AppState.shared.displayTemperature(temperature)
        let unitSymbol = AppState.shared.temperatureUnit.shortSymbol
        button.title = String(format: " %.0f°%@", displayTemp, unitSymbol)
        button.imagePosition = .imageLeading
    }
    
    private func togglePopover() {
        if popover?.isShown == true {
            hidePopover()
        } else {
            showPopover()
        }
    }
    
    private func showPopover() {
        if let button = statusItem?.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover?.contentViewController?.view.window?.makeKey()
        }
    }
    
    private func hidePopover() {
        popover?.performClose(nil)
    }
    
    @objc func toggleService() {
        AppState.shared.toggleService { _ in }
    }
    
    @objc func toggleLaunchAtLogin() {
        let currentValue = UserDefaults.standard.bool(forKey: "launchAtLogin")
        let newValue = !currentValue
        UserDefaults.standard.set(newValue, forKey: "launchAtLogin")
        
        if #available(macOS 13.0, *) {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update login item: \(error)")
            }
        }
    }
    
    @objc func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func checkForUpdates() {
        AppState.shared.checkHomebrewStatus()
        if AppState.shared.homebrewStatus == .cliToolsOutdated {
            showPopover()
        }
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.stopMonitoring()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

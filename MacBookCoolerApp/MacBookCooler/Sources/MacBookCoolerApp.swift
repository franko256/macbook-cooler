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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - menu bar only app
        NSApp.setActivationPolicy(.accessory)
        
        // Check Homebrew installation status
        AppState.shared.checkHomebrewStatus()
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateStatusBarIcon(temperature: AppState.shared.currentTemperature)
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
        
        // Create popover
        setupPopover()
        
        // Create right-click menu
        setupMenu()
        
        // Start monitoring
        AppState.shared.startMonitoring { [weak self] in
            DispatchQueue.main.async {
                self?.updateStatusBarIcon(temperature: AppState.shared.currentTemperature)
            }
        }
        
        // Monitor for clicks outside popover
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover?.isShown == true {
                self?.popover?.performClose(nil)
            }
        }
        
        // Show onboarding if needed
        if !AppState.shared.hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showPopover()
            }
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 360, height: 520)
        popover?.behavior = .transient
        popover?.animates = true
        
        let hostingController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(AppState.shared)
        )
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 360, height: 520)
        popover?.contentViewController = hostingController
    }
    
    private func setupMenu() {
        menu = NSMenu()
        
        // Temperature display (disabled, just for info)
        let tempItem = NSMenuItem(title: "Temperature: --°C", action: nil, keyEquivalent: "")
        tempItem.isEnabled = false
        tempItem.tag = 100 // Tag to update later
        menu?.addItem(tempItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        // Service control
        let serviceItem = NSMenuItem(title: "Service Running", action: #selector(toggleService), keyEquivalent: "")
        serviceItem.state = AppState.shared.isServiceRunning ? .on : .off
        serviceItem.tag = 101
        menu?.addItem(serviceItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        // Launch at Login
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.state = UserDefaults.standard.bool(forKey: "launchAtLogin") ? .on : .off
        launchItem.tag = 102
        menu?.addItem(launchItem)
        
        // Open Settings
        menu?.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        
        menu?.addItem(NSMenuItem.separator())
        
        // About
        menu?.addItem(NSMenuItem(title: "About MacBook Cooler", action: #selector(showAbout), keyEquivalent: ""))
        
        // Check for Updates
        menu?.addItem(NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: ""))
        
        menu?.addItem(NSMenuItem.separator())
        
        // Quit
        menu?.addItem(NSMenuItem(title: "Quit MacBook Cooler", action: #selector(quitApp), keyEquivalent: "q"))
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseUp {
            // Update menu items before showing
            updateMenuItems()
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil // Reset so left-click works again
        } else {
            togglePopover()
        }
    }
    
    private func updateMenuItems() {
        // Update temperature
        if let tempItem = menu?.item(withTag: 100) {
            tempItem.title = String(format: "Temperature: %.0f°C", AppState.shared.currentTemperature)
        }
        
        // Update service status
        if let serviceItem = menu?.item(withTag: 101) {
            serviceItem.state = AppState.shared.isServiceRunning ? .on : .off
            serviceItem.title = AppState.shared.isServiceRunning ? "Service Running" : "Service Stopped"
        }
        
        // Update launch at login
        if let launchItem = menu?.item(withTag: 102) {
            launchItem.state = UserDefaults.standard.bool(forKey: "launchAtLogin") ? .on : .off
        }
    }
    
    func updateStatusBarIcon(temperature: Double) {
        guard let button = statusItem?.button else { return }
        
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        
        if temperature >= 90 {
            button.image = NSImage(systemSymbolName: "thermometer.sun.fill", accessibilityDescription: "Critical")?
                .withSymbolConfiguration(config)
            button.contentTintColor = .systemRed
        } else if temperature >= 75 {
            button.image = NSImage(systemSymbolName: "thermometer.high", accessibilityDescription: "High")?
                .withSymbolConfiguration(config)
            button.contentTintColor = .systemOrange
        } else if temperature >= 60 {
            button.image = NSImage(systemSymbolName: "thermometer.medium", accessibilityDescription: "Normal")?
                .withSymbolConfiguration(config)
            button.contentTintColor = .labelColor
        } else {
            button.image = NSImage(systemSymbolName: "thermometer.low", accessibilityDescription: "Cool")?
                .withSymbolConfiguration(config)
            button.contentTintColor = .systemGreen
        }
        
        button.title = String(format: " %.0f°", temperature)
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
    
    // MARK: - Menu Actions
    
    @objc func toggleService() {
        AppState.shared.toggleService { _ in }
    }
    
    @objc func toggleLaunchAtLogin() {
        let currentValue = UserDefaults.standard.bool(forKey: "launchAtLogin")
        let newValue = !currentValue
        UserDefaults.standard.set(newValue, forKey: "launchAtLogin")
        
        // Register/unregister with macOS login items
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

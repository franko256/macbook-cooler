import Foundation
import SwiftUI
import Combine

enum HomebrewStatus {
    case notInstalled
    case installed
    case cliToolsInstalled
    case cliToolsOutdated
    case checking
}

enum PowerMode: String, CaseIterable {
    case automatic = "Automatic"
    case lowPower = "Low Power"
    case normal = "Normal"
    case highPerformance = "High Performance"
    
    var shortName: String {
        switch self {
        case .automatic: return "Auto"
        case .lowPower: return "Low"
        case .normal: return "Normal"
        case .highPerformance: return "High"
        }
    }
}

enum TemperatureUnit: String, CaseIterable {
    case fahrenheit = "Fahrenheit"
    case celsius = "Celsius"
    
    var symbol: String {
        switch self {
        case .fahrenheit: return "°F"
        case .celsius: return "°C"
        }
    }
    
    var shortSymbol: String {
        switch self {
        case .fahrenheit: return "F"
        case .celsius: return "C"
        }
    }
}

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

class AppState: ObservableObject {
    static let shared = AppState()
    
    // MARK: - Published Properties
    @Published var currentTemperature: Double = 0
    @Published var cpuUsage: Double = 0
    @Published var gpuTemperature: Double = 0
    @Published var fanSpeed: Int = 0
    @Published var thermalPressure: String = "Nominal"
    @Published var powerMode: PowerMode = .automatic
    @Published var isServiceRunning: Bool = false
    
    @Published var homebrewStatus: HomebrewStatus = .checking
    @Published var cliVersion: String = ""
    @Published var latestVersion: String = "1.0.0"
    @Published var hasCompletedOnboarding: Bool = false
    
    @Published var isInstalling: Bool = false
    @Published var installProgress: String = ""
    @Published var temperatureUnit: TemperatureUnit = .fahrenheit
    @Published var appearanceMode: AppearanceMode = .system
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var updateCallback: (() -> Void)?
    
    private let homebrewPath = "/opt/homebrew/bin/brew"
    private let thermalMonitorPath = "/opt/homebrew/bin/thermal-monitor"
    private let thermalPowerPath = "/opt/homebrew/bin/thermal-power"
    
    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if let unitString = UserDefaults.standard.string(forKey: "temperatureUnit"),
           let unit = TemperatureUnit(rawValue: unitString) {
            temperatureUnit = unit
        } else {
            temperatureUnit = .fahrenheit // Default to Fahrenheit
        }
        
        if let modeString = UserDefaults.standard.string(forKey: "appearanceMode"),
           let mode = AppearanceMode(rawValue: modeString) {
            appearanceMode = mode
        } else {
            appearanceMode = .system // Default to System
        }
        applyAppearance()
    }
    
    // MARK: - Temperature Conversion
    func displayTemperature(_ celsius: Double) -> Double {
        switch temperatureUnit {
        case .celsius:
            return celsius
        case .fahrenheit:
            return (celsius * 9/5) + 32
        }
    }
    
    func setTemperatureUnit(_ unit: TemperatureUnit) {
        temperatureUnit = unit
        UserDefaults.standard.set(unit.rawValue, forKey: "temperatureUnit")
    }
    
    func setAppearanceMode(_ mode: AppearanceMode) {
        appearanceMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "appearanceMode")
        applyAppearance()
    }
    
    func applyAppearance() {
        DispatchQueue.main.async {
            switch self.appearanceMode {
            case .system:
                NSApp.appearance = nil
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }
    
    // Computed property for SwiftUI preferredColorScheme
    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    // MARK: - Homebrew Detection
    func checkHomebrewStatus() {
        homebrewStatus = .checking
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Check if Homebrew is installed
            let homebrewInstalled = FileManager.default.fileExists(atPath: self.homebrewPath)
            
            if !homebrewInstalled {
                DispatchQueue.main.async {
                    self.homebrewStatus = .notInstalled
                }
                return
            }
            
            // Check if CLI tools are installed
            let cliInstalled = FileManager.default.fileExists(atPath: self.thermalMonitorPath)
            
            if !cliInstalled {
                DispatchQueue.main.async {
                    self.homebrewStatus = .installed
                }
                return
            }
            
            // Get installed version
            let version = self.getInstalledVersion()
            
            DispatchQueue.main.async {
                self.cliVersion = version
                if version < self.latestVersion {
                    self.homebrewStatus = .cliToolsOutdated
                } else {
                    self.homebrewStatus = .cliToolsInstalled
                }
                self.checkServiceStatus()
            }
        }
    }
    
    private func getInstalledVersion() -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: homebrewPath)
        task.arguments = ["info", "--json=v2", "macbook-cooler"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let formulae = json["formulae"] as? [[String: Any]],
               let first = formulae.first,
               let versions = first["versions"] as? [String: Any],
               let stable = versions["stable"] as? String {
                return stable
            }
        } catch {
            print("Error getting version: \(error)")
        }
        
        return "0.0.0"
    }
    
    func checkServiceStatus() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: homebrewPath)
        task.arguments = ["services", "list"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            DispatchQueue.main.async {
                self.isServiceRunning = output.contains("macbook-cooler") && output.contains("started")
            }
        } catch {
            print("Error checking service: \(error)")
        }
    }
    
    // MARK: - Installation
    func installCLITools(completion: @escaping (Bool, String) -> Void) {
        isInstalling = true
        installProgress = "Adding tap..."
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Step 1: Add tap
            let tapResult = self.runBrewCommand(["tap", "nelsojona/macbook-cooler"])
            if !tapResult.success {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    completion(false, "Failed to add tap: \(tapResult.output)")
                }
                return
            }
            
            DispatchQueue.main.async {
                self.installProgress = "Installing macbook-cooler..."
            }
            
            // Step 2: Install formula
            let installResult = self.runBrewCommand(["install", "macbook-cooler"])
            if !installResult.success {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    completion(false, "Failed to install: \(installResult.output)")
                }
                return
            }
            
            DispatchQueue.main.async {
                self.installProgress = "Starting service..."
            }
            
            // Step 3: Start service
            let serviceResult = self.runBrewCommand(["services", "start", "macbook-cooler"])
            
            DispatchQueue.main.async {
                self.isInstalling = false
                self.checkHomebrewStatus()
                self.hasCompletedOnboarding = true
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                completion(serviceResult.success, serviceResult.success ? "Installation complete!" : serviceResult.output)
            }
        }
    }
    
    func upgradeCLITools(completion: @escaping (Bool, String) -> Void) {
        isInstalling = true
        installProgress = "Upgrading macbook-cooler..."
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Stop service first
            _ = self.runBrewCommand(["services", "stop", "macbook-cooler"])
            
            // Upgrade
            let upgradeResult = self.runBrewCommand(["upgrade", "macbook-cooler"])
            
            // Restart service
            _ = self.runBrewCommand(["services", "start", "macbook-cooler"])
            
            DispatchQueue.main.async {
                self.isInstalling = false
                self.checkHomebrewStatus()
                completion(upgradeResult.success, upgradeResult.success ? "Upgrade complete!" : upgradeResult.output)
            }
        }
    }
    
    func toggleService(completion: @escaping (Bool) -> Void) {
        let action = isServiceRunning ? "stop" : "start"
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let result = self.runBrewCommand(["services", action, "macbook-cooler"])
            
            DispatchQueue.main.async {
                self.checkServiceStatus()
                completion(result.success)
            }
        }
    }
    
    private func runBrewCommand(_ arguments: [String]) -> (success: Bool, output: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: homebrewPath)
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return (task.terminationStatus == 0, output)
        } catch {
            return (false, error.localizedDescription)
        }
    }
    
    // MARK: - Thermal Monitoring
    func startMonitoring(callback: @escaping () -> Void) {
        updateCallback = callback
        
        // Initial reading
        updateThermalData()
        
        // Update every 3 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.updateThermalData()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateThermalData() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Get thermal data using powermetrics or IOKit
            let thermalData = self.getThermalData()
            
            DispatchQueue.main.async {
                self.currentTemperature = thermalData.cpuTemp
                self.gpuTemperature = thermalData.gpuTemp
                self.cpuUsage = thermalData.cpuUsage
                self.fanSpeed = thermalData.fanSpeed
                self.thermalPressure = thermalData.pressure
                self.updateCallback?()
            }
        }
    }
    
    private func getThermalData() -> (cpuTemp: Double, gpuTemp: Double, cpuUsage: Double, fanSpeed: Int, pressure: String) {
        // Read real temperatures from SMC (System Management Controller)
        let smcData = SMCReader.shared.getAllThermalData()
        
        // Get CPU temperature from SMC
        let cpuTemp = smcData.cpuTemp ?? 0
        
        // Get GPU temperature from SMC
        let gpuTemp = smcData.gpuTemp ?? cpuTemp  // Fallback to CPU temp if GPU not available
        
        // Get fan speed from SMC
        let fanSpeed = smcData.fanSpeed
        
        // Get thermal pressure from ProcessInfo (built-in macOS API)
        let pressure = ProcessInfo.processInfo.thermalPressureString
        
        // Get CPU usage from host_statistics
        let cpuUsage = getCPUUsage()
        
        return (
            cpuTemp: cpuTemp,
            gpuTemp: gpuTemp,
            cpuUsage: cpuUsage,
            fanSpeed: fanSpeed,
            pressure: pressure
        )
    }
    
    /// Get CPU usage percentage using host_statistics
    private func getCPUUsage() -> Double {
        var cpuInfo: host_cpu_load_info_data_t = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return 0
        }
        
        let userTicks = Double(cpuInfo.cpu_ticks.0)   // CPU_STATE_USER
        let systemTicks = Double(cpuInfo.cpu_ticks.1) // CPU_STATE_SYSTEM
        let idleTicks = Double(cpuInfo.cpu_ticks.2)   // CPU_STATE_IDLE
        let niceTicks = Double(cpuInfo.cpu_ticks.3)   // CPU_STATE_NICE
        
        let totalTicks = userTicks + systemTicks + idleTicks + niceTicks
        let usedTicks = userTicks + systemTicks + niceTicks
        
        guard totalTicks > 0 else { return 0 }
        
        return (usedTicks / totalTicks) * 100
    }
    
    // MARK: - Power Mode Control
    func setPowerMode(_ mode: PowerMode) {
        powerMode = mode
        
        guard FileManager.default.fileExists(atPath: thermalPowerPath) else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            
            switch mode {
            case .automatic:
                task.arguments = [self.thermalPowerPath, "--daemon"]
            case .lowPower:
                task.arguments = ["pmset", "-a", "lowpowermode", "1"]
            case .normal:
                task.arguments = ["pmset", "-a", "lowpowermode", "0"]
            case .highPerformance:
                task.arguments = ["pmset", "-a", "lowpowermode", "0"]
            }
            
            try? task.run()
        }
    }
}

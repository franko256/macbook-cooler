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
        // Try to get data from thermal-monitor if installed
        if FileManager.default.fileExists(atPath: thermalMonitorPath) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            task.arguments = [thermalMonitorPath, "--json", "--single"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    return (
                        cpuTemp: json["cpu_temp"] as? Double ?? 0,
                        gpuTemp: json["gpu_temp"] as? Double ?? 0,
                        cpuUsage: json["cpu_usage"] as? Double ?? 0,
                        fanSpeed: json["fan_speed"] as? Int ?? 0,
                        pressure: json["thermal_pressure"] as? String ?? "Unknown"
                    )
                }
            } catch {
                // Fall through to simulated data
            }
        }
        
        // Fallback: Use system profiler for basic temp (simulated for demo)
        return (
            cpuTemp: Double.random(in: 45...85),
            gpuTemp: Double.random(in: 40...80),
            cpuUsage: Double.random(in: 10...90),
            fanSpeed: Int.random(in: 1200...6000),
            pressure: ["Nominal", "Moderate", "Heavy"].randomElement() ?? "Nominal"
        )
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

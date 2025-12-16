import Foundation
import IOKit

// MARK: - SMC Data Types

/// SMC key data structure
struct SMCKeyData {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

// MARK: - SMC Constants

enum SMCSelector: UInt8 {
    case kSMCHandleYPCEvent = 2
    case kSMCReadKey = 5
    case kSMCWriteKey = 6
    case kSMCGetKeyFromIndex = 8
    case kSMCGetKeyInfo = 9
}

// MARK: - SMC Keys for Temperature Sensors

/// Common SMC temperature sensor keys for Apple Silicon and Intel Macs
struct SMCTemperatureKeys {
    // CPU Temperature Keys
    static let cpuProximity = "TC0P"      // CPU Proximity
    static let cpuDie = "TC0D"            // CPU Die
    static let cpuCore1 = "TC1C"          // CPU Core 1
    static let cpuCore2 = "TC2C"          // CPU Core 2
    static let cpuPackage = "TC0F"        // CPU Package
    static let cpuPeci = "TCXC"           // CPU PECI
    
    // Apple Silicon specific
    static let cpuEfficiency = "Tp09"     // Efficiency cores
    static let cpuPerformance = "Tp01"    // Performance cores
    static let cpuPerformance2 = "Tp05"   // Performance cores 2
    
    // GPU Temperature Keys
    static let gpuProximity = "TG0P"      // GPU Proximity
    static let gpuDie = "TG0D"            // GPU Die
    static let gpuHeatsink = "TG0H"       // GPU Heatsink
    
    // Apple Silicon GPU
    static let gpuAppleSilicon1 = "Tg05"  // GPU cluster
    static let gpuAppleSilicon2 = "Tg0f"  // GPU cluster
    
    // Fan Keys
    static let fan0Speed = "F0Ac"         // Fan 0 actual speed
    static let fan1Speed = "F1Ac"         // Fan 1 actual speed
    static let fanCount = "FNum"          // Number of fans
}

// MARK: - SMC Reader Class

class SMCReader {
    static let shared = SMCReader()
    
    private var connection: io_connect_t = 0
    private var isConnected = false
    
    private init() {
        openConnection()
    }
    
    deinit {
        closeConnection()
    }
    
    // MARK: - Connection Management
    
    private func openConnection() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        
        guard service != 0 else {
            print("SMC: Could not find AppleSMC service")
            return
        }
        
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)
        
        if result == kIOReturnSuccess {
            isConnected = true
        } else {
            print("SMC: Could not open connection, error: \(result)")
        }
    }
    
    private func closeConnection() {
        if isConnected {
            IOServiceClose(connection)
            isConnected = false
        }
    }
    
    // MARK: - Key Conversion
    
    private func stringToUInt32(_ str: String) -> UInt32 {
        var result: UInt32 = 0
        for char in str.utf8.prefix(4) {
            result = (result << 8) | UInt32(char)
        }
        return result
    }
    
    private func uint32ToString(_ value: UInt32) -> String {
        var chars = [Character]()
        var val = value
        for _ in 0..<4 {
            chars.insert(Character(UnicodeScalar(UInt8(val & 0xFF))), at: 0)
            val >>= 8
        }
        return String(chars)
    }
    
    // MARK: - SMC Read Operations
    
    private func readSMCKey(_ key: String) -> SMCKeyData? {
        guard isConnected else { return nil }
        
        var inputStruct = SMCKeyData()
        var outputStruct = SMCKeyData()
        
        inputStruct.key = stringToUInt32(key)
        inputStruct.data8 = SMCSelector.kSMCGetKeyInfo.rawValue
        
        let inputSize = MemoryLayout<SMCKeyData>.size
        var outputSize = MemoryLayout<SMCKeyData>.size
        
        // Get key info first
        let result1 = IOConnectCallStructMethod(
            connection,
            UInt32(SMCSelector.kSMCHandleYPCEvent.rawValue),
            &inputStruct,
            inputSize,
            &outputStruct,
            &outputSize
        )
        
        guard result1 == kIOReturnSuccess else { return nil }
        
        // Now read the actual value
        inputStruct.keyInfo.dataSize = outputStruct.keyInfo.dataSize
        inputStruct.data8 = SMCSelector.kSMCReadKey.rawValue
        
        let result2 = IOConnectCallStructMethod(
            connection,
            UInt32(SMCSelector.kSMCHandleYPCEvent.rawValue),
            &inputStruct,
            inputSize,
            &outputStruct,
            &outputSize
        )
        
        guard result2 == kIOReturnSuccess else { return nil }
        
        return outputStruct
    }
    
    // MARK: - Temperature Reading
    
    /// Read temperature from SMC key (returns Celsius)
    func readTemperature(key: String) -> Double? {
        guard let data = readSMCKey(key) else { return nil }
        
        // Temperature is typically stored as sp78 (signed fixed point 7.8)
        // or flt (float) depending on the sensor
        let bytes = data.bytes
        
        // Try sp78 format first (most common for temperature)
        let intValue = Int16(bytes.0) << 8 | Int16(bytes.1)
        let temp = Double(intValue) / 256.0
        
        // Sanity check - temperature should be between -20 and 150 Celsius
        if temp > -20 && temp < 150 {
            return temp
        }
        
        // Try flt format
        let floatBytes = [bytes.0, bytes.1, bytes.2, bytes.3]
        let floatValue = floatBytes.withUnsafeBytes { $0.load(as: Float.self) }
        let floatTemp = Double(floatValue)
        
        if floatTemp > -20 && floatTemp < 150 {
            return floatTemp
        }
        
        return nil
    }
    
    /// Read fan speed in RPM
    func readFanSpeed(fanIndex: Int = 0) -> Int? {
        let key = "F\(fanIndex)Ac"
        guard let data = readSMCKey(key) else { return nil }
        
        // Fan speed is typically stored as fpe2 (unsigned fixed point 14.2)
        let bytes = data.bytes
        let intValue = UInt16(bytes.0) << 8 | UInt16(bytes.1)
        let rpm = Int(intValue) >> 2
        
        // Sanity check
        if rpm > 0 && rpm < 10000 {
            return rpm
        }
        
        return nil
    }
    
    // MARK: - Public Interface
    
    /// Get CPU temperature (tries multiple sensors, returns best reading)
    func getCPUTemperature() -> Double? {
        // Try different CPU temperature keys in order of preference
        let cpuKeys = [
            SMCTemperatureKeys.cpuPerformance,   // Apple Silicon performance cores
            SMCTemperatureKeys.cpuPerformance2,  // Apple Silicon performance cores 2
            SMCTemperatureKeys.cpuDie,           // CPU Die
            SMCTemperatureKeys.cpuProximity,     // CPU Proximity
            SMCTemperatureKeys.cpuPackage,       // CPU Package
            SMCTemperatureKeys.cpuPeci,          // CPU PECI
            "Tc0a", "Tc0b", "Tc0c", "Tc0d",     // Additional Apple Silicon sensors
            "Tp01", "Tp05", "Tp09", "Tp0D"       // More Apple Silicon sensors
        ]
        
        for key in cpuKeys {
            if let temp = readTemperature(key: key), temp > 20 && temp < 120 {
                return temp
            }
        }
        
        return nil
    }
    
    /// Get GPU temperature (tries multiple sensors, returns best reading)
    func getGPUTemperature() -> Double? {
        // Try different GPU temperature keys
        let gpuKeys = [
            SMCTemperatureKeys.gpuAppleSilicon1, // Apple Silicon GPU
            SMCTemperatureKeys.gpuAppleSilicon2, // Apple Silicon GPU 2
            SMCTemperatureKeys.gpuDie,           // GPU Die
            SMCTemperatureKeys.gpuProximity,     // GPU Proximity
            SMCTemperatureKeys.gpuHeatsink,      // GPU Heatsink
            "Tg0a", "Tg0b", "Tg0c", "Tg0d"      // Additional GPU sensors
        ]
        
        for key in gpuKeys {
            if let temp = readTemperature(key: key), temp > 20 && temp < 120 {
                return temp
            }
        }
        
        return nil
    }
    
    /// Get total fan speed (sum of all fans)
    func getTotalFanSpeed() -> Int {
        var totalSpeed = 0
        
        for i in 0..<4 {  // Check up to 4 fans
            if let speed = readFanSpeed(fanIndex: i) {
                totalSpeed += speed
            }
        }
        
        return totalSpeed > 0 ? totalSpeed : 0
    }
    
    /// Get all thermal data at once
    func getAllThermalData() -> (cpuTemp: Double?, gpuTemp: Double?, fanSpeed: Int) {
        return (
            cpuTemp: getCPUTemperature(),
            gpuTemp: getGPUTemperature(),
            fanSpeed: getTotalFanSpeed()
        )
    }
}

// MARK: - ProcessInfo Extension for Thermal State

extension ProcessInfo {
    /// Get thermal pressure as a human-readable string
    var thermalPressureString: String {
        switch thermalState {
        case .nominal:
            return "Nominal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        @unknown default:
            return "Unknown"
        }
    }
}

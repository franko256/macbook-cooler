import SwiftUI

// Constants for consistent sizing
private let viewWidth: CGFloat = 320
private let viewHeight: CGFloat = 480
private let horizontalPadding: CGFloat = 16
private let contentWidth: CGFloat = viewWidth - (horizontalPadding * 2)

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
            
            if !appState.hasCompletedOnboarding || appState.homebrewStatus == .notInstalled || appState.homebrewStatus == .installed {
                OnboardingView(showAlert: $showAlert, alertMessage: $alertMessage)
            } else {
                MainDashboardView(showAlert: $showAlert, alertMessage: $alertMessage)
            }
        }
        .frame(width: viewWidth, height: viewHeight)
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 14) {
                Image(systemName: "thermometer.sun.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Text("MacBook Cooler")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                
                Text("Thermal Management Suite")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 14) {
                statusCard
                
                if appState.isInstalling {
                    installingView
                } else {
                    actionButton
                }
            }
            .frame(width: contentWidth)
            
            Spacer()
            
            footerLinks
                .padding(.bottom, 16)
        }
        .frame(width: viewWidth, height: viewHeight)
    }
    
    private var statusCard: some View {
        HStack(spacing: 10) {
            statusIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.system(size: 13, weight: .semibold))
                Text(statusSubtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
    }
    
    private var statusIcon: some View {
        Group {
            switch appState.homebrewStatus {
            case .checking:
                ProgressView().scaleEffect(0.7)
            case .notInstalled:
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            case .installed:
                Image(systemName: "shippingbox.fill").foregroundColor(.blue)
            case .cliToolsInstalled:
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            case .cliToolsOutdated:
                Image(systemName: "arrow.up.circle.fill").foregroundColor(.orange)
            }
        }
        .font(.system(size: 22))
    }
    
    private var statusTitle: String {
        switch appState.homebrewStatus {
        case .checking: return "Checking..."
        case .notInstalled: return "Homebrew Required"
        case .installed: return "Ready to Install"
        case .cliToolsInstalled: return "All Set!"
        case .cliToolsOutdated: return "Update Available"
        }
    }
    
    private var statusSubtitle: String {
        switch appState.homebrewStatus {
        case .checking: return "Detecting installation status"
        case .notInstalled: return "Install Homebrew first"
        case .installed: return "CLI tools not installed"
        case .cliToolsInstalled: return "Version \(appState.cliVersion)"
        case .cliToolsOutdated: return "\(appState.cliVersion) → \(appState.latestVersion)"
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        switch appState.homebrewStatus {
        case .notInstalled:
            Link(destination: URL(string: "https://brew.sh")!) {
                buttonContent(icon: "safari.fill", text: "Install Homebrew", colors: [.orange, .red])
            }
            .buttonStyle(.plain)
        case .installed:
            Button(action: installCLI) {
                buttonContent(icon: "arrow.down.circle.fill", text: "Install CLI Tools", colors: [.blue, .purple])
            }
            .buttonStyle(.plain)
        case .cliToolsOutdated:
            Button(action: upgradeCLI) {
                buttonContent(icon: "arrow.up.circle.fill", text: "Upgrade to \(appState.latestVersion)", colors: [.orange, .yellow])
            }
            .buttonStyle(.plain)
        case .cliToolsInstalled:
            Button(action: continueToApp) {
                buttonContent(icon: "arrow.right.circle.fill", text: "Continue", colors: [.green, .mint])
            }
            .buttonStyle(.plain)
        default:
            EmptyView()
        }
    }
    
    private func buttonContent(icon: String, text: String, colors: [Color]) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
        .cornerRadius(10)
    }
    
    private var installingView: some View {
        VStack(spacing: 10) {
            ProgressView().scaleEffect(1.0)
            Text(appState.installProgress)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(height: 50)
    }
    
    private var footerLinks: some View {
        HStack(spacing: 12) {
            Link("GitHub", destination: URL(string: "https://github.com/nelsojona/macbook-cooler")!)
            Text("•").foregroundColor(.secondary)
            Link("Docs", destination: URL(string: "https://github.com/nelsojona/macbook-cooler#readme")!)
        }
        .font(.system(size: 10))
        .foregroundColor(.secondary)
    }
    
    private func installCLI() {
        appState.installCLITools { success, message in
            if !success { alertMessage = message; showAlert = true }
        }
    }
    
    private func upgradeCLI() {
        appState.upgradeCLITools { success, message in
            alertMessage = message; showAlert = true
        }
    }
    
    private func continueToApp() {
        appState.hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

// MARK: - Main Dashboard View
struct MainDashboardView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .frame(width: contentWidth)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            Divider()
                .frame(width: contentWidth)
            
            // Scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    temperatureCard
                    statsGrid
                    powerModeSection
                    serviceControlSection
                    settingsSection
                }
                .frame(width: contentWidth)
                .padding(.vertical, 12)
            }
            
            Divider()
                .frame(width: contentWidth)
            
            // Footer
            footerView
                .frame(width: contentWidth)
                .padding(.vertical, 10)
        }
        .frame(width: viewWidth, height: viewHeight)
    }
    
    private var headerView: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MacBook Cooler")
                    .font(.system(size: 14, weight: .semibold))
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.isServiceRunning ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    Text(appState.isServiceRunning ? "Service Running" : "Service Stopped")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: { appState.checkHomebrewStatus() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
        }
    }
    
    private var temperatureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CPU Temperature")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(String(format: "%.0f", appState.displayTemperature(appState.currentTemperature)))
                            .font(.system(size: 40, weight: .light, design: .rounded))
                        Text(appState.temperatureUnit.symbol)
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Image(systemName: temperatureIcon)
                        .font(.system(size: 24))
                        .foregroundColor(temperatureColor)
                    Text(appState.thermalPressure)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            // Temperature bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [.green, .yellow, .orange, .red], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * min(max(appState.currentTemperature / 100, 0), 1.0))
                }
            }
            .frame(height: 5)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
    }
    
    private var temperatureIcon: String {
        if appState.currentTemperature >= 90 { return "thermometer.sun.fill" }
        if appState.currentTemperature >= 75 { return "thermometer.high" }
        if appState.currentTemperature >= 60 { return "thermometer.medium" }
        return "thermometer.low"
    }
    
    private var temperatureColor: Color {
        if appState.currentTemperature >= 90 { return .red }
        if appState.currentTemperature >= 75 { return .orange }
        if appState.currentTemperature >= 60 { return .yellow }
        return .green
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.fixed((contentWidth - 10) / 2)),
            GridItem(.fixed((contentWidth - 10) / 2))
        ], spacing: 10) {
            StatCard(title: "GPU", value: String(format: "%.0f%@", appState.displayTemperature(appState.gpuTemperature), appState.temperatureUnit.symbol), icon: "rectangle.3.group.fill")
            StatCard(title: "CPU Usage", value: String(format: "%.0f%%", appState.cpuUsage), icon: "cpu.fill")
            StatCard(title: "Fan Speed", value: "\(appState.fanSpeed) RPM", icon: "fan.fill")
            StatCard(title: "Power Mode", value: appState.powerMode.rawValue, icon: "bolt.fill")
        }
    }
    
    private var powerModeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Power Mode")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            
            Picker("", selection: $appState.powerMode) {
                ForEach(PowerMode.allCases, id: \.self) { mode in
                    Text(mode.shortName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: appState.powerMode) { newValue in
                appState.setPowerMode(newValue)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial))
    }
    
    private var serviceControlSection: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Background Service")
                    .font(.system(size: 11, weight: .medium))
                Text(appState.isServiceRunning ? "Auto thermal management" : "Service stopped")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { appState.isServiceRunning },
                set: { _ in
                    appState.toggleService { success in
                        if !success { alertMessage = "Failed to toggle service"; showAlert = true }
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .scaleEffect(0.75)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial))
    }
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            
            // Temperature Unit
            HStack {
                Text("Temperature")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Picker("", selection: Binding(
                    get: { appState.temperatureUnit },
                    set: { appState.setTemperatureUnit($0) }
                )) {
                    Text("°F").tag(TemperatureUnit.fahrenheit)
                    Text("°C").tag(TemperatureUnit.celsius)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
            }
            
            // Appearance Mode
            HStack {
                Text("Appearance")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Picker("", selection: Binding(
                    get: { appState.appearanceMode },
                    set: { appState.setAppearanceMode($0) }
                )) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 90)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial))
    }
    
    private var footerView: some View {
        HStack {
            if appState.homebrewStatus == .cliToolsOutdated {
                Button(action: {
                    appState.upgradeCLITools { success, message in
                        alertMessage = message; showAlert = true
                    }
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Update")
                    }
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            } else {
                Text("v\(appState.cliVersion.isEmpty ? "1.0.0" : appState.cliVersion)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { NSApp.terminate(nil) }) {
                Text("Quit")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Supporting Views
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial))
    }
}

// MARK: - Power Mode Extension
extension PowerMode {
    var shortName: String {
        switch self {
        case .automatic: return "Auto"
        case .lowPower: return "Low"
        case .normal: return "Normal"
        case .highPerformance: return "High"
        }
    }
}

// MARK: - Visual Effect Blur
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(appState)
                .tabItem { Label("General", systemImage: "gear") }
            ThresholdsSettingsView()
                .tabItem { Label("Thresholds", systemImage: "thermometer") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 400, height: 250)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showTemperatureInMenuBar") private var showTemperatureInMenuBar = true
    
    var body: some View {
        Form {
            Picker("Temperature Unit", selection: Binding(
                get: { appState.temperatureUnit },
                set: { appState.setTemperatureUnit($0) }
            )) {
                ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }
            
            Picker("Appearance", selection: Binding(
                get: { appState.appearanceMode },
                set: { appState.setAppearanceMode($0) }
            )) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            
            Toggle("Launch at login", isOn: $launchAtLogin)
            Toggle("Show temperature in menu bar", isOn: $showTemperatureInMenuBar)
        }
        .padding()
    }
}

struct ThresholdsSettingsView: View {
    @AppStorage("highThreshold") private var highThreshold = 80.0
    @AppStorage("lowThreshold") private var lowThreshold = 65.0
    @AppStorage("criticalThreshold") private var criticalThreshold = 95.0
    
    var body: some View {
        Form {
            Section("Temperature Thresholds (°C)") {
                HStack {
                    Text("Low Power Mode Trigger")
                    Spacer()
                    TextField("", value: $highThreshold, format: .number).frame(width: 50)
                }
                HStack {
                    Text("Normal Mode Return")
                    Spacer()
                    TextField("", value: $lowThreshold, format: .number).frame(width: 50)
                }
                HStack {
                    Text("Critical Alert")
                    Spacer()
                    TextField("", value: $criticalThreshold, format: .number).frame(width: 50)
                }
            }
        }
        .padding()
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "thermometer.sun.fill")
                .font(.system(size: 40))
                .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("MacBook Cooler").font(.headline)
            Text("Thermal Management Suite").font(.caption).foregroundColor(.secondary)
            Text("Version 1.0.0").font(.caption2).foregroundColor(.secondary)
            Link("View on GitHub", destination: URL(string: "https://github.com/nelsojona/macbook-cooler")!)
                .font(.caption)
        }
        .padding()
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppState.shared)
}

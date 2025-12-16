import SwiftUI

// Constants for consistent sizing
private let viewWidth: CGFloat = 320
private let viewHeight: CGFloat = 520
private let horizontalPadding: CGFloat = 16
private let contentWidth: CGFloat = viewWidth - (horizontalPadding * 2)

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
            
            if !appState.hasCompletedOnboarding || appState.homebrewStatus == .notInstalled || appState.homebrewStatus == .installed {
                OnboardingView(showAlert: $showAlert, alertMessage: $alertMessage)
            } else {
                // Sliding panel container
                ZStack {
                    // Main Dashboard (slides left when settings shown)
                    MainDashboardView(showAlert: $showAlert, alertMessage: $alertMessage, showSettings: $showSettings)
                        .offset(x: showSettings ? -viewWidth : 0)
                    
                    // Settings Panel (slides in from right)
                    SettingsPanelView(showSettings: $showSettings)
                        .offset(x: showSettings ? 0 : viewWidth)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showSettings)
            }
        }
        .frame(width: viewWidth, height: viewHeight)
        .preferredColorScheme(appState.colorScheme)
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        }
    }
}

// MARK: - Settings Panel View
struct SettingsPanelView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showSettings: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: { showSettings = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                // Invisible spacer for centering
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .opacity(0)
            }
            .frame(width: contentWidth)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .frame(width: contentWidth)
            
            // Settings content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // Appearance Section
                    settingsSection(title: "Appearance") {
                        VStack(spacing: 12) {
                            settingsRow(title: "Theme", icon: "paintbrush.fill") {
                                Picker("", selection: Binding(
                                    get: { appState.appearanceMode },
                                    set: { appState.setAppearanceMode($0) }
                                )) {
                                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 160)
                            }
                            
                            settingsRow(title: "Temperature Unit", icon: "thermometer") {
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
                        }
                    }
                    
                    // Behavior Section
                    settingsSection(title: "Behavior") {
                        VStack(spacing: 12) {
                            settingsToggleRow(
                                title: "Launch at Login",
                                icon: "power",
                                isOn: Binding(
                                    get: { UserDefaults.standard.bool(forKey: "launchAtLogin") },
                                    set: { UserDefaults.standard.set($0, forKey: "launchAtLogin") }
                                )
                            )
                            
                            settingsToggleRow(
                                title: "Show in Menu Bar",
                                icon: "menubar.rectangle",
                                isOn: Binding(
                                    get: { UserDefaults.standard.bool(forKey: "showTemperatureInMenuBar") },
                                    set: { UserDefaults.standard.set($0, forKey: "showTemperatureInMenuBar") }
                                )
                            )
                        }
                    }
                    
                    // Thresholds Section
                    settingsSection(title: "Temperature Thresholds") {
                        VStack(spacing: 16) {
                            thresholdSlider(
                                title: "High Temp Warning",
                                value: Binding(
                                    get: { UserDefaults.standard.double(forKey: "highThreshold") == 0 ? 80 : UserDefaults.standard.double(forKey: "highThreshold") },
                                    set: { UserDefaults.standard.set($0, forKey: "highThreshold") }
                                ),
                                range: 70...100,
                                color: .orange
                            )
                            
                            thresholdSlider(
                                title: "Low Temp Recovery",
                                value: Binding(
                                    get: { UserDefaults.standard.double(forKey: "lowThreshold") == 0 ? 65 : UserDefaults.standard.double(forKey: "lowThreshold") },
                                    set: { UserDefaults.standard.set($0, forKey: "lowThreshold") }
                                ),
                                range: 50...80,
                                color: .green
                            )
                        }
                    }
                    
                    // About Section
                    settingsSection(title: "About") {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Version")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("1.0.0")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            
                            HStack {
                                Text("CLI Tools")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(appState.cliVersion.isEmpty ? "1.0.0" : appState.cliVersion)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            
                            Divider()
                            
                            Link(destination: URL(string: "https://github.com/nelsojona/macbook-cooler")!) {
                                HStack {
                                    Image(systemName: "link")
                                        .font(.system(size: 10))
                                    Text("View on GitHub")
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
                .frame(width: contentWidth)
                .padding(.vertical, 16)
            }
        }
        .frame(width: viewWidth, height: viewHeight)
    }
    
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)
            
            VStack(spacing: 0) {
                content()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
        }
    }
    
    private func settingsRow<Content: View>(title: String, icon: String, @ViewBuilder control: () -> Content) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            Spacer()
            control()
        }
    }
    
    private func settingsToggleRow(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.7)
                .labelsHidden()
        }
    }
    
    private func thresholdSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text(String(format: "%.0f°C", value.wrappedValue))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
            }
            
            Slider(value: value, in: range, step: 1)
                .tint(color)
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
                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
            case .installed:
                Image(systemName: "checkmark.circle.fill").foregroundColor(.yellow)
            case .cliToolsInstalled, .cliToolsOutdated:
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            }
        }
        .font(.system(size: 24))
    }
    
    private var statusTitle: String {
        switch appState.homebrewStatus {
        case .checking: return "Checking..."
        case .notInstalled: return "Homebrew Required"
        case .installed: return "CLI Tools Required"
        case .cliToolsInstalled: return "Ready to Go!"
        case .cliToolsOutdated: return "Update Available"
        }
    }
    
    private var statusSubtitle: String {
        switch appState.homebrewStatus {
        case .checking: return "Detecting system configuration"
        case .notInstalled: return "Install Homebrew to continue"
        case .installed: return "Install thermal management tools"
        case .cliToolsInstalled: return "All components installed"
        case .cliToolsOutdated: return "New version available"
        }
    }
    
    private var installingView: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text(appState.installProgress)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    @ViewBuilder
    private var actionButton: some View {
        switch appState.homebrewStatus {
        case .notInstalled:
            Link(destination: URL(string: "https://brew.sh")!) {
                Label("Install Homebrew", systemImage: "arrow.up.right.square")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor))
                    .foregroundColor(.white)
            }
        case .installed:
            Button(action: installCLI) {
                Label("Install CLI Tools", systemImage: "terminal")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        case .cliToolsInstalled:
            Button(action: continueToApp) {
                Label("Continue", systemImage: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.green))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        case .cliToolsOutdated:
            VStack(spacing: 8) {
                Button(action: upgradeCLI) {
                    Label("Update CLI Tools", systemImage: "arrow.up.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Button(action: continueToApp) {
                    Text("Skip for now")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        default:
            EmptyView()
        }
    }
    
    private var footerLinks: some View {
        HStack(spacing: 16) {
            Link("Documentation", destination: URL(string: "https://github.com/nelsojona/macbook-cooler#readme")!)
            Text("•").foregroundColor(.secondary)
            Link("GitHub", destination: URL(string: "https://github.com/nelsojona/macbook-cooler")!)
        }
        .font(.system(size: 10))
        .foregroundColor(.secondary)
    }
    
    private func installCLI() {
        appState.installCLITools { success, message in
            alertMessage = message; showAlert = true
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
    @Binding var showSettings: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .frame(width: contentWidth)
                .padding(.top, 20)
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
            
            // Settings button
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
            
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
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial))
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
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Settings Window (for menu bar)
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            ThresholdsSettingsView()
                .tabItem {
                    Label("Thresholds", systemImage: "thermometer")
                }
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
    
    var body: some View {
        Form {
            VStack(alignment: .leading) {
                Text("High Temperature Threshold: \(Int(highThreshold))°C")
                Slider(value: $highThreshold, in: 70...100, step: 1)
                Text("Triggers Low Power Mode when exceeded")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading) {
                Text("Low Temperature Threshold: \(Int(lowThreshold))°C")
                Slider(value: $lowThreshold, in: 50...80, step: 1)
                Text("Returns to normal mode when reached")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

# MacBook Cooler

A comprehensive thermal management solution for Apple Silicon MacBook Pro models (M1, M2, M3, M4 and later). This project includes both a native macOS menu bar application with a beautiful glassmorphism UI and a suite of command-line tools for advanced users.

![macOS](https://img.shields.io/badge/macOS-Ventura%2B-blue)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%2FM2%2FM3%2FM4-orange)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.1.0-purple)

---

## Table of Contents

- [The Problem](#the-problem)
- [Features](#features)
- [Installation](#installation)
  - [Menu Bar App](#menu-bar-app-installation)
  - [CLI Tools](#cli-tools-installation)
- [Menu Bar App](#menu-bar-app)
- [CLI Tools](#cli-tools)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## The Problem

High-performance laptops like the MacBook Pro with M3/M4 Max processors can generate significant heat under heavy, sustained loads. When the system reaches critical temperatures, macOS will automatically throttle the CPU and GPU to prevent hardware damage. This results in a noticeable drop in performance, which can be frustrating for users who rely on their machines for demanding tasks like video rendering, machine learning, and running multiple virtual machines.

MacBook Cooler provides a proactive approach to thermal management, allowing you to monitor temperatures in real-time, automate power-saving measures, and control background processes to maintain optimal performance for longer.

---

## Features

| Feature | Menu Bar App | CLI Tools |
|---------|:------------:|:---------:|
| Real-time temperature monitoring | ✓ | ✓ |
| Automatic power mode switching | ✓ | ✓ |
| Temperature unit toggle (°F/°C) | ✓ | - |
| Light/Dark/System appearance | ✓ | - |
| Process throttling | - | ✓ |
| Task scheduling | - | ✓ |
| Fan control profiles | - | ✓ |
| System optimization | - | ✓ |
| Launch at login | ✓ | ✓ |
| Glassmorphism UI | ✓ | - |

---

## Installation

### Menu Bar App Installation

The menu bar app provides a beautiful, user-friendly interface for thermal management. Choose one of the following installation methods:

#### Option 1: Homebrew Cask (Recommended)

```bash
# Add the tap and install the app
brew tap nelsojona/macbook-cooler
brew install --cask macbook-cooler-app
```

#### Option 2: DMG Download

1. Download the latest DMG from the [Releases](https://github.com/nelsojona/macbook-cooler/releases) page.
2. Open the DMG file and drag **MacBook Cooler.app** to your Applications folder.
3. Launch the app from Applications or Spotlight.

> **Note**: On first launch, you may need to right-click the app and select "Open" to bypass Gatekeeper, as the app is not notarized.

### CLI Tools Installation

The CLI tools provide advanced thermal management capabilities for power users.

#### Option 1: Homebrew (Recommended)

```bash
# Add the tap
brew tap nelsojona/macbook-cooler

# Install the CLI tools
brew install macbook-cooler

# Start the automatic power mode service
brew services start macbook-cooler
```

#### Option 2: Quick Install Script

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/nelsojona/macbook-cooler/main/scripts/install.sh)"
```

#### Option 3: Manual Installation

```bash
git clone https://github.com/nelsojona/macbook-cooler.git
cd macbook-cooler/scripts
./install.sh
```

---

## Menu Bar App

The MacBook Cooler menu bar app provides an elegant interface for monitoring and managing your MacBook's thermal performance.

### Dashboard

The main dashboard displays real-time thermal information including CPU and GPU temperatures, current power mode, and system status. Temperature readings update automatically and are color-coded based on thermal thresholds.

### Power Modes

Three power modes are available for quick switching:

| Mode | Description |
|------|-------------|
| **Low Power** | Reduces performance to minimize heat generation. Ideal for battery life and quiet operation. |
| **Automatic** | Lets macOS manage power based on workload. Recommended for most users. |
| **High Performance** | Maximizes performance at the cost of higher temperatures and fan noise. |

### Settings

Access settings by clicking the gear icon in the popover or right-clicking the menu bar icon. Available options include:

- **Temperature Unit**: Toggle between Fahrenheit (default) and Celsius.
- **Appearance**: Choose Light, Dark, or System appearance mode.
- **Launch at Login**: Start the app automatically when you log in.
- **Temperature Thresholds**: Customize the temperatures that trigger automatic power mode changes.

---

## CLI Tools

The command-line tools provide advanced thermal management capabilities for power users and automation scenarios.

### thermal-monitor

Real-time monitoring of CPU/GPU temperatures, fan speeds, and thermal pressure.

```bash
# Start continuous monitoring (requires sudo)
sudo thermal-monitor

# Get a single reading
sudo thermal-monitor --single
```

### thermal-power

Automatically switches between macOS energy modes based on temperature.

```bash
# Run as a background daemon (recommended)
sudo thermal-power --daemon

# Stop the daemon
sudo thermal-power --kill
```

### thermal-throttle

Identifies and reduces the priority of resource-intensive background processes.

```bash
# Run automatically based on temperature
sudo thermal-throttle --auto

# Restore all throttled processes to normal priority
sudo thermal-throttle --restore
```

### thermal-schedule

Queue heavy tasks to be executed only when the system is cool.

```bash
# Add a video rendering task to the queue
thermal-schedule --add "Render Project X" "ffmpeg -i input.mp4 output.mp4"

# Process the queue (run this via a cron job or launchd)
sudo thermal-schedule --process
```

### thermal-fan

Set custom fan curves (requires Macs Fan Control).

```bash
# Set the fan profile to 'performance'
sudo thermal-fan --profile performance

# Monitor and apply the fan curve continuously
sudo thermal-fan --monitor
```

### thermal-optimize

Tools for disabling unnecessary launch agents and optimizing system settings.

```bash
# List all launch agents
thermal-optimize --list-agents

# Automatically disable a list of common, optional agents
sudo thermal-optimize --disable-optional
```

---

## Configuration

### Menu Bar App

All settings can be configured directly in the app by clicking the Settings button (gear icon). Changes are saved automatically and persist across app restarts.

### CLI Tools

For CLI users, all scripts can be configured by editing the `thermal_config.conf` file located in the `scripts` directory.

```bash
# Example configuration in thermal_config.conf

# Temperature to trigger Low Power Mode
HIGH_THRESHOLD=80

# Temperature to return to Normal Mode
LOW_THRESHOLD=65

# CPU usage threshold for throttling (percentage)
CPU_THRESHOLD=50

# Default fan profile (silent, balanced, performance, max_cooling)
DEFAULT_FAN_PROFILE=balanced
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **Command not found** | Restart your terminal or run `source ~/.zshrc`. Verify that `~/.local/bin` is in your `PATH`. |
| **Permission denied** | Most CLI scripts require `sudo` to access system metrics. Run them with `sudo`. |
| **Fan control not working** | Direct fan control on Apple Silicon is limited by firmware. Install Macs Fan Control for better results. |
| **App won't open** | Right-click the app and select "Open" to bypass Gatekeeper on first launch. |
| **Temperature not updating** | Grant the app permission to access system information in System Settings > Privacy & Security. |

---

## Contributing

Contributions are welcome! Please read the [CONTRIBUTING.md](CONTRIBUTING.md) file for details on our code of conduct and the process for submitting pull requests.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Author

Created by [Jonathan Nelson](https://github.com/nelsojona)

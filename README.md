# MacBook Pro Thermal Management Scripts

This repository contains a suite of shell scripts designed to monitor and manage thermal performance on Apple Silicon MacBook Pro models (M1, M2, M3, M4 and later). These scripts help prevent overheating and performance throttling during sustained, intensive workloads such as video rendering, machine learning, and running multiple virtual machines.

---

## Table of Contents

- [The Problem](#the-problem)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [thermal-monitor](#thermal-monitor)
  - [thermal-power](#thermal-power)
  - [thermal-throttle](#thermal-throttle)
  - [thermal-schedule](#thermal-schedule)
  - [thermal-fan](#thermal-fan)
  - [thermal-optimize](#thermal-optimize)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## The Problem

High-performance laptops like the MacBook Pro with M3/M4 Max processors can generate significant heat under heavy, sustained loads. When the system reaches critical temperatures, macOS will automatically throttle the CPU and GPU to prevent hardware damage. This results in a noticeable drop in performance, which can be frustrating for users who rely on their machines for demanding tasks.

These scripts provide a proactive approach to thermal management, allowing you to monitor temperatures, automate power-saving measures, and control background processes to maintain optimal performance for longer.

---

## Prerequisites

- **Operating System**: macOS 12 (Monterey) or later. Optimized for macOS 14 (Sonoma) and later.
- **Hardware**: Apple Silicon MacBook Pro (M1, M2, M3, M4 series).
- **Permissions**: `sudo` access is required for many of the scripts, as they interact with system-level metrics and settings.
- **Optional**: [Macs Fan Control](https://crystalidea.com/macs-fan-control) for fan control features.

---

## Installation

### Homebrew (Recommended)

The easiest way to install on macOS is via Homebrew. Run the following commands:

```bash
# Download the formula
curl -sL https://raw.githubusercontent.com/nelsojona/macbook-cooler/main/Formula/macbook-cooler.rb -o macbook-cooler.rb

# Install from the local file
brew install --formula ./macbook-cooler.rb

# Clean up the downloaded file
rm macbook-cooler.rb
```

To start the automatic power mode service:

```bash
brew services start macbook-cooler
```

To uninstall:

```bash
brew uninstall macbook-cooler
```

### Quick Start (One-Liner)

For a fast and easy setup, you can run the installer directly from GitHub using `curl`:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/nelsojona/macbook-cooler/main/scripts/install.sh)"
```

This will download and execute the bootstrap script, guiding you through the standard installation process.

### Manual Installation

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/nelsojona/macbook-cooler.git
    cd macbook-cooler/scripts
    ```

2.  **Run the installer script:**

    The interactive installer allows you to customize the setup.

    ```bash
    ./install.sh
    ```

### Installation Modes

The installer supports several modes via the `--mode` flag:

-   `minimal`: Installs the scripts and command-line access. No automated services are configured.
-   `standard` (default): Installs scripts and the auto power mode switching service.
-   `full`: Installs all scripts and all available `launchd` services, including the thermal-aware task scheduler.

Example for a full, non-interactive installation:

```bash
./install.sh --mode full --non-interactive
```

### Installer Flags

-   `-m, --mode [minimal|standard|full]`: Set the installation mode.
-   `-n, --non-interactive`: Run without interactive prompts.
-   `-d, --dry-run`: Preview all actions without making any changes to your system.
-   `-h, --help`: Show the help message.

---

## Configuration

All scripts can be configured by editing the `thermal_config.conf` file located in the `scripts` directory. This file allows you to adjust temperature thresholds, fan speed profiles, and other settings.

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

## Usage

Once installed, the scripts are available as command-line tools.

### `thermal-monitor`

Real-time monitoring of CPU/GPU temperatures, fan speeds, and thermal pressure.

```bash
# Start continuous monitoring (requires sudo)
sudo thermal-monitor

# Get a single reading
sudo thermal-monitor --single
```

### `thermal-power`

Automatically switches between macOS energy modes based on temperature.

```bash
# Run as a background daemon (recommended)
sudo thermal-power --daemon

# Stop the daemon
sudo thermal-power --kill
```

### `thermal-throttle`

Identifies and reduces the priority of resource-intensive background processes.

```bash
# Run automatically based on temperature
sudo thermal-throttle --auto

# Restore all throttled processes to normal priority
sudo thermal-throttle --restore
```

### `thermal-schedule`

Queue heavy tasks to be executed only when the system is cool.

```bash
# Add a video rendering task to the queue
thermal-schedule --add "Render Project X" "ffmpeg -i input.mp4 output.mp4"

# Process the queue (run this via a cron job or launchd)
sudo thermal-schedule --process
```

### `thermal-fan`

Set custom fan curves (requires Macs Fan Control).

```bash
# Set the fan profile to 'performance'
sudo thermal-fan --profile performance

# Monitor and apply the fan curve continuously
sudo thermal-fan --monitor
```

### `thermal-optimize`

Tools for disabling unnecessary launch agents and optimizing system settings.

```bash
# List all launch agents
thermal-optimize --list-agents

# Automatically disable a list of common, optional agents
sudo thermal-optimize --disable-optional
```

---

## Troubleshooting

- **Command not found**: If you get a `command not found` error after installation, make sure you have restarted your terminal or sourced your shell profile (`source ~/.zshrc`). Also, verify that `~/.local/bin` is in your `PATH` (`echo $PATH`).

- **Permission denied**: Most scripts require `sudo` to access system metrics. Always run them with `sudo` (e.g., `sudo thermal-monitor`).

- **Fan control not working**: Direct fan control on the latest Apple Silicon Macs is limited by the firmware. The `thermal-fan` script works best when Macs Fan Control is installed, but even then, macOS may override settings. This is a known limitation of the platform.

---

## Contributing

Contributions are welcome! Please read the [CONTRIBUTING.md](CONTRIBUTING.md) file for details on our code of conduct and the process for submitting pull requests.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

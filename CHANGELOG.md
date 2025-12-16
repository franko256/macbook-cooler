# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- 

### Changed
- 

### Deprecated
- 

### Removed
- 

### Fixed
- 

### Security
- 

## [1.1.0] - 2025-12-16

### Added
- **Native macOS Menu Bar Application**: A beautiful SwiftUI-based menu bar app for thermal management.
  - Real-time CPU and GPU temperature monitoring with live updates.
  - Glassmorphism UI design matching macOS Sonoma aesthetics.
  - Temperature display in Fahrenheit (default) or Celsius with easy toggle.
  - Light, Dark, and System appearance modes.
  - Quick power mode switching (Low Power, Automatic, High Performance).
  - Sliding settings panel with smooth spring animations.
  - Configurable temperature thresholds for automatic power mode switching.
  - Launch at Login functionality.
  - Template-mode menu bar icon that adapts to system appearance.
  - Author attribution with GitHub profile link.
- **DMG Installer**: Easy drag-and-drop installation for non-technical users.
- **Homebrew Cask**: Install the menu bar app via `brew install --cask macbook-cooler-app`.

### Changed
- Updated README with comprehensive installation instructions for both CLI and GUI.
- Improved documentation structure with separate sections for menu bar app and CLI tools.

## [1.0.0] - 2025-12-16

### Added
- Initial release of the thermal management script suite.
- `thermal-monitor`: Real-time temperature monitoring.
- `thermal-power`: Automatic power mode switching.
- `thermal-throttle`: Process throttling during thermal events.
- `thermal-schedule`: Task scheduling for cooler periods.
- `thermal-fan`: Fan control and custom profiles.
- `system-optimizer`: System optimization tools.
- Comprehensive `README.md`, `CONTRIBUTING.md`, and `LICENSE` files.

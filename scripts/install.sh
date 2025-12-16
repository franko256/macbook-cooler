#!/bin/bash
#===============================================================================
# THERMAL MANAGEMENT SUITE BOOTSTRAPPER
# A comprehensive CLI for installing and configuring the thermal management suite.
#
# Author: Manus AI
# Version: 2.0.0
#===============================================================================

set -e

# --- Configuration ---
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTALL_DIR="${HOME}/.thermal-management"
readonly BIN_DIR="${HOME}/.local/bin"
readonly LOG_DIR="${HOME}/Library/Logs/ThermalMonitor"
readonly LAUNCHD_DIR="${HOME}/Library/LaunchAgents"

# --- Globals ---
DRY_RUN=false
NON_INTERACTIVE=false
SETUP_MODE="standard"

# --- Colors and Formatting ---
readonly C_RESET='\033[0m'
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'
readonly C_BOLD='\033[1m'

# --- Logging and Output ---
info() { echo -e "${C_BLUE}==>${C_RESET} ${C_BOLD}$1${C_RESET}"; }
success() { echo -e "${C_GREEN}✓${C_RESET} $1"; }
warn() { echo -e "${C_YELLOW}!!${C_RESET} $1"; }
error() { echo -e "${C_RED}✗${C_RESET} $1" >&2; exit 1; }
execute() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${C_CYAN}[DRY RUN]${C_RESET} $1"
    else
        eval "$1"
    fi
}

# --- Helper Functions ---
prompt_yes_no() {
    if [ "$NON_INTERACTIVE" = true ]; then
        # Default to yes in non-interactive mode
        return 0
    fi
    while true; do
        read -p "$1 [Y/n]: " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# --- Main Logic ---

usage() {
    cat <<EOF
${C_BOLD}Thermal Management Suite Bootstrapper${C_RESET}

Usage: $(basename "$0") [OPTIONS]

Installs and configures the thermal management script suite for macOS.

${C_BOLD}Options:${C_RESET}
  -m, --mode [minimal|standard|full]  Set the installation mode (default: standard).
  -n, --non-interactive               Run without interactive prompts (uses defaults).
  -d, --dry-run                       Show what would be done, without making changes.
  -h, --help                          Show this help message.

${C_BOLD}One-Liner Quick Start:${C_RESET}
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/nelsojona/macbook-cooler/main/scripts/install.sh)"
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--mode)
                if [[ ! "$2" =~ ^(minimal|standard|full)$ ]]; then
                    error "Invalid mode: $2. Must be one of minimal, standard, or full."
                fi
                SETUP_MODE="$2"
                shift 2
                ;;
            -n|--non-interactive)
                NON_INTERACTIVE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
}

print_banner() {
    echo -e "${C_CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║   ████████╗██╗  ██╗███████╗██████╗ ███╗   ███╗ █████╗ ██╗                    ║
║   ╚══██╔══╝██║  ██║██╔════╝██╔══██╗████╗ ████║██╔══██╗██║                    ║
║      ██║   ███████║█████╗  ██████╔╝██╔████╔██║███████║██║                    ║
║      ██║   ██╔══██║██╔══╝  ██╔══██╗██║╚██╔╝██║██╔══██║██║                    ║
║      ██║   ██║  ██║███████╗██║  ██║██║ ╚═╝ ██║██║  ██║███████╗               ║
║      ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝               ║
║                                                                              ║
║              MANAGEMENT SUITE FOR MACBOOK PRO M3/M4 MAX                      ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${C_RESET}"
}

check_prerequisites() {
    info "1. Checking prerequisites..."
    local os_name
    os_name=$(uname)
    if [ "${os_name}" != "Darwin" ]; then
        error "This script is designed for macOS only."
    fi
    success "Running on macOS."

    local chip
    chip=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "unknown")
    if [[ "${chip}" != *"Apple"* ]]; then
        warn "This suite is optimized for Apple Silicon Macs."
    else
        success "Apple Silicon detected."
    fi

    if ! sudo -n true 2>/dev/null; then
        warn "Sudo access will be required for some steps."
        if [ "$NON_INTERACTIVE" = false ]; then
            sudo -v # Prompt for password upfront
        fi
    else
        success "Sudo access available."
    fi
}

setup_directories() {
    info "2. Setting up directory structure..."
    execute "mkdir -p '${INSTALL_DIR}'"
    execute "mkdir -p '${BIN_DIR}'"
    execute "mkdir -p '${LOG_DIR}'"
    execute "mkdir -p '${LAUNCHD_DIR}'"
    success "Directories created successfully."
}

install_scripts() {
    info "3. Installing scripts..."
    local scripts_to_install=("thermal_monitor.sh" "auto_power_mode.sh" "thermal_throttle.sh" "thermal_scheduler.sh" "fan_control.sh" "system_optimizer.sh")
    
    for script in "${scripts_to_install[@]}"; do
        execute "cp '${SCRIPT_DIR}/${script}' '${INSTALL_DIR}/'"
        execute "chmod +x '${INSTALL_DIR}/${script}'"
    done
    success "Core scripts installed."

    execute "cp '${SCRIPT_DIR}/thermal_config.conf' '${INSTALL_DIR}/'"
    success "Configuration file installed."
}

setup_symlinks() {
    info "4. Creating command-line symlinks..."
    local symlinks=(
        "thermal_monitor.sh:thermal-monitor"
        "auto_power_mode.sh:thermal-power"
        "thermal_throttle.sh:thermal-throttle"
        "thermal_scheduler.sh:thermal-schedule"
        "fan_control.sh:thermal-fan"
        "system_optimizer.sh:thermal-optimize"
    )

    for link_pair in "${symlinks[@]}"; do
        local script="${link_pair%%:*}"
        local link="${link_pair##*:}"
        execute "ln -sf '${INSTALL_DIR}/${script}' '${BIN_DIR}/${link}'"
    done
    success "Symlinks created in ${BIN_DIR}."
}

setup_path() {
    info "5. Configuring shell PATH..."
    local shell_rc=""
    if [[ -f "${HOME}/.zshrc" ]]; then
        shell_rc="${HOME}/.zshrc"
    elif [[ -f "${HOME}/.bash_profile" ]]; then
        shell_rc="${HOME}/.bash_profile"
    elif [[ -f "${HOME}/.bashrc" ]]; then
        shell_rc="${HOME}/.bashrc"
    else
        warn "Could not find .zshrc, .bash_profile, or .bashrc. You will need to add ${BIN_DIR} to your PATH manually."
        return
    fi

    if ! grep -q "${BIN_DIR}" "${shell_rc}" 2>/dev/null; then
        if prompt_yes_no "Add ${BIN_DIR} to your PATH in ${shell_rc}?"; then
            execute "echo '' >> '${shell_rc}'"
            execute "echo '# Thermal Management Suite' >> '${shell_rc}'"
            execute "echo 'export PATH=\\"${BIN_DIR}:\$PATH\\"' >> '${shell_rc}'"
            success "PATH configured in ${shell_rc}."
        else
            warn "Skipping PATH configuration. You must add it manually."
        fi
    else
        success "PATH is already configured."
    fi
}

install_services() {
    if [ "${SETUP_MODE}" = "minimal" ]; then
        info "6. Skipping launchd services installation (minimal mode)."
        return
    fi

    info "6. Installing automated launchd services..."
    
    # Auto Power Mode Service
    if [ "${SETUP_MODE}" = "standard" ] || [ "${SETUP_MODE}" = "full" ]; then
        if prompt_yes_no "Install auto power mode switching service?"; then
            local plist_path="${LAUNCHD_DIR}/com.thermal.power.plist"
            execute "cat > '${plist_path}' << EOF
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
    <key>Label</key>
    <string>com.thermal.power</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BIN_DIR}/thermal-power</string>
        <string>--daemon</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/power_service.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/power_service_error.log</string>
</dict>
</plist>
EOF"
            execute "launchctl load '${plist_path}'"
            success "Auto power mode service installed and loaded."
        fi
    fi

    # Task Scheduler Service
    if [ "${SETUP_MODE}" = "full" ]; then
        if prompt_yes_no "Install thermal-aware task scheduler service?"; then
            local plist_path="${LAUNCHD_DIR}/com.thermal.scheduler.plist"
            execute "cat > '${plist_path}' << EOF
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
    <key>Label</key>
    <string>com.thermal.scheduler</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BIN_DIR}/thermal-schedule</string>
        <string>--process</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/scheduler_service.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/scheduler_service_error.log</string>
</dict>
</plist>
EOF"
            execute "launchctl load '${plist_path}'"
            success "Task scheduler service installed and loaded."
        fi
    fi
}

create_uninstaller() {
    info "7. Creating uninstaller..."
    execute "cat > '${INSTALL_DIR}/uninstall.sh' << 'UNINSTALL_EOF'
#!/bin/bash
# Thermal Management Suite Uninstaller

echo \"Uninstalling Thermal Management Suite...\"

# Stop and unload services
launchctl unload ~/Library/LaunchAgents/com.thermal.power.plist 2>/dev/null || true
launchctl unload ~/Library/LaunchAgents/com.thermal.scheduler.plist 2>/dev/null || true

# Remove launchd plists
rm -f ~/Library/LaunchAgents/com.thermal.power.plist
rm -f ~/Library/LaunchAgents/com.thermal.scheduler.plist

# Remove symlinks
rm -f ~/.local/bin/thermal-monitor
rm -f ~/.local/bin/thermal-power
rm -f ~/.local/bin/thermal-throttle
rm -f ~/.local/bin/thermal-schedule
rm -f ~/.local/bin/thermal-fan
rm -f ~/.local/bin/thermal-optimize
rm -f ~/.local/bin/thermal-uninstall

# Remove installation directory
rm -rf ~/.thermal-management

echo \"Uninstallation complete.\"
echo \"Note: Log files in ~/Library/Logs/ThermalMonitor and shell configuration were preserved.\"
UNINSTALL_EOF"

    execute "chmod +x '${INSTALL_DIR}/uninstall.sh'"
    execute "ln -sf '${INSTALL_DIR}/uninstall.sh' '${BIN_DIR}/thermal-uninstall'"
    success "Uninstaller created."
}

verify_installation() {
    info "8. Verifying installation..."
    local all_good=true

    # Check for bin directory in PATH
    if [[ ":$PATH:" != *":${BIN_DIR}:"* ]]; then
        warn "${BIN_DIR} not found in PATH. You may need to restart your terminal."
        all_good=false
    else
        success "PATH is correctly configured."
    fi

    # Check for thermal-monitor command
    if ! command -v thermal-monitor &> /dev/null; then
        warn "'thermal-monitor' command not found. Verification failed."
        all_good=false
    else
        success "'thermal-monitor' command is available."
    fi

    if [ "$all_good" = false ]; then
        error "Verification failed. Please review the warnings above."
    fi
    success "Installation verified successfully."
}

print_summary() {
    echo ""
    echo -e "${C_GREEN}${C_BOLD}Installation Complete!${C_RESET}"
    echo -e "${C_CYAN}═══════════════════════════════════════════════════════════════════════════════${C_RESET}"
    echo ""
    echo "${C_BOLD}What's Next?${C_RESET}"
    echo "  1. ${C_BOLD}Restart your terminal${C_RESET} or run '. ~/.zshrc' (or equivalent) to start using the commands."
    echo "  2. Run ${C_CYAN}sudo thermal-monitor${C_RESET} to see your system's live thermal status."
    echo "  3. Customize settings in ${C_CYAN}${INSTALL_DIR}/thermal_config.conf${C_RESET}."
    echo "  4. To uninstall, run ${C_CYAN}thermal-uninstall${C_RESET}."
    echo ""
    echo "${C_BOLD}Available Commands:${C_RESET}"
    echo "  thermal-monitor, thermal-power, thermal-throttle, thermal-schedule, thermal-fan, thermal-optimize"
    echo ""
    echo -e "${C_CYAN}═══════════════════════════════════════════════════════════════════════════════${C_RESET}"
}

# --- Main Execution ---
main() {
    parse_args "$@"
    print_banner

    if [ "$DRY_RUN" = true ]; then
        warn "Running in Dry Run mode. No changes will be made."
    fi

    echo "This script will install the Thermal Management Suite."
    echo "Installation mode: ${C_BOLD}${SETUP_MODE}${C_RESET}"
    echo ""

    if ! prompt_yes_no "Do you want to proceed with the installation?"; then
        echo "Installation aborted."
        exit 0
    fi

    check_prerequisites
    setup_directories
    install_scripts
    setup_symlinks
    setup_path
    install_services
    create_uninstaller
    
    if [ "$DRY_RUN" = false ]; then
        verify_installation
    fi

    print_summary
}

main "$@"

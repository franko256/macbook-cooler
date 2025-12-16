#!/bin/bash
#===============================================================================
# AUTOMATIC POWER MODE SWITCHER FOR MACBOOK PRO (M3/M4 MAX)
# Switches between macOS energy modes based on temperature thresholds
# 
# Author: Manus AI
# Version: 1.0.0
# Compatibility: macOS 14+ (Sonoma/Sequoia) with Apple Silicon
#===============================================================================

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="${HOME}/Library/Logs/ThermalMonitor"
readonly LOG_FILE="${LOG_DIR}/power_mode_$(date +%Y%m%d).log"
readonly STATE_FILE="${LOG_DIR}/.power_mode_state"

# Temperature thresholds (Celsius)
# Switch to Low Power Mode when temperature exceeds HIGH_THRESHOLD
# Switch back to Normal/High Performance when below LOW_THRESHOLD
HIGH_THRESHOLD=80
LOW_THRESHOLD=65
CRITICAL_THRESHOLD=90

# Hysteresis to prevent rapid switching (seconds)
MIN_SWITCH_INTERVAL=300

# Check interval (seconds)
CHECK_INTERVAL=30

# Notification settings
ENABLE_NOTIFICATIONS=true

# Colors
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

#-------------------------------------------------------------------------------
# Initialize
#-------------------------------------------------------------------------------
init() {
    mkdir -p "${LOG_DIR}"
    
    # Initialize state file if not exists
    if [[ ! -f "${STATE_FILE}" ]]; then
        echo "normal" > "${STATE_FILE}"
    fi
    
    log_message "INFO" "Auto Power Mode Switcher initialized"
}

#-------------------------------------------------------------------------------
# Logging function
#-------------------------------------------------------------------------------
log_message() {
    local level=$1
    local message=$2
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "${timestamp} [${level}] ${message}" >> "${LOG_FILE}"
    
    case "${level}" in
        ERROR)
            echo -e "${RED}[${level}] ${message}${NC}"
            ;;
        WARN)
            echo -e "${YELLOW}[${level}] ${message}${NC}"
            ;;
        INFO)
            echo -e "${GREEN}[${level}] ${message}${NC}"
            ;;
        *)
            echo "[${level}] ${message}"
            ;;
    esac
}

#-------------------------------------------------------------------------------
# Send macOS notification
#-------------------------------------------------------------------------------
send_notification() {
    local title=$1
    local message=$2
    local sound="${3:-default}"
    
    if [[ "${ENABLE_NOTIFICATIONS}" == "true" ]]; then
        osascript -e "display notification \"${message}\" with title \"${title}\" sound name \"${sound}\"" 2>/dev/null || true
    fi
}

#-------------------------------------------------------------------------------
# Get current CPU temperature
#-------------------------------------------------------------------------------
get_temperature() {
    local temp
    
    # Use powermetrics for accurate temperature
    temp=$(sudo powermetrics --samplers smc -i 1 -n 1 2>/dev/null | \
           grep -E "CPU die temperature|CPU Pcore" | \
           head -1 | \
           grep -oE '[0-9]+\.[0-9]+' | head -1)
    
    if [[ -n "${temp}" ]]; then
        echo "${temp}"
    else
        echo "0"
    fi
}

#-------------------------------------------------------------------------------
# Get current power mode state
#-------------------------------------------------------------------------------
get_current_state() {
    cat "${STATE_FILE}" 2>/dev/null || echo "unknown"
}

#-------------------------------------------------------------------------------
# Set power mode state
#-------------------------------------------------------------------------------
set_state() {
    local state=$1
    echo "${state}" > "${STATE_FILE}"
}

#-------------------------------------------------------------------------------
# Get last switch timestamp
#-------------------------------------------------------------------------------
get_last_switch_time() {
    local state_mtime
    if [[ -f "${STATE_FILE}" ]]; then
        state_mtime=$(stat -f %m "${STATE_FILE}" 2>/dev/null || stat -c %Y "${STATE_FILE}" 2>/dev/null || echo "0")
        echo "${state_mtime}"
    else
        echo "0"
    fi
}

#-------------------------------------------------------------------------------
# Check if enough time has passed since last switch
#-------------------------------------------------------------------------------
can_switch() {
    local current_time
    local last_switch
    local elapsed
    
    current_time=$(date +%s)
    last_switch=$(get_last_switch_time)
    elapsed=$((current_time - last_switch))
    
    if (( elapsed >= MIN_SWITCH_INTERVAL )); then
        return 0
    else
        log_message "INFO" "Hysteresis active: ${elapsed}s since last switch (min: ${MIN_SWITCH_INTERVAL}s)"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Switch to Low Power Mode
#-------------------------------------------------------------------------------
enable_low_power_mode() {
    log_message "INFO" "Switching to Low Power Mode..."
    
    # Enable Low Power Mode via pmset
    sudo pmset -a lowpowermode 1
    
    # Additional power-saving measures
    # Reduce display brightness (optional)
    # osascript -e 'tell application "System Events" to set value of slider 1 of group 1 of window "Display" of application process "System Preferences" to 0.5'
    
    set_state "low_power"
    send_notification "Thermal Management" "Switched to Low Power Mode due to high temperature" "Submarine"
    log_message "INFO" "Low Power Mode enabled"
}

#-------------------------------------------------------------------------------
# Switch to Normal/High Performance Mode
#-------------------------------------------------------------------------------
enable_normal_mode() {
    log_message "INFO" "Switching to Normal Mode..."
    
    # Disable Low Power Mode
    sudo pmset -a lowpowermode 0
    
    set_state "normal"
    send_notification "Thermal Management" "Temperature normalized - Switched to Normal Mode" "Glass"
    log_message "INFO" "Normal Mode enabled"
}

#-------------------------------------------------------------------------------
# Emergency thermal protection
#-------------------------------------------------------------------------------
emergency_thermal_protection() {
    local temp=$1
    
    log_message "ERROR" "CRITICAL TEMPERATURE: ${temp}°C - Initiating emergency measures"
    send_notification "⚠️ THERMAL EMERGENCY" "CPU at ${temp}°C! Taking emergency action!" "Basso"
    
    # Enable Low Power Mode immediately
    sudo pmset -a lowpowermode 1
    
    # Kill resource-intensive processes (optional - uncomment if desired)
    # This will terminate processes using more than 80% CPU
    # ps aux | awk '$3 > 80.0 {print $2}' | xargs -I {} kill -STOP {} 2>/dev/null || true
    
    # Reduce CPU performance (if available)
    # Note: This is limited on Apple Silicon
    
    # Log top CPU consumers
    log_message "WARN" "Top CPU consumers during thermal emergency:"
    ps aux --sort=-%cpu | head -6 >> "${LOG_FILE}"
    
    set_state "emergency"
}

#-------------------------------------------------------------------------------
# Evaluate temperature and switch mode if needed
#-------------------------------------------------------------------------------
evaluate_and_switch() {
    local temp
    local current_state
    local temp_int
    
    temp=$(get_temperature)
    current_state=$(get_current_state)
    
    if [[ "${temp}" == "0" || -z "${temp}" ]]; then
        log_message "WARN" "Could not read temperature"
        return 1
    fi
    
    # Convert to integer for comparison
    temp_int=${temp%.*}
    
    log_message "INFO" "Current temperature: ${temp}°C (State: ${current_state})"
    
    # Emergency check (always applies)
    if (( temp_int >= CRITICAL_THRESHOLD )); then
        emergency_thermal_protection "${temp}"
        return 0
    fi
    
    # Check if we should switch to Low Power Mode
    if (( temp_int >= HIGH_THRESHOLD )) && [[ "${current_state}" != "low_power" ]]; then
        if can_switch; then
            enable_low_power_mode
        fi
        return 0
    fi
    
    # Check if we should switch back to Normal Mode
    if (( temp_int <= LOW_THRESHOLD )) && [[ "${current_state}" == "low_power" || "${current_state}" == "emergency" ]]; then
        if can_switch; then
            enable_normal_mode
        fi
        return 0
    fi
    
    log_message "INFO" "No mode change needed"
}

#-------------------------------------------------------------------------------
# Main monitoring loop
#-------------------------------------------------------------------------------
monitor_loop() {
    log_message "INFO" "Starting continuous monitoring (interval: ${CHECK_INTERVAL}s)"
    log_message "INFO" "Thresholds - High: ${HIGH_THRESHOLD}°C, Low: ${LOW_THRESHOLD}°C, Critical: ${CRITICAL_THRESHOLD}°C"
    
    while true; do
        evaluate_and_switch
        sleep "${CHECK_INTERVAL}"
    done
}

#-------------------------------------------------------------------------------
# Run as daemon (background service)
#-------------------------------------------------------------------------------
run_daemon() {
    local pid_file="${LOG_DIR}/.auto_power_mode.pid"
    
    # Check if already running
    if [[ -f "${pid_file}" ]]; then
        local existing_pid
        existing_pid=$(cat "${pid_file}")
        if kill -0 "${existing_pid}" 2>/dev/null; then
            log_message "WARN" "Daemon already running with PID ${existing_pid}"
            exit 1
        fi
    fi
    
    # Fork to background
    nohup "$0" --monitor > /dev/null 2>&1 &
    echo $! > "${pid_file}"
    
    log_message "INFO" "Daemon started with PID $(cat "${pid_file}")"
}

#-------------------------------------------------------------------------------
# Stop daemon
#-------------------------------------------------------------------------------
stop_daemon() {
    local pid_file="${LOG_DIR}/.auto_power_mode.pid"
    
    if [[ -f "${pid_file}" ]]; then
        local pid
        pid=$(cat "${pid_file}")
        if kill -0 "${pid}" 2>/dev/null; then
            kill "${pid}"
            rm -f "${pid_file}"
            log_message "INFO" "Daemon stopped (PID ${pid})"
        else
            rm -f "${pid_file}"
            log_message "WARN" "Daemon was not running"
        fi
    else
        log_message "WARN" "No daemon PID file found"
    fi
}

#-------------------------------------------------------------------------------
# Show status
#-------------------------------------------------------------------------------
show_status() {
    local temp
    local current_state
    local power_mode
    
    temp=$(get_temperature)
    current_state=$(get_current_state)
    power_mode=$(pmset -g | grep -E "lowpowermode" | awk '{print $2}')
    
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║              AUTO POWER MODE STATUS                              ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    echo "║ Current Temperature: ${temp}°C"
    echo "║ Script State: ${current_state}"
    echo "║ Low Power Mode: $([ "${power_mode}" == "1" ] && echo "Enabled" || echo "Disabled")"
    echo "║ High Threshold: ${HIGH_THRESHOLD}°C"
    echo "║ Low Threshold: ${LOW_THRESHOLD}°C"
    echo "║ Critical Threshold: ${CRITICAL_THRESHOLD}°C"
    echo "╚══════════════════════════════════════════════════════════════════╝"
}

#-------------------------------------------------------------------------------
# Usage
#-------------------------------------------------------------------------------
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Automatic Power Mode Switcher for MacBook Pro M3/M4 Max

OPTIONS:
    -m, --monitor       Start continuous monitoring
    -d, --daemon        Run as background daemon
    -k, --kill          Stop the daemon
    -s, --status        Show current status
    -o, --once          Evaluate once and exit
    -h, --help          Show this help message

CONFIGURATION:
    HIGH_THRESHOLD      Temperature to trigger Low Power Mode (default: ${HIGH_THRESHOLD}°C)
    LOW_THRESHOLD       Temperature to return to Normal Mode (default: ${LOW_THRESHOLD}°C)
    CRITICAL_THRESHOLD  Emergency thermal protection (default: ${CRITICAL_THRESHOLD}°C)
    CHECK_INTERVAL      Monitoring interval in seconds (default: ${CHECK_INTERVAL}s)

EXAMPLES:
    sudo $(basename "$0") -m              # Start monitoring
    sudo $(basename "$0") -d              # Run as daemon
    sudo $(basename "$0") -k              # Stop daemon
    sudo $(basename "$0") -s              # Show status
    sudo $(basename "$0") -o              # Single evaluation

NOTES:
    - Requires sudo for powermetrics and pmset commands
    - Log files: ${LOG_DIR}

EOF
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    local action="monitor"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--monitor)
                action="monitor"
                shift
                ;;
            -d|--daemon)
                action="daemon"
                shift
                ;;
            -k|--kill)
                action="kill"
                shift
                ;;
            -s|--status)
                action="status"
                shift
                ;;
            -o|--once)
                action="once"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Initialize
    init
    
    # Execute action
    case "${action}" in
        monitor)
            monitor_loop
            ;;
        daemon)
            run_daemon
            ;;
        kill)
            stop_daemon
            ;;
        status)
            show_status
            ;;
        once)
            evaluate_and_switch
            ;;
    esac
}

# Ensure running as root for most operations
if [[ $EUID -ne 0 ]] && [[ "${1:-}" != "-h" ]] && [[ "${1:-}" != "--help" ]]; then
    echo -e "${YELLOW}Warning: This script requires sudo for full functionality${NC}"
    echo "Run with: sudo $0 $*"
fi

main "$@"

#!/bin/bash
#===============================================================================
# THERMAL PROCESS THROTTLER FOR MACBOOK PRO (M3/M4 MAX)
# Identifies and throttles resource-intensive background processes during
# thermal events to reduce CPU load and temperature
# 
# Author: Manus AI
# Version: 1.0.0
# Compatibility: macOS 14+ (Sonoma/Sequoia) with Apple Silicon
#===============================================================================

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="${HOME}/Library/Logs/ThermalMonitor"
readonly LOG_FILE="${LOG_DIR}/throttle_$(date +%Y%m%d).log"
readonly THROTTLED_FILE="${LOG_DIR}/.throttled_processes"

# CPU usage threshold for throttling (percentage)
CPU_THRESHOLD=50

# Temperature threshold to trigger throttling
TEMP_THRESHOLD=80

# Processes to never throttle (whitelist)
WHITELIST=(
    "kernel_task"
    "launchd"
    "WindowServer"
    "loginwindow"
    "Finder"
    "Dock"
    "SystemUIServer"
    "Terminal"
    "iTerm2"
    "ssh"
    "sshd"
)

# Processes to always consider for throttling (greylist - throttle if high CPU)
GREYLIST=(
    "mdworker"
    "mds_stores"
    "photolibraryd"
    "photoanalysisd"
    "Spotlight"
    "backupd"
    "Time Machine"
    "softwareupdated"
    "nsurlsessiond"
)

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
    touch "${THROTTLED_FILE}"
    log_message "INFO" "Thermal Throttler initialized"
}

#-------------------------------------------------------------------------------
# Logging
#-------------------------------------------------------------------------------
log_message() {
    local level=$1
    local message=$2
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "${timestamp} [${level}] ${message}" >> "${LOG_FILE}"
    
    case "${level}" in
        ERROR) echo -e "${RED}[${level}] ${message}${NC}" ;;
        WARN)  echo -e "${YELLOW}[${level}] ${message}${NC}" ;;
        INFO)  echo -e "${GREEN}[${level}] ${message}${NC}" ;;
        *)     echo "[${level}] ${message}" ;;
    esac
}

#-------------------------------------------------------------------------------
# Check if process is in whitelist
#-------------------------------------------------------------------------------
is_whitelisted() {
    local process_name=$1
    
    for item in "${WHITELIST[@]}"; do
        if [[ "${process_name}" == *"${item}"* ]]; then
            return 0
        fi
    done
    return 1
}

#-------------------------------------------------------------------------------
# Check if process is in greylist
#-------------------------------------------------------------------------------
is_greylisted() {
    local process_name=$1
    
    for item in "${GREYLIST[@]}"; do
        if [[ "${process_name}" == *"${item}"* ]]; then
            return 0
        fi
    done
    return 1
}

#-------------------------------------------------------------------------------
# Get current CPU temperature
#-------------------------------------------------------------------------------
get_temperature() {
    local temp
    temp=$(sudo powermetrics --samplers smc -i 1 -n 1 2>/dev/null | \
           grep -E "CPU die temperature" | \
           grep -oE '[0-9]+\.[0-9]+' | head -1)
    echo "${temp:-0}"
}

#-------------------------------------------------------------------------------
# Get high CPU processes
#-------------------------------------------------------------------------------
get_high_cpu_processes() {
    # Get processes using more than CPU_THRESHOLD% CPU
    # Format: PID CPU_PERCENT PROCESS_NAME
    ps aux | awk -v threshold="${CPU_THRESHOLD}" \
        'NR>1 && $3 > threshold {print $2, $3, $11}' | \
        sort -k2 -rn
}

#-------------------------------------------------------------------------------
# Get all running processes with CPU usage
#-------------------------------------------------------------------------------
list_processes() {
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║                    TOP CPU CONSUMING PROCESSES                           ║"
    echo "╠══════════════════════════════════════════════════════════════════════════╣"
    printf "║ %-8s %-8s %-8s %-45s ║\n" "PID" "CPU%" "MEM%" "PROCESS"
    echo "╠══════════════════════════════════════════════════════════════════════════╣"
    
    ps aux --sort=-%cpu | head -16 | tail -15 | while read -r line; do
        local pid cpu mem process
        pid=$(echo "${line}" | awk '{print $2}')
        cpu=$(echo "${line}" | awk '{print $3}')
        mem=$(echo "${line}" | awk '{print $4}')
        process=$(echo "${line}" | awk '{print $11}' | xargs basename 2>/dev/null || echo "${line}" | awk '{print $11}')
        
        # Truncate process name if too long
        process="${process:0:45}"
        
        printf "║ %-8s %-8s %-8s %-45s ║\n" "${pid}" "${cpu}" "${mem}" "${process}"
    done
    
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
}

#-------------------------------------------------------------------------------
# Throttle a process (reduce priority using renice)
#-------------------------------------------------------------------------------
throttle_process() {
    local pid=$1
    local process_name=$2
    
    # Check if already throttled
    if grep -q "^${pid}$" "${THROTTLED_FILE}" 2>/dev/null; then
        log_message "INFO" "Process ${pid} (${process_name}) already throttled"
        return 0
    fi
    
    # Reduce process priority (nice value 19 = lowest priority)
    if sudo renice 19 -p "${pid}" > /dev/null 2>&1; then
        echo "${pid}" >> "${THROTTLED_FILE}"
        log_message "INFO" "Throttled process ${pid} (${process_name})"
        return 0
    else
        log_message "ERROR" "Failed to throttle process ${pid} (${process_name})"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Pause a process (SIGSTOP)
#-------------------------------------------------------------------------------
pause_process() {
    local pid=$1
    local process_name=$2
    
    if kill -STOP "${pid}" 2>/dev/null; then
        echo "${pid}:paused" >> "${THROTTLED_FILE}"
        log_message "WARN" "Paused process ${pid} (${process_name})"
        return 0
    else
        log_message "ERROR" "Failed to pause process ${pid}"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Resume a paused process (SIGCONT)
#-------------------------------------------------------------------------------
resume_process() {
    local pid=$1
    
    if kill -CONT "${pid}" 2>/dev/null; then
        # Remove from throttled file
        sed -i '' "/^${pid}:paused$/d" "${THROTTLED_FILE}" 2>/dev/null || true
        log_message "INFO" "Resumed process ${pid}"
        return 0
    else
        log_message "ERROR" "Failed to resume process ${pid}"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Restore all throttled processes
#-------------------------------------------------------------------------------
restore_all() {
    log_message "INFO" "Restoring all throttled processes..."
    
    local count=0
    
    while IFS= read -r line; do
        if [[ -z "${line}" ]]; then
            continue
        fi
        
        if [[ "${line}" == *":paused"* ]]; then
            local pid="${line%%:*}"
            resume_process "${pid}"
        else
            # Restore normal priority
            sudo renice 0 -p "${line}" > /dev/null 2>&1 || true
        fi
        ((count++))
    done < "${THROTTLED_FILE}"
    
    # Clear the throttled file
    > "${THROTTLED_FILE}"
    
    log_message "INFO" "Restored ${count} processes"
}

#-------------------------------------------------------------------------------
# Automatic throttling based on temperature
#-------------------------------------------------------------------------------
auto_throttle() {
    local temp
    temp=$(get_temperature)
    local temp_int=${temp%.*}
    
    log_message "INFO" "Current temperature: ${temp}°C (threshold: ${TEMP_THRESHOLD}°C)"
    
    if (( temp_int < TEMP_THRESHOLD )); then
        log_message "INFO" "Temperature below threshold, no throttling needed"
        return 0
    fi
    
    log_message "WARN" "Temperature above threshold, scanning for processes to throttle..."
    
    local throttled_count=0
    
    # Get high CPU processes
    while IFS= read -r line; do
        if [[ -z "${line}" ]]; then
            continue
        fi
        
        local pid cpu process_name
        pid=$(echo "${line}" | awk '{print $1}')
        cpu=$(echo "${line}" | awk '{print $2}')
        process_name=$(echo "${line}" | awk '{print $3}' | xargs basename 2>/dev/null || echo "${line}" | awk '{print $3}')
        
        # Skip whitelisted processes
        if is_whitelisted "${process_name}"; then
            log_message "INFO" "Skipping whitelisted process: ${process_name} (${pid})"
            continue
        fi
        
        # Throttle greylisted processes more aggressively
        if is_greylisted "${process_name}"; then
            log_message "INFO" "Throttling greylisted process: ${process_name} (${pid}) - CPU: ${cpu}%"
            throttle_process "${pid}" "${process_name}"
            ((throttled_count++))
            continue
        fi
        
        # Throttle other high-CPU processes
        log_message "INFO" "Throttling high-CPU process: ${process_name} (${pid}) - CPU: ${cpu}%"
        throttle_process "${pid}" "${process_name}"
        ((throttled_count++))
        
    done <<< "$(get_high_cpu_processes)"
    
    log_message "INFO" "Throttled ${throttled_count} processes"
}

#-------------------------------------------------------------------------------
# Interactive mode - select processes to throttle
#-------------------------------------------------------------------------------
interactive_throttle() {
    list_processes
    
    echo ""
    echo "Enter PID to throttle (or 'q' to quit, 'r' to restore all):"
    
    while true; do
        read -r -p "> " input
        
        case "${input}" in
            q|Q|quit|exit)
                break
                ;;
            r|R|restore)
                restore_all
                ;;
            [0-9]*)
                local process_name
                process_name=$(ps -p "${input}" -o comm= 2>/dev/null || echo "unknown")
                
                if [[ -n "${process_name}" ]]; then
                    throttle_process "${input}" "${process_name}"
                else
                    echo "Process ${input} not found"
                fi
                ;;
            *)
                echo "Invalid input. Enter a PID, 'r' to restore, or 'q' to quit."
                ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# Monitor and auto-throttle loop
#-------------------------------------------------------------------------------
monitor_loop() {
    local check_interval="${1:-60}"
    
    log_message "INFO" "Starting thermal throttle monitor (interval: ${check_interval}s)"
    
    while true; do
        auto_throttle
        sleep "${check_interval}"
    done
}

#-------------------------------------------------------------------------------
# Kill resource-intensive processes (emergency)
#-------------------------------------------------------------------------------
emergency_kill() {
    log_message "ERROR" "EMERGENCY: Killing high-CPU processes"
    
    # Get processes using more than 80% CPU
    while IFS= read -r line; do
        if [[ -z "${line}" ]]; then
            continue
        fi
        
        local pid process_name
        pid=$(echo "${line}" | awk '{print $1}')
        process_name=$(echo "${line}" | awk '{print $3}' | xargs basename 2>/dev/null)
        
        if is_whitelisted "${process_name}"; then
            continue
        fi
        
        log_message "WARN" "Killing process ${pid} (${process_name})"
        kill -TERM "${pid}" 2>/dev/null || true
        
    done <<< "$(ps aux | awk 'NR>1 && $3 > 80.0 {print $2, $3, $11}')"
}

#-------------------------------------------------------------------------------
# Usage
#-------------------------------------------------------------------------------
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Thermal Process Throttler for MacBook Pro M3/M4 Max

OPTIONS:
    -a, --auto          Automatic throttling based on temperature
    -m, --monitor       Continuous monitoring and auto-throttling
    -i, --interactive   Interactive process selection
    -l, --list          List top CPU-consuming processes
    -r, --restore       Restore all throttled processes
    -e, --emergency     Emergency kill high-CPU processes
    -t, --threshold N   Set CPU threshold percentage (default: ${CPU_THRESHOLD})
    -T, --temp N        Set temperature threshold (default: ${TEMP_THRESHOLD}°C)
    -h, --help          Show this help message

EXAMPLES:
    sudo $(basename "$0") -a              # Auto-throttle based on temperature
    sudo $(basename "$0") -m              # Continuous monitoring
    sudo $(basename "$0") -i              # Interactive mode
    sudo $(basename "$0") -l              # List processes
    sudo $(basename "$0") -r              # Restore all throttled processes

NOTES:
    - Requires sudo for process priority changes
    - Whitelisted processes are never throttled
    - Greylisted processes are throttled more aggressively

EOF
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    local action="auto"
    local interval=60
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--auto)
                action="auto"
                shift
                ;;
            -m|--monitor)
                action="monitor"
                shift
                ;;
            -i|--interactive)
                action="interactive"
                shift
                ;;
            -l|--list)
                action="list"
                shift
                ;;
            -r|--restore)
                action="restore"
                shift
                ;;
            -e|--emergency)
                action="emergency"
                shift
                ;;
            -t|--threshold)
                CPU_THRESHOLD="$2"
                shift 2
                ;;
            -T|--temp)
                TEMP_THRESHOLD="$2"
                shift 2
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
    
    init
    
    case "${action}" in
        auto)
            auto_throttle
            ;;
        monitor)
            monitor_loop "${interval}"
            ;;
        interactive)
            interactive_throttle
            ;;
        list)
            list_processes
            ;;
        restore)
            restore_all
            ;;
        emergency)
            emergency_kill
            ;;
    esac
}

main "$@"

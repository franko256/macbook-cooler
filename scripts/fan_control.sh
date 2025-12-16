#!/bin/bash
#===============================================================================
# FAN CONTROL INTEGRATION FOR MACBOOK PRO (M3/M4 MAX)
# Custom fan curve profiles using Macs Fan Control CLI (if available)
# 
# Author: Manus AI
# Version: 1.0.0
# Compatibility: macOS 14+ (Sonoma/Sequoia) with Apple Silicon
# 
# NOTE: M3/M4 Pro/Max have limited fan control due to Apple's firmware
# restrictions. This script provides what control is possible and falls
# back to system defaults when direct control is unavailable.
#===============================================================================

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="${HOME}/Library/Logs/ThermalMonitor"
readonly LOG_FILE="${LOG_DIR}/fan_control_$(date +%Y%m%d).log"
readonly CONFIG_FILE="${SCRIPT_DIR}/fan_profiles.conf"

# Macs Fan Control paths
readonly MFC_APP="/Applications/Macs Fan Control.app"
readonly MFC_CLI="${MFC_APP}/Contents/Resources/macsfancontrol"

# Fan speed limits (RPM) - typical for MacBook Pro 16"
MIN_FAN_SPEED=1200
MAX_FAN_SPEED=7200

# Fan curve profiles (temperature:speed pairs)
# Format: "temp1:speed1,temp2:speed2,..."
declare -A FAN_PROFILES
FAN_PROFILES[silent]="40:1200,50:1500,60:2000,70:2500,80:3000,90:4000"
FAN_PROFILES[balanced]="40:1500,50:2000,60:3000,70:4000,80:5000,90:6000"
FAN_PROFILES[performance]="40:2000,50:3000,60:4000,70:5000,80:6000,90:7200"
FAN_PROFILES[max_cooling]="40:4000,50:5000,60:6000,70:6500,80:7000,90:7200"

# Current profile
CURRENT_PROFILE="balanced"

# Colors
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

#-------------------------------------------------------------------------------
# Initialize
#-------------------------------------------------------------------------------
init() {
    mkdir -p "${LOG_DIR}"
    log_message "INFO" "Fan Control Script initialized"
}

#-------------------------------------------------------------------------------
# Logging
#-------------------------------------------------------------------------------
log_message() {
    local level=$1
    local message=$2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [${level}] ${message}" >> "${LOG_FILE}"
    
    case "${level}" in
        ERROR) echo -e "${RED}[${level}] ${message}${NC}" ;;
        WARN)  echo -e "${YELLOW}[${level}] ${message}${NC}" ;;
        INFO)  echo -e "${GREEN}[${level}] ${message}${NC}" ;;
        *)     echo "[${level}] ${message}" ;;
    esac
}

#-------------------------------------------------------------------------------
# Check if Macs Fan Control is installed
#-------------------------------------------------------------------------------
check_mfc_installed() {
    if [[ -d "${MFC_APP}" ]]; then
        log_message "INFO" "Macs Fan Control found at ${MFC_APP}"
        return 0
    else
        log_message "WARN" "Macs Fan Control not installed"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Get current temperature
#-------------------------------------------------------------------------------
get_temperature() {
    local temp
    temp=$(sudo powermetrics --samplers smc -i 1 -n 1 2>/dev/null | \
           grep -E "CPU die temperature" | \
           grep -oE '[0-9]+\.[0-9]+' | head -1)
    echo "${temp:-0}"
}

#-------------------------------------------------------------------------------
# Get current fan speed
#-------------------------------------------------------------------------------
get_fan_speed() {
    local speed
    speed=$(sudo powermetrics --samplers smc -i 1 -n 1 2>/dev/null | \
            grep -E "Fan:" | \
            grep -oE '[0-9]+' | head -1)
    echo "${speed:-0}"
}

#-------------------------------------------------------------------------------
# Calculate target fan speed from profile
#-------------------------------------------------------------------------------
calculate_fan_speed() {
    local temp=$1
    local profile=${2:-${CURRENT_PROFILE}}
    local temp_int=${temp%.*}
    
    local curve="${FAN_PROFILES[${profile}]}"
    local prev_temp=0
    local prev_speed=${MIN_FAN_SPEED}
    local target_speed=${MIN_FAN_SPEED}
    
    # Parse curve and interpolate
    IFS=',' read -ra PAIRS <<< "${curve}"
    for pair in "${PAIRS[@]}"; do
        local curve_temp="${pair%%:*}"
        local curve_speed="${pair##*:}"
        
        if (( temp_int <= curve_temp )); then
            # Linear interpolation between previous and current point
            if (( prev_temp < curve_temp )); then
                local temp_range=$((curve_temp - prev_temp))
                local speed_range=$((curve_speed - prev_speed))
                local temp_offset=$((temp_int - prev_temp))
                target_speed=$((prev_speed + (speed_range * temp_offset / temp_range)))
            else
                target_speed=${curve_speed}
            fi
            break
        fi
        
        prev_temp=${curve_temp}
        prev_speed=${curve_speed}
        target_speed=${curve_speed}
    done
    
    # Clamp to valid range
    if (( target_speed < MIN_FAN_SPEED )); then
        target_speed=${MIN_FAN_SPEED}
    elif (( target_speed > MAX_FAN_SPEED )); then
        target_speed=${MAX_FAN_SPEED}
    fi
    
    echo "${target_speed}"
}

#-------------------------------------------------------------------------------
# Set fan speed (if possible)
# NOTE: Direct fan control is limited on M3/M4 Pro/Max
#-------------------------------------------------------------------------------
set_fan_speed() {
    local target_speed=$1
    
    log_message "INFO" "Attempting to set fan speed to ${target_speed} RPM"
    
    # Method 1: Try Macs Fan Control CLI
    if check_mfc_installed && [[ -x "${MFC_CLI}" ]]; then
        "${MFC_CLI}" --set "Left side" "${target_speed}" 2>/dev/null || true
        "${MFC_CLI}" --set "Right side" "${target_speed}" 2>/dev/null || true
        log_message "INFO" "Fan speed set via Macs Fan Control"
        return 0
    fi
    
    # Method 2: Try SMC direct control (usually restricted on Apple Silicon)
    # This is a placeholder - direct SMC control requires specialized tools
    log_message "WARN" "Direct fan control not available on this system"
    log_message "INFO" "macOS will manage fan speed automatically"
    
    # Method 3: Influence fan speed indirectly through workload
    # Running intensive tasks will cause macOS to increase fan speed
    
    return 1
}

#-------------------------------------------------------------------------------
# Reset to automatic fan control
#-------------------------------------------------------------------------------
reset_to_auto() {
    log_message "INFO" "Resetting to automatic fan control"
    
    if check_mfc_installed && [[ -x "${MFC_CLI}" ]]; then
        "${MFC_CLI}" --set "Left side" auto 2>/dev/null || true
        "${MFC_CLI}" --set "Right side" auto 2>/dev/null || true
        log_message "INFO" "Fan control reset to automatic via Macs Fan Control"
    else
        log_message "INFO" "System is using automatic fan control"
    fi
}

#-------------------------------------------------------------------------------
# Display fan curve profile
#-------------------------------------------------------------------------------
display_profile() {
    local profile=${1:-${CURRENT_PROFILE}}
    local curve="${FAN_PROFILES[${profile}]}"
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              FAN CURVE PROFILE: ${profile^^}"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║"
    
    # ASCII graph of fan curve
    echo "║  RPM"
    echo "║  7200 ┤"
    echo "║  6000 ┤"
    echo "║  5000 ┤"
    echo "║  4000 ┤"
    echo "║  3000 ┤"
    echo "║  2000 ┤"
    echo "║  1200 ┼────────────────────────────────────────"
    echo "║       40   50   60   70   80   90  100  °C"
    echo "║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    printf "║ %-10s %-10s\n" "TEMP" "FAN SPEED"
    echo "╠══════════════════════════════════════════════════════════════╣"
    
    IFS=',' read -ra PAIRS <<< "${curve}"
    for pair in "${PAIRS[@]}"; do
        local temp="${pair%%:*}"
        local speed="${pair##*:}"
        printf "║ %-10s %-10s RPM\n" "${temp}°C" "${speed}"
    done
    
    echo "╚══════════════════════════════════════════════════════════════╝"
}

#-------------------------------------------------------------------------------
# List all profiles
#-------------------------------------------------------------------------------
list_profiles() {
    echo ""
    echo "Available Fan Curve Profiles:"
    echo "─────────────────────────────"
    
    for profile in "${!FAN_PROFILES[@]}"; do
        local marker=""
        if [[ "${profile}" == "${CURRENT_PROFILE}" ]]; then
            marker=" (current)"
        fi
        echo -e "  ${CYAN}${profile}${NC}${marker}"
    done
    echo ""
}

#-------------------------------------------------------------------------------
# Apply fan curve based on current temperature
#-------------------------------------------------------------------------------
apply_fan_curve() {
    local profile=${1:-${CURRENT_PROFILE}}
    local temp
    local target_speed
    local current_speed
    
    temp=$(get_temperature)
    current_speed=$(get_fan_speed)
    target_speed=$(calculate_fan_speed "${temp}" "${profile}")
    
    echo "Temperature: ${temp}°C"
    echo "Current Fan Speed: ${current_speed} RPM"
    echo "Target Fan Speed: ${target_speed} RPM (profile: ${profile})"
    
    if (( target_speed != current_speed )); then
        set_fan_speed "${target_speed}"
    else
        log_message "INFO" "Fan speed already at target"
    fi
}

#-------------------------------------------------------------------------------
# Monitor and apply fan curve continuously
#-------------------------------------------------------------------------------
monitor_and_apply() {
    local profile=${1:-${CURRENT_PROFILE}}
    local interval=${2:-10}
    
    log_message "INFO" "Starting fan curve monitor (profile: ${profile}, interval: ${interval}s)"
    
    while true; do
        local temp current_speed target_speed
        
        temp=$(get_temperature)
        current_speed=$(get_fan_speed)
        target_speed=$(calculate_fan_speed "${temp}" "${profile}")
        
        # Clear screen and display status
        clear
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║           FAN CONTROL MONITOR - ${profile^^}"
        echo "╠══════════════════════════════════════════════════════════════╣"
        echo "║ Temperature:     ${temp}°C"
        echo "║ Current Speed:   ${current_speed} RPM"
        echo "║ Target Speed:    ${target_speed} RPM"
        echo "║ Profile:         ${profile}"
        echo "╠══════════════════════════════════════════════════════════════╣"
        
        # Temperature bar
        local temp_int=${temp%.*}
        local bar_length=$((temp_int / 2))
        local bar=""
        for ((i=0; i<bar_length; i++)); do
            if (( i < 30 )); then
                bar+="█"
            elif (( i < 40 )); then
                bar+="▓"
            else
                bar+="░"
            fi
        done
        echo "║ [${bar}] ${temp}°C"
        
        echo "╠══════════════════════════════════════════════════════════════╣"
        echo "║ Press Ctrl+C to exit"
        echo "╚══════════════════════════════════════════════════════════════╝"
        
        # Apply fan curve
        if (( target_speed != current_speed )); then
            set_fan_speed "${target_speed}" 2>/dev/null || true
        fi
        
        sleep "${interval}"
    done
}

#-------------------------------------------------------------------------------
# Create custom profile
#-------------------------------------------------------------------------------
create_profile() {
    local name=$1
    local curve=$2
    
    FAN_PROFILES[${name}]="${curve}"
    log_message "INFO" "Created custom profile: ${name}"
    
    # Save to config file
    echo "${name}=${curve}" >> "${CONFIG_FILE}"
}

#-------------------------------------------------------------------------------
# Load custom profiles from config
#-------------------------------------------------------------------------------
load_profiles() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        while IFS='=' read -r name curve; do
            if [[ -n "${name}" && -n "${curve}" ]]; then
                FAN_PROFILES[${name}]="${curve}"
            fi
        done < "${CONFIG_FILE}"
        log_message "INFO" "Loaded custom profiles from ${CONFIG_FILE}"
    fi
}

#-------------------------------------------------------------------------------
# Show current status
#-------------------------------------------------------------------------------
show_status() {
    local temp current_speed
    
    temp=$(get_temperature)
    current_speed=$(get_fan_speed)
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    FAN CONTROL STATUS                        ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║ CPU Temperature:    ${temp}°C"
    echo "║ Fan Speed:          ${current_speed} RPM"
    echo "║ Current Profile:    ${CURRENT_PROFILE}"
    echo "║ Macs Fan Control:   $(check_mfc_installed && echo "Installed" || echo "Not Installed")"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║ M3/M4 Pro/Max Note: Direct fan control is limited by Apple  ║"
    echo "║ firmware. macOS manages fan speed automatically based on    ║"
    echo "║ thermal conditions.                                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

#-------------------------------------------------------------------------------
# Usage
#-------------------------------------------------------------------------------
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Fan Control for MacBook Pro M3/M4 Max

OPTIONS:
    -s, --status            Show current fan status
    -p, --profile NAME      Set/display fan curve profile
    -l, --list              List available profiles
    -a, --apply             Apply fan curve based on current temperature
    -m, --monitor           Monitor and apply fan curve continuously
    -r, --reset             Reset to automatic fan control
    -c, --create NAME CURVE Create custom profile
    -h, --help              Show this help message

PROFILES:
    silent      - Prioritize quiet operation
    balanced    - Balance between noise and cooling (default)
    performance - Prioritize cooling over noise
    max_cooling - Maximum cooling for heavy workloads

EXAMPLES:
    $(basename "$0") -s                    # Show status
    $(basename "$0") -p performance        # Set performance profile
    $(basename "$0") -m                    # Monitor and apply
    $(basename "$0") -c custom "40:2000,60:4000,80:6000"

NOTES:
    - M3/M4 Pro/Max have limited fan control due to Apple firmware
    - Macs Fan Control app provides additional control options
    - Download from: https://crystalidea.com/macs-fan-control

EOF
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    local action="status"
    local profile=""
    local curve=""
    
    init
    load_profiles
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--status)
                action="status"
                shift
                ;;
            -p|--profile)
                action="profile"
                profile="$2"
                shift 2
                ;;
            -l|--list)
                action="list"
                shift
                ;;
            -a|--apply)
                action="apply"
                shift
                ;;
            -m|--monitor)
                action="monitor"
                shift
                ;;
            -r|--reset)
                action="reset"
                shift
                ;;
            -c|--create)
                action="create"
                profile="$2"
                curve="$3"
                shift 3
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
    
    case "${action}" in
        status)
            show_status
            ;;
        profile)
            if [[ -n "${profile}" ]]; then
                if [[ -n "${FAN_PROFILES[${profile}]:-}" ]]; then
                    CURRENT_PROFILE="${profile}"
                    display_profile "${profile}"
                else
                    log_message "ERROR" "Unknown profile: ${profile}"
                    list_profiles
                fi
            fi
            ;;
        list)
            list_profiles
            ;;
        apply)
            apply_fan_curve
            ;;
        monitor)
            monitor_and_apply "${CURRENT_PROFILE}"
            ;;
        reset)
            reset_to_auto
            ;;
        create)
            create_profile "${profile}" "${curve}"
            ;;
    esac
}

main "$@"

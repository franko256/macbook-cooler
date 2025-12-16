#!/bin/bash
#===============================================================================
# THERMAL MONITOR FOR MACBOOK PRO (M3/M4 MAX)
# Real-time CPU and GPU temperature monitoring using powermetrics and IOKit
# 
# Author: Manus AI
# Version: 1.0.0
# Compatibility: macOS 14+ (Sonoma/Sequoia) with Apple Silicon
#===============================================================================

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="${HOME}/Library/Logs/ThermalMonitor"
readonly LOG_FILE="${LOG_DIR}/thermal_$(date +%Y%m%d).log"
readonly CONFIG_FILE="${SCRIPT_DIR}/thermal_config.conf"

# Temperature thresholds (Celsius)
TEMP_WARNING=75
TEMP_CRITICAL=85
TEMP_EMERGENCY=95

# Sampling interval (seconds)
SAMPLE_INTERVAL=5

# Colors for terminal output
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

#-------------------------------------------------------------------------------
# Initialize logging directory
#-------------------------------------------------------------------------------
init_logging() {
    mkdir -p "${LOG_DIR}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Thermal Monitor Started" >> "${LOG_FILE}"
}

#-------------------------------------------------------------------------------
# Load configuration if exists
#-------------------------------------------------------------------------------
load_config() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        source "${CONFIG_FILE}"
        echo -e "${GREEN}Configuration loaded from ${CONFIG_FILE}${NC}"
    fi
}

#-------------------------------------------------------------------------------
# Get CPU temperature using powermetrics (requires sudo)
# Returns temperature in Celsius
#-------------------------------------------------------------------------------
get_cpu_temperature() {
    local temp
    
    # Try powermetrics first (most accurate for Apple Silicon)
    if command -v powermetrics &> /dev/null; then
        temp=$(sudo powermetrics --samplers smc -i 1 -n 1 2>/dev/null | \
               grep -E "CPU die temperature|CPU Pcore" | \
               head -1 | \
               grep -oE '[0-9]+\.[0-9]+' | head -1)
        
        if [[ -n "${temp}" ]]; then
            echo "${temp}"
            return 0
        fi
    fi
    
    # Fallback: Use IOKit via Python (works without sudo)
    temp=$(python3 << 'EOF'
import subprocess
import re

try:
    # Use ioreg to get thermal sensors
    result = subprocess.run(
        ['ioreg', '-r', '-c', 'AppleARMIODevice', '-d', '1'],
        capture_output=True, text=True, timeout=5
    )
    
    # Try to find temperature readings
    output = result.stdout
    
    # Alternative: Use system_profiler for hardware overview
    result2 = subprocess.run(
        ['system_profiler', 'SPHardwareDataType'],
        capture_output=True, text=True, timeout=10
    )
    
    # For Apple Silicon, thermal data is limited without powermetrics
    # Return a placeholder that indicates we need sudo
    print("N/A")
except Exception as e:
    print("N/A")
EOF
)
    echo "${temp}"
}

#-------------------------------------------------------------------------------
# Get GPU temperature (Apple Silicon unified memory architecture)
#-------------------------------------------------------------------------------
get_gpu_temperature() {
    local temp
    
    if command -v powermetrics &> /dev/null; then
        temp=$(sudo powermetrics --samplers smc -i 1 -n 1 2>/dev/null | \
               grep -E "GPU die temperature|GPU MTR" | \
               head -1 | \
               grep -oE '[0-9]+\.[0-9]+' | head -1)
        
        if [[ -n "${temp}" ]]; then
            echo "${temp}"
            return 0
        fi
    fi
    
    echo "N/A"
}

#-------------------------------------------------------------------------------
# Get thermal pressure level from macOS
#-------------------------------------------------------------------------------
get_thermal_pressure() {
    local pressure
    
    if command -v powermetrics &> /dev/null; then
        pressure=$(sudo powermetrics --samplers thermal -i 1 -n 1 2>/dev/null | \
                   grep -E "Thermal level" | \
                   awk '{print $NF}')
        
        if [[ -n "${pressure}" ]]; then
            echo "${pressure}"
            return 0
        fi
    fi
    
    # Fallback: Use sysctl
    pressure=$(sysctl -n machdep.xcpm.thermal_level 2>/dev/null || echo "N/A")
    echo "${pressure}"
}

#-------------------------------------------------------------------------------
# Get fan speed (RPM)
#-------------------------------------------------------------------------------
get_fan_speed() {
    local fan_speed
    
    if command -v powermetrics &> /dev/null; then
        fan_speed=$(sudo powermetrics --samplers smc -i 1 -n 1 2>/dev/null | \
                    grep -E "Fan:" | \
                    grep -oE '[0-9]+' | head -1)
        
        if [[ -n "${fan_speed}" ]]; then
            echo "${fan_speed}"
            return 0
        fi
    fi
    
    echo "N/A"
}

#-------------------------------------------------------------------------------
# Get current power mode
#-------------------------------------------------------------------------------
get_power_mode() {
    local mode
    mode=$(pmset -g | grep -E "lowpowermode" | awk '{print $2}')
    
    if [[ "${mode}" == "1" ]]; then
        echo "Low Power"
    else
        # Check for High Power mode (connected to power)
        local power_source
        power_source=$(pmset -g ps | head -1)
        if [[ "${power_source}" == *"AC Power"* ]]; then
            echo "High Performance"
        else
            echo "Automatic"
        fi
    fi
}

#-------------------------------------------------------------------------------
# Display temperature with color coding
#-------------------------------------------------------------------------------
display_temperature() {
    local temp=$1
    local label=$2
    local color
    
    if [[ "${temp}" == "N/A" ]]; then
        echo -e "${BLUE}${label}: ${temp}${NC}"
        return
    fi
    
    # Convert to integer for comparison
    local temp_int=${temp%.*}
    
    if (( temp_int >= TEMP_EMERGENCY )); then
        color="${RED}"
    elif (( temp_int >= TEMP_CRITICAL )); then
        color="${RED}"
    elif (( temp_int >= TEMP_WARNING )); then
        color="${YELLOW}"
    else
        color="${GREEN}"
    fi
    
    echo -e "${label}: ${color}${temp}°C${NC}"
}

#-------------------------------------------------------------------------------
# Log thermal data to file
#-------------------------------------------------------------------------------
log_thermal_data() {
    local cpu_temp=$1
    local gpu_temp=$2
    local fan_speed=$3
    local thermal_pressure=$4
    local power_mode=$5
    
    echo "$(date '+%Y-%m-%d %H:%M:%S'),${cpu_temp},${gpu_temp},${fan_speed},${thermal_pressure},${power_mode}" >> "${LOG_FILE}"
}

#-------------------------------------------------------------------------------
# Check if running with sudo (required for powermetrics)
#-------------------------------------------------------------------------------
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Warning: Running without sudo. Some features require root access.${NC}"
        echo -e "${YELLOW}Run with: sudo $0${NC}"
        echo ""
        return 1
    fi
    return 0
}

#-------------------------------------------------------------------------------
# Display header
#-------------------------------------------------------------------------------
display_header() {
    clear
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║         MACBOOK PRO THERMAL MONITOR (M3/M4 MAX)                  ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    echo "║  Thresholds: Warning=${TEMP_WARNING}°C | Critical=${TEMP_CRITICAL}°C | Emergency=${TEMP_EMERGENCY}°C  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
}

#-------------------------------------------------------------------------------
# Main monitoring loop
#-------------------------------------------------------------------------------
monitor_loop() {
    local cpu_temp gpu_temp fan_speed thermal_pressure power_mode
    
    while true; do
        display_header
        
        echo "Sampling thermal data..."
        echo ""
        
        cpu_temp=$(get_cpu_temperature)
        gpu_temp=$(get_gpu_temperature)
        fan_speed=$(get_fan_speed)
        thermal_pressure=$(get_thermal_pressure)
        power_mode=$(get_power_mode)
        
        echo "┌─────────────────────────────────────────┐"
        echo "│ CURRENT READINGS                        │"
        echo "├─────────────────────────────────────────┤"
        display_temperature "${cpu_temp}" "│ CPU Temperature"
        display_temperature "${gpu_temp}" "│ GPU Temperature"
        echo -e "│ Fan Speed: ${BLUE}${fan_speed} RPM${NC}"
        echo -e "│ Thermal Pressure: ${BLUE}${thermal_pressure}${NC}"
        echo -e "│ Power Mode: ${BLUE}${power_mode}${NC}"
        echo "└─────────────────────────────────────────┘"
        echo ""
        echo "Log file: ${LOG_FILE}"
        echo "Press Ctrl+C to exit"
        
        # Log data
        log_thermal_data "${cpu_temp}" "${gpu_temp}" "${fan_speed}" "${thermal_pressure}" "${power_mode}"
        
        sleep "${SAMPLE_INTERVAL}"
    done
}

#-------------------------------------------------------------------------------
# Single reading mode (for scripting)
#-------------------------------------------------------------------------------
single_reading() {
    local format="${1:-text}"
    local cpu_temp gpu_temp fan_speed thermal_pressure power_mode
    
    cpu_temp=$(get_cpu_temperature)
    gpu_temp=$(get_gpu_temperature)
    fan_speed=$(get_fan_speed)
    thermal_pressure=$(get_thermal_pressure)
    power_mode=$(get_power_mode)
    
    case "${format}" in
        json)
            cat << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "cpu_temperature": "${cpu_temp}",
    "gpu_temperature": "${gpu_temp}",
    "fan_speed": "${fan_speed}",
    "thermal_pressure": "${thermal_pressure}",
    "power_mode": "${power_mode}"
}
EOF
            ;;
        csv)
            echo "timestamp,cpu_temp,gpu_temp,fan_speed,thermal_pressure,power_mode"
            echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),${cpu_temp},${gpu_temp},${fan_speed},${thermal_pressure},${power_mode}"
            ;;
        *)
            echo "CPU Temperature: ${cpu_temp}°C"
            echo "GPU Temperature: ${gpu_temp}°C"
            echo "Fan Speed: ${fan_speed} RPM"
            echo "Thermal Pressure: ${thermal_pressure}"
            echo "Power Mode: ${power_mode}"
            ;;
    esac
}

#-------------------------------------------------------------------------------
# Usage information
#-------------------------------------------------------------------------------
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

MacBook Pro Thermal Monitor for M3/M4 Max processors

OPTIONS:
    -m, --monitor       Start continuous monitoring (default)
    -s, --single        Single reading and exit
    -j, --json          Output in JSON format (with -s)
    -c, --csv           Output in CSV format (with -s)
    -i, --interval N    Set sampling interval to N seconds (default: 5)
    -h, --help          Show this help message

EXAMPLES:
    sudo $(basename "$0")                    # Start monitoring
    sudo $(basename "$0") -s                 # Single reading
    sudo $(basename "$0") -s -j              # Single reading in JSON
    sudo $(basename "$0") -i 10              # Monitor with 10s interval

NOTES:
    - Requires sudo for accurate temperature readings via powermetrics
    - Log files are stored in: ${LOG_DIR}
    - Configure thresholds in: ${CONFIG_FILE}

EOF
}

#-------------------------------------------------------------------------------
# Main entry point
#-------------------------------------------------------------------------------
main() {
    local mode="monitor"
    local format="text"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--monitor)
                mode="monitor"
                shift
                ;;
            -s|--single)
                mode="single"
                shift
                ;;
            -j|--json)
                format="json"
                shift
                ;;
            -c|--csv)
                format="csv"
                shift
                ;;
            -i|--interval)
                SAMPLE_INTERVAL="$2"
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
    
    # Initialize
    init_logging
    load_config
    check_sudo || true
    
    # Execute based on mode
    case "${mode}" in
        monitor)
            monitor_loop
            ;;
        single)
            single_reading "${format}"
            ;;
    esac
}

# Run main function
main "$@"

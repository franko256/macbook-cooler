#!/bin/bash
#===============================================================================
# SYSTEM OPTIMIZER FOR MACBOOK PRO (M3/M4 MAX)
# Disable unnecessary launch agents, optimize processes, and reduce thermal load
# 
# Author: Manus AI
# Version: 1.0.0
# Compatibility: macOS 14+ (Sonoma/Sequoia) with Apple Silicon
#===============================================================================

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="${HOME}/Library/Logs/ThermalMonitor"
readonly LOG_FILE="${LOG_DIR}/optimizer_$(date +%Y%m%d).log"
readonly BACKUP_DIR="${HOME}/Library/LaunchAgents.backup"

# Colors
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

#-------------------------------------------------------------------------------
# Common resource-intensive launch agents that can be safely disabled
#-------------------------------------------------------------------------------
OPTIONAL_AGENTS=(
    # Adobe
    "com.adobe.AdobeCreativeCloud"
    "com.adobe.CCXProcess"
    "com.adobe.CCLibrary"
    "com.adobe.accmac"
    
    # Microsoft
    "com.microsoft.update.agent"
    "com.microsoft.autoupdate.helper"
    
    # Google
    "com.google.keystone.agent"
    "com.google.keystone.xpcservice"
    
    # Dropbox
    "com.dropbox.DropboxMacUpdate.agent"
    
    # Spotify
    "com.spotify.webhelper"
    
    # Steam
    "com.valvesoftware.steamclean"
    
    # Various updaters
    "com.oracle.java.Java-Updater"
)

#-------------------------------------------------------------------------------
# System agents that should NOT be disabled
#-------------------------------------------------------------------------------
PROTECTED_AGENTS=(
    "com.apple"
    "com.openssh"
    "org.cups"
)

#-------------------------------------------------------------------------------
# Initialize
#-------------------------------------------------------------------------------
init() {
    mkdir -p "${LOG_DIR}"
    mkdir -p "${BACKUP_DIR}"
    log_message "INFO" "System Optimizer initialized"
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
# Check if agent is protected
#-------------------------------------------------------------------------------
is_protected() {
    local agent=$1
    
    for protected in "${PROTECTED_AGENTS[@]}"; do
        if [[ "${agent}" == ${protected}* ]]; then
            return 0
        fi
    done
    return 1
}

#-------------------------------------------------------------------------------
# List all launch agents
#-------------------------------------------------------------------------------
list_launch_agents() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           LAUNCH AGENTS                                      ║"
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    
    echo "║ USER AGENTS (~Library/LaunchAgents):"
    echo "╠──────────────────────────────────────────────────────────────────────────────╣"
    
    if [[ -d "${HOME}/Library/LaunchAgents" ]]; then
        for plist in "${HOME}/Library/LaunchAgents"/*.plist; do
            if [[ -f "${plist}" ]]; then
                local name
                name=$(basename "${plist}" .plist)
                local status
                if launchctl list | grep -q "${name}"; then
                    status="${GREEN}[RUNNING]${NC}"
                else
                    status="${YELLOW}[STOPPED]${NC}"
                fi
                echo -e "║   ${name} ${status}"
            fi
        done
    fi
    
    echo "╠──────────────────────────────────────────────────────────────────────────────╣"
    echo "║ GLOBAL AGENTS (/Library/LaunchAgents):"
    echo "╠──────────────────────────────────────────────────────────────────────────────╣"
    
    if [[ -d "/Library/LaunchAgents" ]]; then
        for plist in /Library/LaunchAgents/*.plist; do
            if [[ -f "${plist}" ]]; then
                local name
                name=$(basename "${plist}" .plist)
                local status
                if launchctl list | grep -q "${name}"; then
                    status="${GREEN}[RUNNING]${NC}"
                else
                    status="${YELLOW}[STOPPED]${NC}"
                fi
                echo -e "║   ${name} ${status}"
            fi
        done
    fi
    
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
}

#-------------------------------------------------------------------------------
# Disable a launch agent
#-------------------------------------------------------------------------------
disable_agent() {
    local agent_name=$1
    local plist_path=""
    
    # Find the plist file
    if [[ -f "${HOME}/Library/LaunchAgents/${agent_name}.plist" ]]; then
        plist_path="${HOME}/Library/LaunchAgents/${agent_name}.plist"
    elif [[ -f "/Library/LaunchAgents/${agent_name}.plist" ]]; then
        plist_path="/Library/LaunchAgents/${agent_name}.plist"
    else
        log_message "WARN" "Agent not found: ${agent_name}"
        return 1
    fi
    
    # Check if protected
    if is_protected "${agent_name}"; then
        log_message "ERROR" "Cannot disable protected agent: ${agent_name}"
        return 1
    fi
    
    # Backup the plist
    cp "${plist_path}" "${BACKUP_DIR}/" 2>/dev/null || true
    
    # Unload the agent
    launchctl unload "${plist_path}" 2>/dev/null || true
    
    # Disable by renaming (add .disabled extension)
    mv "${plist_path}" "${plist_path}.disabled" 2>/dev/null || \
        sudo mv "${plist_path}" "${plist_path}.disabled"
    
    log_message "INFO" "Disabled agent: ${agent_name}"
}

#-------------------------------------------------------------------------------
# Enable a launch agent
#-------------------------------------------------------------------------------
enable_agent() {
    local agent_name=$1
    local plist_path=""
    
    # Find the disabled plist file
    if [[ -f "${HOME}/Library/LaunchAgents/${agent_name}.plist.disabled" ]]; then
        plist_path="${HOME}/Library/LaunchAgents/${agent_name}.plist"
    elif [[ -f "/Library/LaunchAgents/${agent_name}.plist.disabled" ]]; then
        plist_path="/Library/LaunchAgents/${agent_name}.plist"
    else
        log_message "WARN" "Disabled agent not found: ${agent_name}"
        return 1
    fi
    
    # Re-enable by removing .disabled extension
    mv "${plist_path}.disabled" "${plist_path}" 2>/dev/null || \
        sudo mv "${plist_path}.disabled" "${plist_path}"
    
    # Load the agent
    launchctl load "${plist_path}" 2>/dev/null || true
    
    log_message "INFO" "Enabled agent: ${agent_name}"
}

#-------------------------------------------------------------------------------
# Disable all optional agents
#-------------------------------------------------------------------------------
disable_optional_agents() {
    log_message "INFO" "Disabling optional launch agents..."
    
    local disabled_count=0
    
    for agent in "${OPTIONAL_AGENTS[@]}"; do
        if [[ -f "${HOME}/Library/LaunchAgents/${agent}.plist" ]] || \
           [[ -f "/Library/LaunchAgents/${agent}.plist" ]]; then
            disable_agent "${agent}"
            ((disabled_count++))
        fi
    done
    
    log_message "INFO" "Disabled ${disabled_count} optional agents"
}

#-------------------------------------------------------------------------------
# Optimize Spotlight indexing
#-------------------------------------------------------------------------------
optimize_spotlight() {
    log_message "INFO" "Optimizing Spotlight indexing..."
    
    echo "Current Spotlight exclusions:"
    sudo mdutil -s / 2>/dev/null || true
    
    # Temporarily disable Spotlight for heavy workloads
    echo ""
    echo "To temporarily disable Spotlight indexing:"
    echo "  sudo mdutil -a -i off"
    echo ""
    echo "To re-enable Spotlight indexing:"
    echo "  sudo mdutil -a -i on"
    echo ""
    echo "To add exclusions, go to:"
    echo "  System Settings > Siri & Spotlight > Spotlight Privacy"
}

#-------------------------------------------------------------------------------
# Optimize Time Machine
#-------------------------------------------------------------------------------
optimize_time_machine() {
    log_message "INFO" "Checking Time Machine settings..."
    
    # Check if Time Machine is running
    local tm_status
    tm_status=$(tmutil status 2>/dev/null | grep "Running" || echo "Not running")
    
    echo "Time Machine Status: ${tm_status}"
    echo ""
    echo "To temporarily disable Time Machine during heavy workloads:"
    echo "  sudo tmutil disable"
    echo ""
    echo "To re-enable Time Machine:"
    echo "  sudo tmutil enable"
    echo ""
    echo "To exclude directories from backup:"
    echo "  sudo tmutil addexclusion /path/to/directory"
}

#-------------------------------------------------------------------------------
# Kill resource-intensive background processes
#-------------------------------------------------------------------------------
kill_background_processes() {
    log_message "INFO" "Checking for resource-intensive background processes..."
    
    # List of processes that can be safely killed
    local killable_processes=(
        "mdworker_shared"
        "mds_stores"
        "photolibraryd"
        "photoanalysisd"
        "cloudd"
        "nsurlsessiond"
        "softwareupdated"
    )
    
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║           RESOURCE-INTENSIVE BACKGROUND PROCESSES                ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    
    for proc in "${killable_processes[@]}"; do
        local pids
        pids=$(pgrep -x "${proc}" 2>/dev/null || echo "")
        
        if [[ -n "${pids}" ]]; then
            local cpu_usage
            cpu_usage=$(ps -p "${pids}" -o %cpu= 2>/dev/null | head -1 || echo "0")
            echo "║ ${proc}: PID ${pids}, CPU ${cpu_usage}%"
        fi
    done
    
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "To kill a specific process:"
    echo "  killall -STOP processname  # Pause process"
    echo "  killall -CONT processname  # Resume process"
    echo "  killall processname        # Terminate process"
}

#-------------------------------------------------------------------------------
# Optimize memory pressure
#-------------------------------------------------------------------------------
optimize_memory() {
    log_message "INFO" "Checking memory status..."
    
    # Get memory statistics
    local mem_stats
    mem_stats=$(vm_stat)
    
    local page_size=16384  # Apple Silicon uses 16KB pages
    local free_pages active_pages inactive_pages wired_pages
    
    free_pages=$(echo "${mem_stats}" | grep "Pages free" | awk '{print $3}' | tr -d '.')
    active_pages=$(echo "${mem_stats}" | grep "Pages active" | awk '{print $3}' | tr -d '.')
    inactive_pages=$(echo "${mem_stats}" | grep "Pages inactive" | awk '{print $3}' | tr -d '.')
    wired_pages=$(echo "${mem_stats}" | grep "Pages wired" | awk '{print $4}' | tr -d '.')
    
    local free_mb=$((free_pages * page_size / 1024 / 1024))
    local active_mb=$((active_pages * page_size / 1024 / 1024))
    local inactive_mb=$((inactive_pages * page_size / 1024 / 1024))
    local wired_mb=$((wired_pages * page_size / 1024 / 1024))
    
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                     MEMORY STATUS                                ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    echo "║ Free Memory:     ${free_mb} MB"
    echo "║ Active Memory:   ${active_mb} MB"
    echo "║ Inactive Memory: ${inactive_mb} MB"
    echo "║ Wired Memory:    ${wired_mb} MB"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "To purge inactive memory (may cause brief slowdown):"
    echo "  sudo purge"
}

#-------------------------------------------------------------------------------
# Optimize for video rendering
#-------------------------------------------------------------------------------
optimize_for_rendering() {
    log_message "INFO" "Applying optimizations for video rendering..."
    
    echo "Optimizations for Video Rendering:"
    echo "─────────────────────────────────────"
    echo ""
    echo "1. Disable Spotlight indexing:"
    echo "   sudo mdutil -a -i off"
    echo ""
    echo "2. Disable Time Machine:"
    echo "   sudo tmutil disable"
    echo ""
    echo "3. Close unnecessary applications"
    echo ""
    echo "4. Set power mode to High Performance:"
    echo "   sudo pmset -a lowpowermode 0"
    echo ""
    echo "5. Disable automatic updates:"
    echo "   sudo softwareupdate --schedule off"
    echo ""
    echo "6. Use ProRes or optimized codecs for better hardware acceleration"
    echo ""
    echo "7. Enable GPU acceleration in your rendering software"
}

#-------------------------------------------------------------------------------
# Optimize for ML training
#-------------------------------------------------------------------------------
optimize_for_ml() {
    log_message "INFO" "Applying optimizations for ML training..."
    
    echo "Optimizations for Machine Learning:"
    echo "─────────────────────────────────────"
    echo ""
    echo "1. Use Metal Performance Shaders (MPS) backend:"
    echo "   export PYTORCH_ENABLE_MPS_FALLBACK=1"
    echo "   device = torch.device('mps')"
    echo ""
    echo "2. Optimize batch sizes for unified memory:"
    echo "   - Start with smaller batches and increase"
    echo "   - Monitor memory pressure with Activity Monitor"
    echo ""
    echo "3. Use mixed precision training:"
    echo "   - torch.cuda.amp equivalent for MPS"
    echo ""
    echo "4. Disable unnecessary background processes"
    echo ""
    echo "5. Schedule training during cooler periods:"
    echo "   ./thermal_scheduler.sh -a 'ML Training' 'python train.py'"
    echo ""
    echo "6. Monitor thermal throttling:"
    echo "   sudo powermetrics --samplers thermal"
}

#-------------------------------------------------------------------------------
# Optimize for virtual machines
#-------------------------------------------------------------------------------
optimize_for_vms() {
    log_message "INFO" "Applying optimizations for virtual machines..."
    
    echo "Optimizations for Virtual Machines:"
    echo "─────────────────────────────────────"
    echo ""
    echo "1. Allocate appropriate CPU cores:"
    echo "   - Leave 2-4 cores for host system"
    echo "   - M4 Max has 16 cores (12P + 4E)"
    echo ""
    echo "2. Memory allocation:"
    echo "   - Don't exceed 75% of total RAM for VMs"
    echo "   - With 128GB, max ~96GB for VMs"
    echo ""
    echo "3. Use efficient virtualization:"
    echo "   - UTM (QEMU-based, optimized for Apple Silicon)"
    echo "   - Parallels Desktop (best performance)"
    echo "   - VMware Fusion (good compatibility)"
    echo ""
    echo "4. Storage optimization:"
    echo "   - Use APFS sparse images"
    echo "   - Store VMs on fast internal SSD"
    echo ""
    echo "5. Network optimization:"
    echo "   - Use bridged networking when possible"
    echo ""
    echo "6. Disable VM features not needed:"
    echo "   - 3D acceleration if not required"
    echo "   - Shared folders if not needed"
}

#-------------------------------------------------------------------------------
# Generate optimization report
#-------------------------------------------------------------------------------
generate_report() {
    local report_file="${LOG_DIR}/optimization_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "${report_file}" << EOF
# System Optimization Report
Generated: $(date)

## System Information
- Model: MacBook Pro (M4 Max)
- Memory: 128 GB Unified Memory
- macOS: $(sw_vers -productVersion)

## Current Status

### Temperature
$(get_temperature 2>/dev/null || echo "N/A")°C

### Memory Usage
$(vm_stat | head -10)

### Top CPU Processes
$(ps aux --sort=-%cpu | head -10)

### Launch Agents Status
$(launchctl list | wc -l) agents loaded

## Recommendations

1. **Immediate Actions**
   - Restart Mac to clear memory pressure (uptime: $(uptime | awk '{print $3}'))
   - Close unused applications
   - Check for runaway processes

2. **Short-term Optimizations**
   - Disable unnecessary launch agents
   - Optimize Spotlight indexing
   - Schedule heavy tasks for cooler periods

3. **Long-term Solutions**
   - Consider external cooling solution
   - Review workflow for thermal efficiency
   - Regular maintenance schedule

## Applied Optimizations
$(cat "${LOG_FILE}" | tail -20)
EOF

    log_message "INFO" "Report generated: ${report_file}"
    echo "Report saved to: ${report_file}"
}

#-------------------------------------------------------------------------------
# Usage
#-------------------------------------------------------------------------------
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

System Optimizer for MacBook Pro M3/M4 Max

OPTIONS:
    -l, --list-agents       List all launch agents
    -d, --disable AGENT     Disable specific launch agent
    -e, --enable AGENT      Enable specific launch agent
    -D, --disable-optional  Disable all optional agents
    -s, --spotlight         Optimize Spotlight settings
    -t, --timemachine       Optimize Time Machine settings
    -k, --kill-bg           Show killable background processes
    -m, --memory            Show memory optimization options
    -r, --rendering         Optimizations for video rendering
    -M, --ml                Optimizations for ML training
    -v, --vms               Optimizations for virtual machines
    -R, --report            Generate optimization report
    -h, --help              Show this help message

EXAMPLES:
    $(basename "$0") -l                    # List launch agents
    $(basename "$0") -D                    # Disable optional agents
    $(basename "$0") -r                    # Show rendering optimizations
    $(basename "$0") -R                    # Generate report

EOF
}

#-------------------------------------------------------------------------------
# Get temperature helper
#-------------------------------------------------------------------------------
get_temperature() {
    sudo powermetrics --samplers smc -i 1 -n 1 2>/dev/null | \
        grep -E "CPU die temperature" | \
        grep -oE '[0-9]+\.[0-9]+' | head -1
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    local action=""
    local agent_name=""
    
    init
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--list-agents)
                action="list"
                shift
                ;;
            -d|--disable)
                action="disable"
                agent_name="$2"
                shift 2
                ;;
            -e|--enable)
                action="enable"
                agent_name="$2"
                shift 2
                ;;
            -D|--disable-optional)
                action="disable_optional"
                shift
                ;;
            -s|--spotlight)
                action="spotlight"
                shift
                ;;
            -t|--timemachine)
                action="timemachine"
                shift
                ;;
            -k|--kill-bg)
                action="kill_bg"
                shift
                ;;
            -m|--memory)
                action="memory"
                shift
                ;;
            -r|--rendering)
                action="rendering"
                shift
                ;;
            -M|--ml)
                action="ml"
                shift
                ;;
            -v|--vms)
                action="vms"
                shift
                ;;
            -R|--report)
                action="report"
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
    
    case "${action}" in
        list)
            list_launch_agents
            ;;
        disable)
            disable_agent "${agent_name}"
            ;;
        enable)
            enable_agent "${agent_name}"
            ;;
        disable_optional)
            disable_optional_agents
            ;;
        spotlight)
            optimize_spotlight
            ;;
        timemachine)
            optimize_time_machine
            ;;
        kill_bg)
            kill_background_processes
            ;;
        memory)
            optimize_memory
            ;;
        rendering)
            optimize_for_rendering
            ;;
        ml)
            optimize_for_ml
            ;;
        vms)
            optimize_for_vms
            ;;
        report)
            generate_report
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"

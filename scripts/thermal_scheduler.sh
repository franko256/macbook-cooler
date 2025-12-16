#!/bin/bash
#===============================================================================
# THERMAL-AWARE TASK SCHEDULER FOR MACBOOK PRO (M3/M4 MAX)
# Schedules heavy computational tasks during cooler periods
# 
# Author: Manus AI
# Version: 1.0.0
# Compatibility: macOS 14+ (Sonoma/Sequoia) with Apple Silicon
#===============================================================================

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="${HOME}/Library/Logs/ThermalMonitor"
readonly LOG_FILE="${LOG_DIR}/scheduler_$(date +%Y%m%d).log"
readonly QUEUE_FILE="${LOG_DIR}/.task_queue"
readonly HISTORY_FILE="${LOG_DIR}/.task_history"

# Temperature thresholds
MAX_TEMP_FOR_HEAVY_TASKS=70  # Don't start heavy tasks above this temperature
IDEAL_TEMP=55                 # Ideal temperature for heavy tasks
COOLDOWN_WAIT=300            # Seconds to wait for cooldown before retrying

# Time-based scheduling (24-hour format)
PREFERRED_START_HOUR=22      # Prefer starting heavy tasks after 10 PM
PREFERRED_END_HOUR=6         # Until 6 AM

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
    touch "${QUEUE_FILE}"
    touch "${HISTORY_FILE}"
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
# Check if current time is in preferred window
#-------------------------------------------------------------------------------
is_preferred_time() {
    local current_hour
    current_hour=$(date +%H)
    
    if (( PREFERRED_START_HOUR > PREFERRED_END_HOUR )); then
        # Window spans midnight (e.g., 22:00 - 06:00)
        if (( current_hour >= PREFERRED_START_HOUR || current_hour < PREFERRED_END_HOUR )); then
            return 0
        fi
    else
        # Window within same day
        if (( current_hour >= PREFERRED_START_HOUR && current_hour < PREFERRED_END_HOUR )); then
            return 0
        fi
    fi
    return 1
}

#-------------------------------------------------------------------------------
# Check if conditions are good for heavy tasks
#-------------------------------------------------------------------------------
check_conditions() {
    local temp
    local temp_int
    
    temp=$(get_temperature)
    temp_int=${temp%.*}
    
    log_message "INFO" "Current temperature: ${temp}°C"
    
    # Check temperature
    if (( temp_int > MAX_TEMP_FOR_HEAVY_TASKS )); then
        log_message "WARN" "Temperature too high for heavy tasks (${temp}°C > ${MAX_TEMP_FOR_HEAVY_TASKS}°C)"
        return 1
    fi
    
    # Check if ideal conditions
    if (( temp_int <= IDEAL_TEMP )) && is_preferred_time; then
        log_message "INFO" "Ideal conditions: temperature ${temp}°C, preferred time window"
        return 0
    fi
    
    # Acceptable but not ideal
    if (( temp_int <= MAX_TEMP_FOR_HEAVY_TASKS )); then
        log_message "INFO" "Acceptable conditions: temperature ${temp}°C"
        return 0
    fi
    
    return 1
}

#-------------------------------------------------------------------------------
# Add task to queue
#-------------------------------------------------------------------------------
add_task() {
    local task_name=$1
    local command=$2
    local priority=${3:-5}  # 1-10, lower = higher priority
    local task_id
    
    task_id=$(date +%s%N | md5sum | head -c 8)
    
    # Store task in queue file (JSON-like format)
    echo "${task_id}|${priority}|${task_name}|${command}|pending|$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${QUEUE_FILE}"
    
    log_message "INFO" "Task added to queue: ${task_name} (ID: ${task_id}, Priority: ${priority})"
    echo "${task_id}"
}

#-------------------------------------------------------------------------------
# List queued tasks
#-------------------------------------------------------------------------------
list_tasks() {
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           SCHEDULED TASKS                                    ║"
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    printf "║ %-8s %-4s %-20s %-10s %-20s ║\n" "ID" "PRI" "NAME" "STATUS" "ADDED"
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    
    if [[ ! -s "${QUEUE_FILE}" ]]; then
        echo "║                           No tasks in queue                                  ║"
    else
        while IFS='|' read -r id priority name command status added; do
            printf "║ %-8s %-4s %-20s %-10s %-20s ║\n" \
                "${id}" "${priority}" "${name:0:20}" "${status}" "${added:0:20}"
        done < "${QUEUE_FILE}"
    fi
    
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
}

#-------------------------------------------------------------------------------
# Remove task from queue
#-------------------------------------------------------------------------------
remove_task() {
    local task_id=$1
    
    if grep -q "^${task_id}|" "${QUEUE_FILE}"; then
        sed -i '' "/^${task_id}|/d" "${QUEUE_FILE}"
        log_message "INFO" "Task ${task_id} removed from queue"
    else
        log_message "WARN" "Task ${task_id} not found in queue"
    fi
}

#-------------------------------------------------------------------------------
# Execute a task
#-------------------------------------------------------------------------------
execute_task() {
    local task_id=$1
    local task_line
    local task_name command status
    
    task_line=$(grep "^${task_id}|" "${QUEUE_FILE}" || echo "")
    
    if [[ -z "${task_line}" ]]; then
        log_message "ERROR" "Task ${task_id} not found"
        return 1
    fi
    
    task_name=$(echo "${task_line}" | cut -d'|' -f3)
    command=$(echo "${task_line}" | cut -d'|' -f4)
    
    log_message "INFO" "Executing task: ${task_name} (${task_id})"
    
    # Update status to running
    sed -i '' "s/^${task_id}|\\([^|]*\\)|\\([^|]*\\)|\\([^|]*\\)|pending/\
${task_id}|\\1|\\2|\\3|running/" "${QUEUE_FILE}"
    
    # Execute the command
    local start_time end_time duration exit_code
    start_time=$(date +%s)
    
    if eval "${command}"; then
        exit_code=0
        log_message "INFO" "Task ${task_name} completed successfully"
    else
        exit_code=$?
        log_message "ERROR" "Task ${task_name} failed with exit code ${exit_code}"
    fi
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # Move to history
    echo "${task_id}|${task_name}|${exit_code}|${duration}|$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${HISTORY_FILE}"
    
    # Remove from queue
    sed -i '' "/^${task_id}|/d" "${QUEUE_FILE}"
    
    return ${exit_code}
}

#-------------------------------------------------------------------------------
# Process queue - execute pending tasks when conditions are good
#-------------------------------------------------------------------------------
process_queue() {
    log_message "INFO" "Processing task queue..."
    
    if [[ ! -s "${QUEUE_FILE}" ]]; then
        log_message "INFO" "No tasks in queue"
        return 0
    fi
    
    # Check conditions
    if ! check_conditions; then
        log_message "WARN" "Conditions not suitable for heavy tasks"
        return 1
    fi
    
    # Get highest priority pending task
    local task_line
    task_line=$(grep "|pending|" "${QUEUE_FILE}" | sort -t'|' -k2 -n | head -1 || echo "")
    
    if [[ -z "${task_line}" ]]; then
        log_message "INFO" "No pending tasks"
        return 0
    fi
    
    local task_id
    task_id=$(echo "${task_line}" | cut -d'|' -f1)
    
    execute_task "${task_id}"
}

#-------------------------------------------------------------------------------
# Wait for good conditions and then execute
#-------------------------------------------------------------------------------
wait_and_execute() {
    local task_id=$1
    local max_wait=${2:-86400}  # Default: wait up to 24 hours
    local waited=0
    
    log_message "INFO" "Waiting for good conditions to execute task ${task_id}..."
    
    while (( waited < max_wait )); do
        if check_conditions; then
            execute_task "${task_id}"
            return $?
        fi
        
        log_message "INFO" "Conditions not suitable, waiting ${COOLDOWN_WAIT}s..."
        sleep "${COOLDOWN_WAIT}"
        waited=$((waited + COOLDOWN_WAIT))
    done
    
    log_message "ERROR" "Timeout waiting for good conditions"
    return 1
}

#-------------------------------------------------------------------------------
# Schedule a command to run when cool
#-------------------------------------------------------------------------------
schedule_when_cool() {
    local task_name=$1
    local command=$2
    local wait_mode=${3:-false}
    
    local task_id
    task_id=$(add_task "${task_name}" "${command}" 5)
    
    if [[ "${wait_mode}" == "true" ]]; then
        wait_and_execute "${task_id}"
    else
        log_message "INFO" "Task ${task_id} queued. Run 'process_queue' to execute when conditions are good."
    fi
}

#-------------------------------------------------------------------------------
# Daemon mode - continuously process queue
#-------------------------------------------------------------------------------
daemon_mode() {
    local check_interval=${1:-300}  # Check every 5 minutes by default
    
    log_message "INFO" "Starting scheduler daemon (interval: ${check_interval}s)"
    
    while true; do
        process_queue
        sleep "${check_interval}"
    done
}

#-------------------------------------------------------------------------------
# Show task history
#-------------------------------------------------------------------------------
show_history() {
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           TASK HISTORY                                       ║"
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    printf "║ %-8s %-25s %-6s %-10s %-20s ║\n" "ID" "NAME" "EXIT" "DURATION" "COMPLETED"
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    
    if [[ ! -s "${HISTORY_FILE}" ]]; then
        echo "║                           No task history                                    ║"
    else
        tail -20 "${HISTORY_FILE}" | while IFS='|' read -r id name exit_code duration completed; do
            printf "║ %-8s %-25s %-6s %-10s %-20s ║\n" \
                "${id}" "${name:0:25}" "${exit_code}" "${duration}s" "${completed:0:20}"
        done
    fi
    
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
}

#-------------------------------------------------------------------------------
# Create launchd plist for automatic scheduling
#-------------------------------------------------------------------------------
create_launchd_plist() {
    local plist_path="${HOME}/Library/LaunchAgents/com.thermal.scheduler.plist"
    
    cat > "${plist_path}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.thermal.scheduler</string>
    <key>ProgramArguments</key>
    <array>
        <string>${SCRIPT_DIR}/thermal_scheduler.sh</string>
        <string>--process</string>
    </array>
    <key>StartCalendarInterval</key>
    <array>
        <!-- Run at 10 PM, 2 AM, and 6 AM -->
        <dict>
            <key>Hour</key>
            <integer>22</integer>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
        <dict>
            <key>Hour</key>
            <integer>2</integer>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
        <dict>
            <key>Hour</key>
            <integer>6</integer>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
    </array>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/scheduler_launchd.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/scheduler_launchd_error.log</string>
</dict>
</plist>
EOF

    log_message "INFO" "Created launchd plist at ${plist_path}"
    echo "To enable: launchctl load ${plist_path}"
    echo "To disable: launchctl unload ${plist_path}"
}

#-------------------------------------------------------------------------------
# Usage
#-------------------------------------------------------------------------------
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Thermal-Aware Task Scheduler for MacBook Pro M3/M4 Max

OPTIONS:
    -a, --add NAME CMD      Add task to queue
    -l, --list              List queued tasks
    -r, --remove ID         Remove task from queue
    -p, --process           Process queue (execute pending tasks)
    -w, --wait ID           Wait for good conditions and execute task
    -d, --daemon            Run as daemon (continuous processing)
    -H, --history           Show task history
    -c, --check             Check current conditions
    -s, --schedule CMD      Schedule command to run when cool
    --create-launchd        Create launchd plist for automatic scheduling
    -h, --help              Show this help message

EXAMPLES:
    # Add a video rendering task
    $(basename "$0") -a "Render Video" "ffmpeg -i input.mp4 -c:v hevc output.mp4"
    
    # Add ML training task with high priority
    $(basename "$0") -a "Train Model" "python train.py" --priority 1
    
    # Process queue when conditions are good
    sudo $(basename "$0") -p
    
    # Run as daemon
    sudo $(basename "$0") -d
    
    # Schedule and wait for execution
    sudo $(basename "$0") -s "Heavy Task" "make build" --wait

CONFIGURATION:
    MAX_TEMP_FOR_HEAVY_TASKS: ${MAX_TEMP_FOR_HEAVY_TASKS}°C
    IDEAL_TEMP: ${IDEAL_TEMP}°C
    PREFERRED_HOURS: ${PREFERRED_START_HOUR}:00 - ${PREFERRED_END_HOUR}:00

EOF
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    local action=""
    local task_name=""
    local command=""
    local task_id=""
    local priority=5
    local wait_mode=false
    
    init
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--add)
                action="add"
                task_name="$2"
                command="$3"
                shift 3
                ;;
            --priority)
                priority="$2"
                shift 2
                ;;
            -l|--list)
                action="list"
                shift
                ;;
            -r|--remove)
                action="remove"
                task_id="$2"
                shift 2
                ;;
            -p|--process)
                action="process"
                shift
                ;;
            -w|--wait)
                action="wait"
                task_id="$2"
                shift 2
                ;;
            -d|--daemon)
                action="daemon"
                shift
                ;;
            -H|--history)
                action="history"
                shift
                ;;
            -c|--check)
                action="check"
                shift
                ;;
            -s|--schedule)
                action="schedule"
                task_name="$2"
                command="$3"
                shift 3
                ;;
            --wait-mode)
                wait_mode=true
                shift
                ;;
            --create-launchd)
                action="create_launchd"
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
        add)
            add_task "${task_name}" "${command}" "${priority}"
            ;;
        list)
            list_tasks
            ;;
        remove)
            remove_task "${task_id}"
            ;;
        process)
            process_queue
            ;;
        wait)
            wait_and_execute "${task_id}"
            ;;
        daemon)
            daemon_mode
            ;;
        history)
            show_history
            ;;
        check)
            if check_conditions; then
                echo -e "${GREEN}Conditions are good for heavy tasks${NC}"
            else
                echo -e "${YELLOW}Conditions not ideal for heavy tasks${NC}"
            fi
            ;;
        schedule)
            schedule_when_cool "${task_name}" "${command}" "${wait_mode}"
            ;;
        create_launchd)
            create_launchd_plist
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"

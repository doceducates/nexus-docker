#!/bin/bash

# Common functions and utilities for Nexus CLI Docker scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" >&2
}

log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" >&2
    fi
}

# Validation functions
validate_number() {
    local value="$1"
    local name="$2"
    
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        log_error "$name must be a valid positive number: $value"
        return 1
    fi
    return 0
}

validate_non_empty() {
    local value="$1"
    local name="$2"
    
    if [ -z "$value" ]; then
        log_error "$name cannot be empty"
        return 1
    fi
    return 0
}

# System information
get_system_info() {
    log_info "System Information:"
    log_info "  OS: $(uname -s) $(uname -r)"
    log_info "  Architecture: $(uname -m)"
    log_info "  CPU cores: $(nproc)"
    log_info "  Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    log_info "  Disk space: $(df -h / | awk 'NR==2 {print $4 " available"}')"
}

# Docker environment validation
validate_docker_env() {
    log_debug "Validating Docker environment"
    
    # Check if running in container
    if [ ! -f /.dockerenv ]; then
        log_warn "Not running in a Docker container"
    fi
    
    # Check required environment variables
    local required_vars=("NEXUS_CLI_PATH" "CONFIG_DIR" "LOG_DIR")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "Required environment variable $var is not set"
            return 1
        fi
    done
    
    # Check if Nexus CLI binary exists and is executable
    if [ ! -x "$NEXUS_CLI_PATH" ]; then
        log_error "Nexus CLI binary not found or not executable: $NEXUS_CLI_PATH"
        return 1
    fi
    
    return 0
}

# Process management
is_process_running() {
    local pid="$1"
    kill -0 "$pid" 2>/dev/null
}

wait_for_process() {
    local pid="$1"
    local timeout="${2:-30}"
    local count=0
    
    while is_process_running "$pid" && [ $count -lt $timeout ]; do
        sleep 1
        ((count++))
    done
    
    if is_process_running "$pid"; then
        return 1  # Timeout
    else
        return 0  # Process stopped
    fi
}

# File operations
ensure_directory() {
    local dir="$1"
    local permissions="${2:-755}"
    
    if [ ! -d "$dir" ]; then
        log_debug "Creating directory: $dir"
        mkdir -p "$dir"
        chmod "$permissions" "$dir"
    fi
}

rotate_log_file() {
    local log_file="$1"
    local max_size="${2:-100M}"
    
    if [ -f "$log_file" ]; then
        local size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0)
        local max_bytes
        
        case "${max_size}" in
            *K|*k) max_bytes=$((${max_size%[Kk]} * 1024)) ;;
            *M|*m) max_bytes=$((${max_size%[Mm]} * 1024 * 1024)) ;;
            *G|*g) max_bytes=$((${max_size%[Gg]} * 1024 * 1024 * 1024)) ;;
            *) max_bytes="$max_size" ;;
        esac
        
        if [ "$size" -gt "$max_bytes" ]; then
            log_info "Rotating log file: $log_file"
            mv "$log_file" "${log_file}.old"
            touch "$log_file"
        fi
    fi
}

# Configuration helpers
create_nexus_config() {
    local config_dir="$1"
    local node_id="$2"
    
    ensure_directory "$config_dir"
    
    cat > "$config_dir/config.json" << EOF
{
   "node_id": "$node_id",
   "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
   "version": "docker-deployment"
}
EOF
    
    log_debug "Created Nexus config for node $node_id in $config_dir"
}

# Health check functions
check_nexus_health() {
    local pid="$1"
    local node_id="$2"
    
    if ! is_process_running "$pid"; then
        log_error "Nexus CLI process (PID: $pid, Node: $node_id) is not running"
        return 1
    fi
    
    # Additional health checks can be added here
    # For example, checking if the process is responding to signals
    # or monitoring resource usage
    
    return 0
}

# Cleanup functions
cleanup_instance_data() {
    local instance_dir="$1"
    local keep_logs="${2:-true}"
    
    if [ -d "$instance_dir" ]; then
        log_info "Cleaning up instance directory: $instance_dir"
        
        if [ "$keep_logs" = "false" ]; then
            rm -rf "$instance_dir"
        else
            # Keep logs but remove other data
            find "$instance_dir" -type f ! -name "*.log" -delete 2>/dev/null || true
        fi
    fi
}

# Signal handling helpers
setup_signal_handlers() {
    local cleanup_function="$1"
    
    trap "$cleanup_function" TERM INT HUP
    log_debug "Signal handlers set up for graceful shutdown"
}

# Version and build information
show_version_info() {
    log_info "Nexus CLI Docker Deployment"
    log_info "Build: ${BUILD_VERSION:-unknown}"
    log_info "Date: ${BUILD_DATE:-unknown}"
    
    if [ -x "$NEXUS_CLI_PATH" ]; then
        log_info "Nexus CLI version:"
        "$NEXUS_CLI_PATH" --version 2>/dev/null | sed 's/^/  /' || log_warn "Could not get Nexus CLI version"
    fi
}

# Initialize common environment
init_common_env() {
    log_debug "Initializing common environment"
    
    # Set default values if not provided
    export CONFIG_DIR="${CONFIG_DIR:-/app/data}"
    export LOG_DIR="${LOG_DIR:-/app/logs}"
    export NEXUS_CLI_PATH="${NEXUS_CLI_PATH:-/app/nexus-cli}"
    
    # Validate environment
    validate_docker_env || exit 1
    
    # Create required directories
    ensure_directory "$CONFIG_DIR"
    ensure_directory "$LOG_DIR"
    
    # Show version information in debug mode
    if [ "${DEBUG:-false}" = "true" ]; then
        get_system_info
        show_version_info
    fi
}

# Call initialization if this script is sourced
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    init_common_env
fi

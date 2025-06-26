#!/bin/bash

# Single instance startup script for Nexus CLI
set -e

# Source common functions
source "$(dirname "$0")/common.sh"

log_info "Starting Nexus CLI - Single Instance Mode"

# Validate environment
validate_node_id() {
    if [ -z "$NODE_ID" ]; then
        log_error "NODE_ID environment variable is required"
        log_info "Usage: docker run -e NODE_ID=your_node_id nexus-docker"
        exit 1
    fi
    
    if ! [[ "$NODE_ID" =~ ^[0-9]+$ ]]; then
        log_error "NODE_ID must be a valid number"
        exit 1
    fi
}

# Setup configuration
setup_config() {
    local config_dir="$HOME/.nexus"
    mkdir -p "$config_dir"
    
    # Create config.json with the provided NODE_ID
    cat > "$config_dir/config.json" << EOF
{
   "node_id": "$NODE_ID"
}
EOF
    
    log_info "Configuration created for Node ID: $NODE_ID"
}

# Build CLI arguments
build_args() {
    local args="start --headless --node-id $NODE_ID"
    
    if [ -n "$MAX_THREADS" ]; then
        if [[ "$MAX_THREADS" =~ ^[0-9]+$ ]] && [ "$MAX_THREADS" -gt 0 ]; then
            args="$args --max-threads $MAX_THREADS"
            log_info "Using $MAX_THREADS threads"
        else
            log_warn "Invalid MAX_THREADS value: $MAX_THREADS. Using default."
        fi
    fi
    
    echo "$args"
}

# Signal handlers for graceful shutdown
cleanup() {
    log_info "Received shutdown signal. Stopping Nexus CLI..."
    if [ -n "$CLI_PID" ]; then
        kill -TERM "$CLI_PID" 2>/dev/null || true
        wait "$CLI_PID" 2>/dev/null || true
    fi
    log_info "Shutdown complete"
    exit 0
}

trap cleanup TERM INT

# Main execution
main() {
    validate_node_id
    setup_config
    
    local args
    args=$(build_args)
    
    log_info "Starting Nexus CLI with arguments: $args"
    log_info "Logs will be written to: $LOG_DIR/nexus-$NODE_ID.log"
    
    # Ensure log directory exists
    mkdir -p "$LOG_DIR"
    
    # Start the CLI and capture PID
    $NEXUS_CLI_PATH $args 2>&1 | tee "$LOG_DIR/nexus-$NODE_ID.log" &
    CLI_PID=$!
    
    log_info "Nexus CLI started with PID: $CLI_PID"
    
    # Wait for the process
    wait "$CLI_PID"
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_info "Nexus CLI exited normally"
    else
        log_error "Nexus CLI exited with code: $exit_code"
    fi
    
    exit $exit_code
}

# Run main function
main "$@"

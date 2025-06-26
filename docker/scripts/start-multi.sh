#!/bin/bash

# Multi-instance startup script for Nexus CLI
set -e

# Source common functions
source "$(dirname "$0")/common.sh"

log_info "Starting Nexus CLI - Multi-Instance Mode"

# Global variables
declare -a PIDS=()
declare -a NODE_ARRAY=()

# Validate environment
validate_node_ids() {
    if [ -z "$NODE_IDS" ]; then
        log_error "NODE_IDS environment variable is required"
        log_info "Usage: docker run -e NODE_IDS='node1,node2,node3' nexus-docker"
        log_info "Example: docker run -e NODE_IDS='123456,789012,345678' nexus-docker"
        exit 1
    fi
    
    # Parse comma-separated NODE_IDS
    IFS=',' read -ra NODE_ARRAY <<< "$NODE_IDS"
    
    if [ ${#NODE_ARRAY[@]} -eq 0 ]; then
        log_error "No valid node IDs found in NODE_IDS"
        exit 1
    fi
    
    # Validate each node ID
    for node_id in "${NODE_ARRAY[@]}"; do
        node_id=$(echo "$node_id" | xargs)  # Trim whitespace
        if [ -n "$node_id" ] && ! [[ "$node_id" =~ ^[0-9]+$ ]]; then
            log_error "Invalid node ID format: $node_id (must be numeric)"
            exit 1
        fi
    done
    
    log_info "Found ${#NODE_ARRAY[@]} node IDs: ${NODE_ARRAY[*]}"
}

# Calculate thread allocation
calculate_threads() {
    local total_instances=${#NODE_ARRAY[@]}
    
    if [ -n "$MAX_THREADS" ] && [[ "$MAX_THREADS" =~ ^[0-9]+$ ]] && [ "$MAX_THREADS" -gt 0 ]; then
        THREADS_PER_INSTANCE=$((MAX_THREADS / total_instances))
        if [ $THREADS_PER_INSTANCE -lt 1 ]; then
            THREADS_PER_INSTANCE=1
            log_warn "MAX_THREADS too low for $total_instances instances. Using 1 thread per instance."
        else
            log_info "Allocating $THREADS_PER_INSTANCE threads per instance (total: $MAX_THREADS)"
        fi
    else
        THREADS_PER_INSTANCE=""
        log_info "Using default thread allocation per instance"
    fi
}

# Start a single instance
start_instance() {
    local node_id=$1
    local instance_num=$2
    
    log_info "Starting instance $instance_num with Node ID: $node_id"
    
    # Create separate directories for this instance
    local instance_dir="$CONFIG_DIR/instance_$instance_num"
    local instance_home="$instance_dir/home"
    local nexus_config_dir="$instance_home/.nexus"
    
    mkdir -p "$nexus_config_dir"
    mkdir -p "$LOG_DIR"
    
    # Create config.json for this instance
    cat > "$nexus_config_dir/config.json" << EOF
{
   "node_id": "$node_id"
}
EOF
    
    # Build arguments for this instance
    local args="start --headless --node-id $node_id"
    if [ -n "$THREADS_PER_INSTANCE" ]; then
        args="$args --max-threads $THREADS_PER_INSTANCE"
    fi
    
    local log_file="$LOG_DIR/nexus-instance-$instance_num-$node_id.log"
    
    # Start the instance in background
    (
        export HOME="$instance_home"
        log_info "Instance $instance_num starting with args: $args"
        log_info "Instance $instance_num home: $HOME"
        log_info "Instance $instance_num log: $log_file"
        
        # Start with proper logging
        $NEXUS_CLI_PATH $args 2>&1 | while IFS= read -r line; do
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Instance-$instance_num:$node_id] $line"
        done | tee "$log_file"
    ) &
    
    local pid=$!
    PIDS+=($pid)
    
    log_info "Instance $instance_num (Node: $node_id) started with PID: $pid"
    
    # Small delay between starts to avoid resource contention
    sleep 2
}

# Signal handlers for graceful shutdown
cleanup() {
    log_info "Received shutdown signal. Stopping all instances..."
    
    # Send TERM signal to all child processes
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Stopping instance with PID: $pid"
            kill -TERM "$pid" 2>/dev/null || true
        fi
    done
    
    # Wait for all processes to exit
    for pid in "${PIDS[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
    
    log_info "All instances stopped. Shutdown complete."
    exit 0
}

trap cleanup TERM INT

# Monitor instances
monitor_instances() {
    while true; do
        local running_count=0
        local failed_pids=()
        
        for i in "${!PIDS[@]}"; do
            local pid=${PIDS[$i]}
            if kill -0 "$pid" 2>/dev/null; then
                ((running_count++))
            else
                failed_pids+=($i)
                log_warn "Instance with PID $pid has stopped"
            fi
        done
        
        # If any instances failed, log the failure
        if [ ${#failed_pids[@]} -gt 0 ]; then
            log_error "${#failed_pids[@]} instance(s) have failed"
            # Optionally restart failed instances here
        fi
        
        # If all instances have stopped, exit
        if [ $running_count -eq 0 ]; then
            log_error "All instances have stopped"
            exit 1
        fi
        
        # Check every 30 seconds
        sleep 30
    done
}

# Main execution
main() {
    validate_node_ids
    calculate_threads
    
    log_info "Starting ${#NODE_ARRAY[@]} Nexus CLI instances"
    
    # Ensure directories exist
    mkdir -p "$CONFIG_DIR" "$LOG_DIR"
    
    # Start all instances
    local instance_num=1
    for node_id in "${NODE_ARRAY[@]}"; do
        # Trim whitespace
        node_id=$(echo "$node_id" | xargs)
        
        if [ -n "$node_id" ]; then
            start_instance "$node_id" "$instance_num"
            instance_num=$((instance_num + 1))
        fi
    done
    
    log_info "All ${#PIDS[@]} instances started successfully"
    log_info "Monitoring instances... (Ctrl+C to stop all)"
    
    # Monitor in background and wait for all processes
    monitor_instances &
    MONITOR_PID=$!
    
    # Wait for all instance processes
    for pid in "${PIDS[@]}"; do
        wait "$pid"
    done
    
    # Stop monitoring
    kill "$MONITOR_PID" 2>/dev/null || true
    
    log_info "All instances have completed"
}

# Run main function
main "$@"

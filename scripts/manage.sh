#!/bin/bash

# Nexus CLI Docker Management Script
# This script provides easy management of Nexus CLI Docker deployments

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_DIR="$PROJECT_ROOT/compose"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Helper functions
check_env_file() {
    local env_file="$PROJECT_ROOT/.env"
    if [ ! -f "$env_file" ]; then
        log_warn ".env file not found. Creating from template..."
        if [ -f "$PROJECT_ROOT/.env.example" ]; then
            cp "$PROJECT_ROOT/.env.example" "$env_file"
            log_info "Please edit .env file with your node IDs and configuration"
            return 1
        else
            log_error ".env.example not found. Please create .env file manually."
            return 1
        fi
    fi
    return 0
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        return 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed or not in PATH"
        return 1
    fi
    
    return 0
}

get_compose_cmd() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        echo "docker compose"
    fi
}

run_compose() {
    local cmd="$1"
    shift
    local compose_cmd
    compose_cmd=$(get_compose_cmd)
    
    cd "$COMPOSE_DIR"
    log_debug "Running: $compose_cmd $cmd $*"
    $compose_cmd $cmd "$@"
}

# Build functions
build() {
    log_info "Building Nexus CLI Docker image..."
    check_docker || exit 1
    
    run_compose build "$@"
    log_info "Build completed successfully!"
}

build_no_cache() {
    log_info "Building Nexus CLI Docker image (no cache)..."
    check_docker || exit 1
    
    run_compose build --no-cache "$@"
    log_info "Build completed successfully!"
}

# Start functions
start_single() {
    check_env_file || exit 1
    check_docker || exit 1
    
    log_info "Starting single instance container..."
    run_compose up -d node-1
    log_info "Single instance container started!"
    show_status
}

start_all_single() {
    check_env_file || exit 1
    check_docker || exit 1
    
    log_info "Starting all single instance containers..."
    run_compose --profile multi-single up -d
    log_info "All single instance containers started!"
    show_status
}

start_multi() {
    check_env_file || exit 1
    check_docker || exit 1
    
    log_info "Starting multi-instance container..."
    run_compose --profile multi up -d
    log_info "Multi-instance container started!"
    show_status
}

start_dev() {
    check_env_file || exit 1
    check_docker || exit 1
    
    log_info "Starting development environment..."
    run_compose -f docker-compose.yml -f docker-compose.dev.yml up -d node-1
    log_info "Development environment started!"
    show_status
}

start_prod() {
    check_env_file || exit 1
    check_docker || exit 1
    
    log_info "Starting production environment..."
    run_compose -f docker-compose.yml -f docker-compose.prod.yml --profile multi-single up -d
    log_info "Production environment started!"
    show_status
}

# Web manager functions
start_manager() {
    check_env_file || exit 1
    check_docker || exit 1
    
    log_info "Starting web management UI..."
    run_compose --profile manager up -d web-manager
    log_info "Web management UI started!"
    log_info "Access the web interface at: http://localhost:${WEB_MANAGER_PORT:-3000}"
    show_status
}

start_single_with_manager() {
    check_env_file || exit 1
    check_docker || exit 1
    
    log_info "Starting single instance with web management UI..."
    run_compose --profile manager up -d node-1 web-manager
    log_info "Single instance and web management UI started!"
    log_info "Access the web interface at: http://localhost:${WEB_MANAGER_PORT:-3000}"
    show_status
}

start_multi_with_manager() {
    check_env_file || exit 1
    check_docker || exit 1
    
    log_info "Starting multi-instance with web management UI..."
    run_compose --profile multi --profile manager up -d
    log_info "Multi-instance and web management UI started!"
    log_info "Access the web interface at: http://localhost:${WEB_MANAGER_PORT:-3000}"
    show_status
}

# Stop functions
stop() {
    check_docker || exit 1
    
    log_info "Stopping all Nexus CLI containers..."
    run_compose down
    run_compose --profile multi down
    run_compose --profile multi-single down
    log_info "All containers stopped!"
}

stop_service() {
    local service="$1"
    if [ -z "$service" ]; then
        log_error "Service name required"
        return 1
    fi
    
    check_docker || exit 1
    log_info "Stopping service: $service"
    run_compose stop "$service"
}

# Restart functions
restart() {
    log_info "Restarting all containers..."
    stop
    sleep 2
    start_single
}

restart_service() {
    local service="$1"
    if [ -z "$service" ]; then
        log_error "Service name required"
        return 1
    fi
    
    check_docker || exit 1
    log_info "Restarting service: $service"
    run_compose restart "$service"
}

# Status and monitoring
show_status() {
    check_docker || exit 1
    
    log_info "Container status:"
    run_compose ps -a
    
    echo ""
    log_info "Resource usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" $(docker ps --filter "name=nexus-" --format "{{.Names}}" 2>/dev/null) 2>/dev/null || log_warn "No running containers found"
}

show_logs() {
    local service="$1"
    local follow="${2:-false}"
    
    check_docker || exit 1
    
    if [ -n "$service" ]; then
        log_info "Showing logs for $service..."
        if [ "$follow" = "true" ]; then
            run_compose logs -f "$service"
        else
            run_compose logs --tail=100 "$service"
        fi
    else
        log_info "Showing logs for all containers..."
        if [ "$follow" = "true" ]; then
            run_compose logs -f
        else
            run_compose logs --tail=100
        fi
    fi
}

show_stats() {
    check_docker || exit 1
    
    log_info "Real-time container statistics (Press Ctrl+C to exit):"
    docker stats $(docker ps --filter "name=nexus-" --format "{{.Names}}" 2>/dev/null) 2>/dev/null || log_warn "No running containers found"
}

# Health checks
health_check() {
    local service="$1"
    
    check_docker || exit 1
    
    if [ -n "$service" ]; then
        log_info "Health check for $service:"
        docker inspect --format='{{.State.Health.Status}}' "nexus-$service" 2>/dev/null || log_error "Container nexus-$service not found"
    else
        log_info "Health check for all containers:"
        for container in $(docker ps --filter "name=nexus-" --format "{{.Names}}" 2>/dev/null); do
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
            echo "  $container: $health"
        done
    fi
}

# Update functions
update() {
    log_info "Updating Nexus CLI containers..."
    
    # Stop current containers
    stop
    
    # Rebuild images
    build_no_cache
    
    # Start containers
    start_single
    
    log_info "Update completed!"
}

pull_latest() {
    log_info "Pulling latest base images..."
    check_docker || exit 1
    
    # Pull latest base images
    docker pull debian:12-slim
    
    log_info "Latest images pulled. Run 'build' to rebuild with latest images."
}

# Cleanup functions
clean() {
    log_warn "This will remove all containers, images, and volumes. Are you sure? (y/N)"
    read -r response
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        log_info "Cleaning up..."
        
        # Stop and remove containers
        stop
        
        # Remove volumes
        run_compose down -v
        run_compose --profile multi down -v
        run_compose --profile multi-single down -v
        
        # Remove images
        docker rmi $(docker images --filter "reference=*nexus*" -q) 2>/dev/null || true
        
        # System cleanup
        docker system prune -f
        
        log_info "Cleanup completed!"
    else
        log_info "Cleanup cancelled."
    fi
}

clean_logs() {
    log_info "Cleaning up log files..."
    
    # Clean Docker logs
    docker system prune --volumes -f
    
    # Clean local log volumes if they exist
    docker volume ls --filter "name=nexus" -q | xargs -r docker volume rm
    
    log_info "Log cleanup completed!"
}

# Scaling functions
scale() {
    local service="$1"
    local count="${2:-1}"
    
    if [ -z "$service" ]; then
        log_error "Usage: $0 scale <service> [count]"
        return 1
    fi
    
    check_docker || exit 1
    log_info "Scaling $service to $count instances..."
    run_compose up -d --scale "$service=$count"
}

# Quick operations
quick_start() {
    local node_id="$1"
    if [ -z "$node_id" ]; then
        log_error "Usage: $0 quick-start <NODE_ID>"
        return 1
    fi
    
    check_docker || exit 1
    log_info "Quick starting with Node ID: $node_id"
    
    docker run -d \
        --name "nexus-quick-$node_id" \
        -e NODE_ID="$node_id" \
        -e MAX_THREADS=4 \
        --restart unless-stopped \
        nexus-cli:latest || {
        log_error "Failed to start container. Make sure the image is built first."
        return 1
    }
    
    log_info "Container started: nexus-quick-$node_id"
}

# Backup and restore
backup_config() {
    local backup_dir="${1:-./backup-$(date +%Y%m%d-%H%M%S)}"
    
    log_info "Backing up configuration to: $backup_dir"
    mkdir -p "$backup_dir"
    
    # Backup volumes
    for volume in $(docker volume ls --filter "name=nexus" -q); do
        log_info "Backing up volume: $volume"
        docker run --rm -v "$volume:/data" -v "$backup_dir:/backup" busybox tar czf "/backup/$volume.tar.gz" -C /data .
    done
    
    # Backup .env file
    if [ -f "$PROJECT_ROOT/.env" ]; then
        cp "$PROJECT_ROOT/.env" "$backup_dir/"
    fi
    
    log_info "Backup completed: $backup_dir"
}

restore_config() {
    local backup_dir="$1"
    if [ -z "$backup_dir" ] || [ ! -d "$backup_dir" ]; then
        log_error "Usage: $0 restore-config <backup_directory>"
        return 1
    fi
    
    log_warn "This will overwrite existing configuration. Continue? (y/N)"
    read -r response
    if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
        log_info "Restore cancelled."
        return 0
    fi
    
    log_info "Restoring configuration from: $backup_dir"
    
    # Stop containers
    stop
    
    # Restore volumes
    for backup_file in "$backup_dir"/*.tar.gz; do
        if [ -f "$backup_file" ]; then
            local volume_name=$(basename "$backup_file" .tar.gz)
            log_info "Restoring volume: $volume_name"
            docker volume create "$volume_name"
            docker run --rm -v "$volume_name:/data" -v "$backup_dir:/backup" busybox tar xzf "/backup/$volume_name.tar.gz" -C /data
        fi
    done
    
    # Restore .env file
    if [ -f "$backup_dir/.env" ]; then
        cp "$backup_dir/.env" "$PROJECT_ROOT/"
    fi
    
    log_info "Restore completed!"
}

# Configuration helpers
show_config() {
    log_info "Current configuration:"
    if [ -f "$PROJECT_ROOT/.env" ]; then
        echo "Environment variables:"
        cat "$PROJECT_ROOT/.env" | grep -v '^#' | grep -v '^$'
    else
        log_warn "No .env file found"
    fi
    
    echo ""
    log_info "Docker Compose files:"
    ls -la "$COMPOSE_DIR"/*.yml
}

edit_config() {
    local editor="${EDITOR:-nano}"
    if [ -f "$PROJECT_ROOT/.env" ]; then
        "$editor" "$PROJECT_ROOT/.env"
    else
        log_error ".env file not found. Run 'show-config' first."
    fi
}

# Help function
show_help() {
    cat << 'EOF'
Nexus CLI Docker Management Script

Usage: ./manage.sh <command> [options]

BUILD COMMANDS:
  build                 Build the Docker image
  build-no-cache        Build the Docker image without cache
  pull-latest          Pull latest base images

START COMMANDS:
  start-single         Start single instance container
  start-all-single     Start all single instance containers  
  start-multi          Start multi-instance container
  start-dev            Start development environment
  start-prod           Start production environment
  start-manager        Start web management UI only
  start-single-with-manager  Start single instance with web UI
  start-multi-with-manager   Start multi-instance with web UI
  quick-start <id>     Quick start with single node ID

STOP COMMANDS:
  stop                 Stop all containers
  stop <service>       Stop specific service
  restart              Restart all containers
  restart <service>    Restart specific service

MONITORING COMMANDS:
  status               Show container status and resource usage
  logs [service]       Show logs (optionally for specific service)
  logs-follow [svc]    Follow logs in real-time
  stats                Show real-time resource statistics
  health [service]     Show health status

MAINTENANCE COMMANDS:
  update               Update containers to latest version
  clean                Remove all containers, images, and volumes
  clean-logs           Clean up log files
  scale <svc> <count>  Scale service to specific number of instances

CONFIGURATION COMMANDS:
  show-config          Show current configuration
  edit-config          Edit .env configuration file
  backup-config [dir]  Backup configuration and data
  restore-config <dir> Restore from backup

EXAMPLES:
  ./manage.sh build
  ./manage.sh start-single
  ./manage.sh start-multi
  ./manage.sh logs node-1
  ./manage.sh logs-follow multi-node
  ./manage.sh quick-start 123456
  ./manage.sh scale node-1 3
  ./manage.sh backup-config ./my-backup

ENVIRONMENT:
  Edit .env file to configure node IDs, resource limits, and other settings.
  Run 'show-config' to see current configuration.

EOF
}

# Main command processing
case "${1:-help}" in
    build)
        build "${@:2}"
        ;;
    build-no-cache)
        build_no_cache "${@:2}"
        ;;
    pull-latest)
        pull_latest
        ;;
    start-single)
        start_single
        ;;
    start-all-single)
        start_all_single
        ;;
    start-multi)
        start_multi
        ;;
    start-dev)
        start_dev
        ;;
    start-prod)
        start_prod
        ;;
    start-manager)
        start_manager
        ;;
    start-single-with-manager)
        start_single_with_manager
        ;;
    start-multi-with-manager)
        start_multi_with_manager
        ;;
    stop)
        if [ -n "$2" ]; then
            stop_service "$2"
        else
            stop
        fi
        ;;
    restart)
        if [ -n "$2" ]; then
            restart_service "$2"
        else
            restart
        fi
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    logs-follow)
        show_logs "$2" "true"
        ;;
    stats)
        show_stats
        ;;
    health)
        health_check "$2"
        ;;
    update)
        update
        ;;
    clean)
        clean
        ;;
    clean-logs)
        clean_logs
        ;;
    scale)
        scale "$2" "$3"
        ;;
    quick-start)
        quick_start "$2"
        ;;
    backup-config)
        backup_config "$2"
        ;;
    restore-config)
        restore_config "$2"
        ;;
    show-config)
        show_config
        ;;
    edit-config)
        edit_config
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac

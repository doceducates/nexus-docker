#!/bin/bash
# Nexus CLI Manager - Simplified Shell Launcher
# Handles basic operations and delegates complex tasks to Python

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_MANAGER_DIR="$PROJECT_ROOT/web-manager"
SETUP_SCRIPT="$PROJECT_ROOT/setup.py"

# Default values
ACTION="help"
DEBUG=false
PORT=5000
HOST="127.0.0.1"
BUILD=false
UPGRADE=false

# Color functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }

show_header() {
    echo -e "${CYAN}=======================================================${NC}"
    echo -e "${CYAN}          Nexus CLI Manager - Python Edition         ${NC}"
    echo -e "${CYAN}=======================================================${NC}"
    echo -e "Project Root: $PROJECT_ROOT"
    echo ""
}

show_help() {
    echo -e "${YELLOW}Nexus CLI Manager - Simplified Shell Launcher${NC}"
    echo ""
    echo -e "${GREEN}USAGE:${NC}"
    echo "  ./manage.sh <action> [options]"
    echo ""
    echo -e "${GREEN}ACTIONS:${NC}"
    echo "  setup       Run Python setup script (install dependencies, etc.)"
    echo "  standalone  Start web manager in standalone mode"
    echo "  docker      Start web manager in Docker mode"
    echo "  stop        Stop running services"
    echo "  status      Show service status"
    echo "  logs        Show service logs"
    echo "  help        Show this help message"
    echo ""
    echo -e "${GREEN}OPTIONS:${NC}"
    echo "  --debug     Enable debug mode"
    echo "  --port      Port to use (default: 5000)"
    echo "  --host      Host to bind to (default: 127.0.0.1)"
    echo "  --build     Build Docker images during setup"
    echo "  --upgrade   Upgrade dependencies during setup"
    echo ""
    echo -e "${GREEN}EXAMPLES:${NC}"
    echo -e "${CYAN}  ./manage.sh setup                        # Initial setup${NC}"
    echo -e "${CYAN}  ./manage.sh setup --build                # Setup with Docker images${NC}"
    echo -e "${CYAN}  ./manage.sh standalone                   # Run standalone mode${NC}"
    echo -e "${CYAN}  ./manage.sh standalone --debug --port 8080 # Debug mode on port 8080${NC}"
    echo -e "${CYAN}  ./manage.sh docker                       # Run Docker mode${NC}"
}

test_python() {
    if command -v python3 &> /dev/null; then
        local version=$(python3 --version 2>&1)
        print_success "Python available: $version"
        PYTHON_CMD="python3"
        return 0
    elif command -v python &> /dev/null; then
        local version=$(python --version 2>&1)
        print_success "Python available: $version"
        PYTHON_CMD="python"
        return 0
    else
        print_error "Python not found. Please install Python 3.8+ from https://python.org"
        return 1
    fi
}

run_setup() {
    print_info "Running Python setup script..."
    
    local args=()
    if [ "$BUILD" = true ]; then
        args+=(--build-images)
    fi
    if [ "$UPGRADE" = true ]; then
        args+=(--upgrade)
    fi
    
    "$PYTHON_CMD" "$SETUP_SCRIPT" "${args[@]}"
    return $?
}

start_standalone() {
    print_info "Starting standalone web manager..."
    
    local launch_script="$WEB_MANAGER_DIR/launch.py"
    if [ ! -f "$launch_script" ]; then
        print_error "Launch script not found. Run setup first: ./manage.sh setup"
        return 1
    fi
    
    cd "$WEB_MANAGER_DIR"
    
    export DEBUG="$DEBUG"
    
    local args=()
    if [ "$DEBUG" = true ]; then
        args+=(--debug)
    fi
    args+=(--host "$HOST")
    args+=(--port "$PORT")
    
    print_success "Starting web manager..."
    echo "  Mode: $([ "$DEBUG" = true ] && echo "Development" || echo "Production")"
    echo "  URL: http://${HOST}:${PORT}"
    echo ""
    print_warning "Press Ctrl+C to stop the server"
    echo ""
    
    "$PYTHON_CMD" launch.py "${args[@]}"
}

start_docker() {
    print_info "Starting Docker web manager..."
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker"
        return 1
    fi
    
    local docker_version=$(docker --version 2>&1)
    print_success "Docker available: $docker_version"
    
    local compose_file="$PROJECT_ROOT/compose/docker-compose-manager.yml"
    if [ ! -f "$compose_file" ]; then
        print_error "Docker compose file not found: $compose_file"
        return 1
    fi
    
    cd "$PROJECT_ROOT/compose"
    
    print_info "Starting Docker services..."
    docker-compose -f docker-compose-manager.yml up -d web-manager
    
    if [ $? -eq 0 ]; then
        print_success "Docker services started"
        echo ""
        print_info "Web manager available at: http://localhost:5000"
        print_info "View logs: ./manage.sh logs"
        print_info "Stop services: ./manage.sh stop"
        return 0
    else
        print_error "Failed to start Docker services"
        return 1
    fi
}

stop_services() {
    print_info "Stopping services..."
    
    # Try to stop Docker services
    if command -v docker &> /dev/null; then
        cd "$PROJECT_ROOT/compose"
        if docker-compose -f docker-compose-manager.yml down; then
            print_success "Docker services stopped"
        else
            print_warning "Some issues stopping Docker services"
        fi
    else
        print_warning "Docker not available"
    fi
    
    # Try to stop standalone processes
    local python_pids=$(pgrep -f "launch.py" 2>/dev/null || true)
    if [ -n "$python_pids" ]; then
        print_info "Stopping standalone processes..."
        kill $python_pids 2>/dev/null || true
        print_success "Standalone processes stopped"
    fi
}

show_status() {
    print_info "Checking service status..."
    
    # Check Docker services
    if command -v docker &> /dev/null; then
        echo ""
        echo -e "${YELLOW}=== Docker Services ===${NC}"
        cd "$PROJECT_ROOT/compose"
        docker-compose -f docker-compose-manager.yml ps
    else
        print_warning "Docker not available"
    fi
    
    # Check standalone processes
    local python_pids=$(pgrep -f "python.*launch.py" 2>/dev/null || true)
    if [ -n "$python_pids" ]; then
        echo ""
        echo -e "${YELLOW}=== Python Processes ===${NC}"
        ps -p $python_pids -o pid,ppid,pcpu,pmem,comm
    fi
}

show_logs() {
    print_info "Showing logs..."
    
    if command -v docker &> /dev/null; then
        cd "$PROJECT_ROOT/compose"
        docker-compose -f docker-compose-manager.yml logs -f web-manager
    else
        print_warning "Docker not available - no centralized logs for standalone mode"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        setup|standalone|docker|stop|status|logs|help)
            ACTION="$1"
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --build)
            BUILD=true
            shift
            ;;
        --upgrade)
            UPGRADE=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
show_header

# Test Python availability
if ! test_python; then
    exit 1
fi

# Execute action
case "$ACTION" in
    help)
        show_help
        ;;
    setup)
        if ! run_setup; then
            print_error "Setup failed"
            exit 1
        fi
        ;;
    standalone)
        if ! start_standalone; then
            exit 1
        fi
        ;;
    docker)
        if ! start_docker; then
            exit 1
        fi
        ;;
    stop)
        stop_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    *)
        print_error "Unknown action: $ACTION"
        show_help
        exit 1
        ;;
esac

echo ""
print_success "Operation completed!"

#!/bin/bash

# Nexus CLI Docker Setup Script
# This script helps you get started with the Nexus CLI Docker deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

check_prerequisites() {
    log_step "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        missing_tools+=("docker-compose")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Please install the missing tools:"
        echo "  Docker: https://docs.docker.com/get-docker/"
        echo "  Docker Compose: https://docs.docker.com/compose/install/"
        return 1
    fi
    
    log_info "All prerequisites are installed ✓"
    return 0
}

setup_environment() {
    log_step "Setting up environment configuration..."
    
    local env_file="$PROJECT_ROOT/.env"
    
    if [ -f "$env_file" ]; then
        log_warn "Environment file already exists at $env_file"
        echo -n "Do you want to overwrite it? (y/N): "
        read -r response
        if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
            log_info "Keeping existing environment file"
            return 0
        fi
    fi
    
    if [ -f "$PROJECT_ROOT/.env.example" ]; then
        cp "$PROJECT_ROOT/.env.example" "$env_file"
        log_info "Environment file created: $env_file"
    else
        log_error "Template file .env.example not found"
        return 1
    fi
    
    return 0
}

configure_node_ids() {
    log_step "Configuring node IDs..."
    
    local env_file="$PROJECT_ROOT/.env"
    
    echo ""
    echo "You need to provide your Nexus node IDs."
    echo "If you don't have node IDs yet, you can:"
    echo "  1. Register at https://app.nexus.xyz"
    echo "  2. Use the original Nexus CLI to register"
    echo ""
    
    echo -n "Do you want to configure node IDs now? (y/N): "
    read -r configure_now
    
    if [ "$configure_now" = "y" ] || [ "$configure_now" = "Y" ]; then
        echo ""
        echo "Enter your node IDs (press Enter to skip):"
        
        echo -n "Node ID 1: "
        read -r node_id_1
        if [ -n "$node_id_1" ]; then
            sed -i.bak "s/NODE_ID_1=.*/NODE_ID_1=$node_id_1/" "$env_file"
        fi
        
        echo -n "Node ID 2: "
        read -r node_id_2
        if [ -n "$node_id_2" ]; then
            sed -i.bak "s/NODE_ID_2=.*/NODE_ID_2=$node_id_2/" "$env_file"
        fi
        
        echo -n "Node ID 3: "
        read -r node_id_3
        if [ -n "$node_id_3" ]; then
            sed -i.bak "s/NODE_ID_3=.*/NODE_ID_3=$node_id_3/" "$env_file"
        fi
        
        # Configure multi-instance node IDs
        echo ""
        echo "For multi-instance deployment, enter comma-separated node IDs:"
        echo -n "Multi-instance node IDs: "
        read -r multi_node_ids
        if [ -n "$multi_node_ids" ]; then
            sed -i.bak "s/NODE_IDS=.*/NODE_IDS=$multi_node_ids/" "$env_file"
        fi
        
        # Remove backup file
        rm -f "$env_file.bak"
        
        log_info "Node IDs configured successfully"
    else
        log_warn "Node IDs not configured. Edit $env_file manually before deployment."
    fi
}

make_scripts_executable() {
    log_step "Making scripts executable..."
    
    local script_dirs=("$PROJECT_ROOT/scripts" "$PROJECT_ROOT/docker/scripts" "$PROJECT_ROOT/k8s")
    
    for dir in "${script_dirs[@]}"; do
        if [ -d "$dir" ]; then
            find "$dir" -name "*.sh" -exec chmod +x {} \;
            log_info "Made scripts executable in: $dir"
        fi
    done
}

test_setup() {
    log_step "Testing setup..."
    
    # Test Docker
    if docker --version &> /dev/null; then
        log_info "Docker is working ✓"
    else
        log_error "Docker test failed"
        return 1
    fi
    
    # Test Docker Compose
    if command -v docker-compose &> /dev/null; then
        if docker-compose --version &> /dev/null; then
            log_info "Docker Compose is working ✓"
        else
            log_error "Docker Compose test failed"
            return 1
        fi
    elif docker compose version &> /dev/null; then
        log_info "Docker Compose (plugin) is working ✓"
    else
        log_error "Docker Compose test failed"
        return 1
    fi
    
    # Test management script
    if [ -x "$PROJECT_ROOT/scripts/manage.sh" ]; then
        log_info "Management script is executable ✓"
    else
        log_error "Management script is not executable"
        return 1
    fi
    
    return 0
}

show_next_steps() {
    log_step "Setup complete! Next steps:"
    
    echo ""
    echo "🚀 Quick Start Commands:"
    echo ""
    echo "  # Build the Docker image"
    echo "  ./scripts/manage.sh build"
    echo ""
    echo "  # Start a single instance"
    echo "  ./scripts/manage.sh start-single"
    echo ""
    echo "  # Start multiple instances in one container"
    echo "  ./scripts/manage.sh start-multi"
    echo ""
    echo "  # Check status"
    echo "  ./scripts/manage.sh status"
    echo ""
    echo "  # View logs"
    echo "  ./scripts/manage.sh logs"
    echo ""
    echo "📝 Configuration:"
    echo ""
    echo "  # Edit environment settings"
    echo "  ./scripts/manage.sh edit-config"
    echo ""
    echo "  # Show current configuration"
    echo "  ./scripts/manage.sh show-config"
    echo ""
    echo "📖 Documentation:"
    echo ""
    echo "  # View all available commands"
    echo "  ./scripts/manage.sh help"
    echo ""
    echo "  # Read the README for detailed information"
    echo "  cat README.md"
    echo ""
    echo "🐳 VS Code Integration:"
    echo ""
    echo "  Use Ctrl+Shift+P and search for 'Tasks: Run Task' to access"
    echo "  pre-configured build and deployment tasks."
    echo ""
    
    if [ ! -f "$PROJECT_ROOT/.env" ] || ! grep -q "NODE_ID_1=[0-9]" "$PROJECT_ROOT/.env"; then
        log_warn "Don't forget to configure your node IDs in .env file!"
    fi
}

main() {
    echo ""
    echo "=========================================="
    echo "   Nexus CLI Docker Setup"
    echo "=========================================="
    echo ""
    
    if ! check_prerequisites; then
        exit 1
    fi
    
    if ! setup_environment; then
        exit 1
    fi
    
    configure_node_ids
    
    make_scripts_executable
    
    if ! test_setup; then
        log_error "Setup test failed"
        exit 1
    fi
    
    show_next_steps
    
    echo ""
    log_info "Setup completed successfully! 🎉"
    echo ""
}

# Show help if requested
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    cat << 'EOF'
Nexus CLI Docker Setup Script

This script helps you set up the Nexus CLI Docker deployment environment.

Usage: ./setup.sh [options]

Options:
  --help, -h    Show this help message

What this script does:
  1. Checks for required tools (Docker, Docker Compose)
  2. Creates environment configuration file
  3. Prompts for node ID configuration
  4. Makes scripts executable
  5. Tests the setup
  6. Shows next steps

Prerequisites:
  - Docker installed and running
  - Docker Compose installed
  - Valid Nexus node IDs (can be configured later)

EOF
    exit 0
fi

# Run main setup
main "$@"

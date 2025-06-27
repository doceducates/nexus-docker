#!/bin/bash

# Nexus Docker Manager - Startup Script
# This script builds and starts the web management interface

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/compose/docker-compose-manager.yml"

echo "=== Nexus Docker Manager Setup ==="
echo "Project Root: $PROJECT_ROOT"
echo "Compose File: $COMPOSE_FILE"
echo

# Function to build the Nexus CLI base image
build_nexus_image() {
    echo "Building Nexus CLI base image..."
    cd "$PROJECT_ROOT"
    docker build -f docker/Dockerfile -t nexus-cli:latest docker/
    echo "✓ Nexus CLI image built successfully"
}

# Function to start the web manager
start_web_manager() {
    echo "Starting Web Manager..."
    cd "$PROJECT_ROOT/compose"
    docker-compose -f docker-compose-manager.yml up -d web-manager
    echo "✓ Web Manager started successfully"
}

# Function to show status
show_status() {
    echo "=== Container Status ==="
    cd "$PROJECT_ROOT/compose"
    docker-compose -f docker-compose-manager.yml ps
    echo
    echo "=== Web Manager Logs (last 10 lines) ==="
    docker-compose -f docker-compose-manager.yml logs --tail=10 web-manager
}

# Function to stop all services
stop_services() {
    echo "Stopping all services..."
    cd "$PROJECT_ROOT/compose"
    docker-compose -f docker-compose-manager.yml down
    echo "✓ Services stopped"
}

# Main script logic
case "${1:-start}" in
    "build")
        build_nexus_image
        ;;
    "start")
        echo "Building Nexus CLI image..."
        build_nexus_image
        echo
        start_web_manager
        echo
        show_status
        echo
        echo "🚀 Nexus Docker Manager is ready!"
        echo "   Web Interface: http://localhost:5000"
        echo "   Use 'docker logs nexus-web-manager' to view logs"
        echo "   Use '$0 stop' to stop all services"
        ;;
    "stop")
        stop_services
        ;;
    "status")
        show_status
        ;;
    "restart")
        stop_services
        echo
        build_nexus_image
        echo
        start_web_manager
        echo
        show_status
        ;;
    "logs")
        cd "$PROJECT_ROOT/compose"
        docker-compose -f docker-compose-manager.yml logs -f web-manager
        ;;
    *)
        echo "Usage: $0 {build|start|stop|status|restart|logs}"
        echo
        echo "Commands:"
        echo "  build   - Build the Nexus CLI base image"
        echo "  start   - Build and start the web manager (default)"
        echo "  stop    - Stop all services"
        echo "  status  - Show container status"
        echo "  restart - Restart all services"
        echo "  logs    - Follow web manager logs"
        exit 1
        ;;
esac

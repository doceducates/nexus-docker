#!/bin/bash
# Nexus CLI Manager - Unix Launcher
# This script provides an easy way to start the Nexus CLI Manager on Linux/macOS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEBUG_MODE=""
PORT="5000"
HOST="127.0.0.1"
INSTALL_ONLY=""
CHECK_ONLY=""

# Function to display help
show_help() {
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --debug         Run in debug mode with auto-reload"
    echo "  --port PORT     Port to listen on (default: 5000)"
    echo "  --host HOST     Host to bind to (default: 127.0.0.1)"
    echo "  --install       Install Python dependencies only"
    echo "  --check         Check system requirements only"
    echo "  --help, -h      Show this help message"
    echo
    echo "Examples:"
    echo "  $0                    Start with default settings"
    echo "  $0 --debug           Start in debug mode"
    echo "  $0 --port 8080       Start on port 8080"
    echo "  $0 --host 0.0.0.0    Listen on all interfaces"
    echo "  $0 --install         Install dependencies"
    echo
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG_MODE="--debug"
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
        --install)
            INSTALL_ONLY="--install"
            shift
            ;;
        --check)
            CHECK_ONLY="--check"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}ERROR: Unknown option $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Header
echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}   Nexus CLI Manager - Unix Launcher${NC}"
echo -e "${BLUE}===============================================${NC}"
echo

# Check if Python is available
if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
    echo -e "${RED}ERROR: Python is not installed or not in PATH${NC}"
    echo "Please install Python 3.8 or later"
    exit 1
fi

# Determine Python command
PYTHON_CMD="python3"
if ! command -v python3 &> /dev/null; then
    PYTHON_CMD="python"
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if launch.py exists
if [ ! -f "launch.py" ]; then
    echo -e "${RED}ERROR: launch.py not found in current directory${NC}"
    echo "Please make sure you're running this from the web-manager directory"
    exit 1
fi

# Handle install-only mode
if [ -n "$INSTALL_ONLY" ]; then
    echo -e "${YELLOW}Installing Python dependencies...${NC}"
    echo
    $PYTHON_CMD launch.py --install
    if [ $? -eq 0 ]; then
        echo
        echo -e "${GREEN}Dependencies installed successfully!${NC}"
        echo "You can now run: ./nexus-manager.sh"
    else
        echo
        echo -e "${RED}ERROR: Failed to install dependencies${NC}"
        exit 1
    fi
    exit 0
fi

# Handle check-only mode
if [ -n "$CHECK_ONLY" ]; then
    echo -e "${YELLOW}Checking system requirements...${NC}"
    echo
    $PYTHON_CMD launch.py --check
    exit $?
fi

# Start the application
echo -e "${GREEN}Starting Nexus CLI Manager...${NC}"
echo
echo "Configuration:"
echo "  Host: $HOST"
echo "  Port: $PORT"
if [ -n "$DEBUG_MODE" ]; then
    echo "  Mode: Debug"
else
    echo "  Mode: Production"
fi
echo

# Create a trap to handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Shutting down...${NC}"; exit 0' INT

# Run the application
$PYTHON_CMD launch.py $DEBUG_MODE --host "$HOST" --port "$PORT"
if [ $? -ne 0 ]; then
    echo
    echo -e "${RED}ERROR: Failed to start Nexus CLI Manager${NC}"
    exit 1
fi

#!/bin/bash
set -e

# Import container utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/container-utils.sh"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ASCII Art and Description
print_header() {
    echo -e "${BLUE}"
    echo "░█████╗░██╗░░██╗░░░░░░██╗░░██╗  ░██████╗██╗███╗░░░███╗██╗░░░██╗██╗░░░░░░█████╗░████████╗░█████╗░██████╗░"
    echo "██╔══██╗██║░██╔╝░░░░░░╚██╗██╔╝  ██╔════╝██║████╗░████║██║░░░██║██║░░░░░██╔══██╗╚══██╔══╝██╔══██╗██╔══██╗"
    echo "██║░░╚═╝█████═╝░█████╗░╚███╔╝░  ╚█████╗░██║██╔████╔██║██║░░░██║██║░░░░░███████║░░░██║░░░██║░░██║██████╔╝" 
    echo "██║░░██╗██╔═██╗░╚════╝░██╔██╗░  ░╚═══██╗██║██║╚██╔╝██║██║░░░██║██║░░░░░██╔══██║░░░██║░░░██║░░██║██╔══██╗"
    echo "╚█████╔╝██║░╚██╗░░░░░░██╔╝╚██╗  ██████╔╝██║██║░╚═╝░██║╚██████╔╝███████╗██║░░██║░░░██║░░░╚█████╔╝██║░░██║"
    echo "░╚════╝░╚═╝░░╚═╝░░░░░░╚═╝░░╚═╝  ╚═════╝░╚═╝╚═╝░░░░░╚═╝░╚═════╝░╚══════╝╚═╝░░╚═╝░░░╚═╝░░░░╚════╝░╚═╝░░╚═╝"
    echo -e "${NC}"
    echo -e "${CYAN}==============================================================${NC}"
    echo -e "${CYAN}CK-X Simulator: Kubernetes Certification Exam Simulator${NC}"
    echo -e "${CYAN}Practice in a realistic environment for CKA, CKAD, and more${NC}"
    echo -e "${CYAN}==============================================================${NC}"
    echo -e "${CYAN} Facing any issues? Please report at: https://github.com/nishanb/CK-X/issues${NC}"
    echo
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if Docker is running
check_container_engine_running() {
    # Detect container engine
    CONTAINER_ENGINE=$(detect_container_engine)
    
    if [ -z "$CONTAINER_ENGINE" ]; then
        echo -e "${RED}✗ No container engine found${NC}"
        echo -e "${YELLOW}Please install Docker or Podman and try again:${NC}"
        echo -e "${CYAN}Visit https://docs.docker.com/get-docker/ for Docker installation instructions${NC}"
        echo -e "${CYAN}Visit https://podman.io/getting-started/installation for Podman installation instructions${NC}"
        exit 1
    fi
    
    if ! check_container_engine_running; then
        echo -e "${RED}✗ $CONTAINER_ENGINE is not running${NC}"
        
        if [ "$CONTAINER_ENGINE" = "docker" ]; then
            echo -e "${YELLOW}Please start Docker and try again:${NC}"
            echo -e "${CYAN}1. Open Docker Desktop${NC}"
            echo -e "${CYAN}2. Wait for Docker to start${NC}"
            echo -e "${CYAN}3. Run this script again${NC}"
        fi
        exit 1
    fi
    echo
}

# Function to check system requirements
check_requirements() {
    echo -e "${BLUE}Checking System Requirements${NC}"
    echo -e "${CYAN}==============================================================${NC}"
    
    # Check for container engine (Docker or Podman)
    CONTAINER_ENGINE=$(detect_container_engine)
    
    if [ -z "$CONTAINER_ENGINE" ]; then
        echo -e "${RED}✗ Neither Docker nor Podman is installed${NC}"
        echo -e "${YELLOW}Please install Docker or Podman first:${NC}"
        echo -e "${CYAN}Visit https://docs.docker.com/get-docker/ for Docker installation instructions${NC}"
        echo -e "${CYAN}Visit https://podman.io/getting-started/installation for Podman installation instructions${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ $CONTAINER_ENGINE is installed${NC}"
    
    # Check if container engine is running
    check_container_engine_running
    
    # Check for compose
    COMPOSE_CMD=$(get_compose_command)
    
    if [ -z "$COMPOSE_CMD" ]; then
        echo -e "${RED}✗ No compose tool found for $CONTAINER_ENGINE${NC}"
        install_compose_if_needed
        
        # Check again after attempted installation
        COMPOSE_CMD=$(get_compose_command)
        if [ -z "$COMPOSE_CMD" ]; then
            echo -e "${RED}✗ Failed to find or install a compose tool${NC}"
            exit 1
        fi
    fi
    echo -e "${GREEN}✓ $COMPOSE_CMD is available${NC}"
    
    # Check curl
    if ! command_exists curl; then
        echo -e "${RED}✗ curl is not installed${NC}"
        echo -e "${YELLOW}Please install curl first${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ curl is installed${NC}"
    
    echo -e "${GREEN}✓ All system requirements satisfied${NC}"
    echo
}

# Function to check if ports are available
check_ports() {
    local port=30080
    
    echo -e "${BLUE}Checking Port Availability${NC}"
    echo -e "${CYAN}==============================================================${NC}"
    
    # Try different methods to check port availability
    if command_exists ss; then
        # Using ss (modern alternative to netstat)
        if ss -tuln | grep -q ":${port} "; then
            echo -e "${RED}✗ Port ${port} is already in use${NC}"
            echo -e "${YELLOW}Please free this port and try again${NC}"
            exit 1
        fi
    elif command_exists lsof; then
        # Using lsof
        if lsof -i :${port} >/dev/null 2>&1; then
            echo -e "${RED}✗ Port ${port} is already in use${NC}"
            echo -e "${YELLOW}Please free this port and try again${NC}"
            exit 1
        fi
    else
        # Fallback: try to bind to the port
        if timeout 1 bash -c ">/dev/tcp/localhost/${port}" 2>/dev/null; then
            echo -e "${RED}✗ Port ${port} is already in use${NC}"
            echo -e "${YELLOW}Please free this port and try again${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✓ Port ${port} is available${NC}"
    echo
}

# Function to wait for service health (modified to be silent)
wait_for_service() {
    local service=$1
    local max_attempts=30
    local attempt=1
    
    # No output headers here anymore
    
    while [ $attempt -le $max_attempts ]; do
        if $COMPOSE_CMD ps $service | grep -q "healthy"; then
            return 0
        fi
        # No progress dots
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}✗ Timeout waiting for $service to be ready${NC}"
    return 1
}

# Function to open browser
open_browser() {
    local url="https://play.sailor.sh/"
    echo -e "${BLUE}Opening Browser${NC}"
    echo -e "${CYAN}==============================================================${NC}"
    
    # Try different methods to open browser
    if command_exists xdg-open; then
        # Linux with desktop environment
        xdg-open $url 2>/dev/null && echo -e "${GREEN}✓ Browser opened successfully${NC}" && return 0
    elif command_exists open; then
        # macOS
        open $url 2>/dev/null && echo -e "${GREEN}✓ Browser opened successfully${NC}" && return 0
    elif command_exists python3; then
        # Try Python as fallback
        python3 -m webbrowser $url 2>/dev/null && echo -e "${GREEN}✓ Browser opened successfully${NC}" && return 0
    elif command_exists python; then
        # Try Python 2 as last resort
        python -m webbrowser $url 2>/dev/null && echo -e "${GREEN}✓ Browser opened successfully${NC}" && return 0
    fi
    
    echo -e "${YELLOW}Could not automatically open browser. Please visit:${NC}"
    echo -e "${GREEN}https://play.sailor.sh/${NC}"
    return 1
}

# Main installation process
main() {
    print_header
    
    # Check requirements
    check_requirements
    
    # Check port
    check_ports
    
    # Create project directory
    echo -e "${BLUE}Setting Up Installation${NC}"
    echo -e "${CYAN}==============================================================${NC}"
    echo -e "${YELLOW}Creating project directory...${NC}"
    mkdir -p ck-x-simulator && cd ck-x-simulator
    
    # Download docker-compose.yml
    echo -e "${YELLOW}Downloading Compose file...${NC}"
    curl -fsSL https://raw.githubusercontent.com/nishanb/ck-x/master/docker-compose.yaml -o docker-compose.yml
    
    if [ ! -f docker-compose.yml ]; then
        echo -e "${RED}✗ Failed to download docker-compose.yml${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Compose file downloaded${NC}"
    
    # Pull images
    echo -e "${YELLOW}Pulling container images...${NC}"
    $COMPOSE_CMD pull
    echo -e "${GREEN}✓ Container images pulled successfully${NC}"
    
    # Start services
    echo -e "${YELLOW}Starting CK-X services...${NC}"
    $COMPOSE_CMD up -d
    echo -e "${GREEN}✓ Services started${NC}"
    
    # Combined waiting message instead of individual service wait messages
    echo -e "${YELLOW}Waiting for services to initialize...${NC}"
    wait_for_service "webapp" || exit 1
    wait_for_service "facilitator" || exit 1
    echo -e "${GREEN}✓ All services initialized successfully${NC}"
    
    echo -e "\n${BLUE}Installation Complete!${NC}"
    echo -e "${CYAN}==============================================================${NC}"
    echo -e "${GREEN}✓ CK-X Simulator has been installed successfully${NC}"
    
    # Wait a bit for the service to be fully ready
    sleep 5
    
    # Try to open browser
    open_browser
    
    echo -e "\n${BLUE}Useful Commands${NC}"
    echo -e "${CYAN}==============================================================${NC}"
    echo -e "${YELLOW}CK-X Simulator has been installed in:${NC} ${GREEN}$(pwd)${NC}, run all below commands from this directory"
    echo -e "${YELLOW}To stop CK-X  ${GREEN}$COMPOSE_CMD down --volumes --remove-orphans --rmi all${NC}"
    echo -e "${YELLOW}To Restart CK-X:${NC} ${GREEN}$COMPOSE_CMD restart${NC}"
    
    if [ "$CONTAINER_ENGINE" = "docker" ]; then
        echo -e "${YELLOW}To clean up all containers and images:${NC} ${GREEN}docker system prune -a${NC}"
        echo -e "${YELLOW}To remove only CK-X images:${NC} ${GREEN}$COMPOSE_CMD down --rmi all${NC}"
    elif [ "$CONTAINER_ENGINE" = "podman" ]; then
        echo -e "${YELLOW}To clean up all containers and images:${NC} ${GREEN}podman system prune -a${NC}"
        echo -e "${YELLOW}To remove only CK-X images:${NC} ${GREEN}$COMPOSE_CMD down --rmi all${NC}"
    fi
    
    echo -e "${YELLOW}To access CK-X Simulator:${NC} ${GREEN}https://play.sailor.sh/${NC}"
    echo
    echo -e "${CYAN}Thank you for installing CK-X Simulator!${NC}"
}

# Run main function
main 
#!/bin/bash

# Utility script for detecting and using Docker or Podman

# Function to determine which container technology to use
# Returns the command to use (docker or podman)
detect_container_engine() {
    # Check for Docker first
    if command -v docker >/dev/null 2>&1; then
        # Check if Docker is running
        if docker info >/dev/null 2>&1; then
            echo "docker"
            return 0
        fi
    fi
    
    # Check for Podman next
    if command -v podman >/dev/null 2>&1; then
        # Podman doesn't need a daemon, so just check if it's available
        echo "podman"
        return 0
    fi
    
    # Neither Docker nor Podman is available
    echo ""
    return 1
}

# Function to get the appropriate compose command
# Returns the compose command to use (docker compose, podman-compose, etc.)
get_compose_command() {
    local container_engine=$(detect_container_engine)
    
    if [ "$container_engine" = "docker" ]; then
        if docker compose version >/dev/null 2>&1; then
            echo "docker compose"
            return 0
        elif command -v docker-compose >/dev/null 2>&1; then
            echo "docker-compose"
            return 0
        fi
    elif [ "$container_engine" = "podman" ]; then
        if command -v podman-compose >/dev/null 2>&1; then
            echo "podman-compose"
            return 0
        fi
    fi
    
    # No compose tool found
    echo ""
    return 1
}

# Function to check if container engine is running
# Returns 0 if running, 1 if not
check_container_engine_running() {
    local container_engine=$(detect_container_engine)
    
    if [ "$container_engine" = "docker" ]; then
        if docker info >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    elif [ "$container_engine" = "podman" ]; then
        # Podman doesn't have a daemon that needs to be running
        return 0
    fi
    
    # No container engine available
    return 1
}

# Function to install compose plugin for the current container engine if needed
# This is a best-effort function
install_compose_if_needed() {
    local container_engine=$(detect_container_engine)
    local compose_command=$(get_compose_command)
    
    # If we already have a compose command, we're good
    if [ -n "$compose_command" ]; then
        return 0
    fi
    
    # Try to install the appropriate compose tool
    if [ "$container_engine" = "docker" ]; then
        echo "Docker is installed but docker compose is missing."
        echo "Please install Docker Compose using your package manager or following the instructions at:"
        echo "https://docs.docker.com/compose/install/"
        return 1
    elif [ "$container_engine" = "podman" ]; then
        echo "Podman is installed but podman-compose is missing."
        echo "You can install podman-compose using pip:"
        echo "pip3 install podman-compose"
        
        # Ask if user wants to install podman-compose
        read -p "Would you like to install podman-compose now? (y/n): " install_choice
        if [[ "$install_choice" =~ ^[Yy]$ ]]; then
            if command -v pip3 >/dev/null 2>&1; then
                pip3 install podman-compose
                if [ $? -eq 0 ]; then
                    echo "podman-compose installed successfully."
                    return 0
                else
                    echo "Failed to install podman-compose."
                    return 1
                fi
            else
                echo "pip3 not found. Please install Python and pip first."
                return 1
            fi
        else
            echo "Skipping podman-compose installation."
            return 1
        fi
    fi
    
    return 1
}

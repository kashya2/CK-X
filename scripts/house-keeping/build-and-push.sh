#!/bin/bash

# Script to build and push container images for CK-X Simulator
# This script builds all images defined in the compose.yaml file and pushes them to a container registry
# Supports multi-architecture builds (linux/amd64 and linux/arm64)

# Import container utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../container-utils.sh"

# Detect container engine
CONTAINER_ENGINE=$(detect_container_engine)
if [ -z "$CONTAINER_ENGINE" ]; then
    echo "Error: No container engine (Docker or Podman) found. Please install Docker or Podman and try again."
    exit 1
fi

# Set variables
DOCKER_HUB_USERNAME=${DOCKER_HUB_USERNAME:-nishanb}
REGISTRY="${DOCKER_HUB_USERNAME}"
SKIP_LOGIN_CHECK=${SKIP_LOGIN_CHECK:-false}
PLATFORMS="linux/amd64,linux/arm64"

# Get the script directory to handle relative paths correctly
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
echo "PROJECT_ROOT: ${PROJECT_ROOT}"

# Define color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}  CK-X Simulator - Build & Push Tool  ${NC}"
echo -e "${GREEN}=======================================${NC}"
echo

# Check if buildx/buildah is available
if [ "$CONTAINER_ENGINE" = "docker" ]; then
    echo -e "${YELLOW}Checking Docker buildx availability...${NC}"
    if ! docker buildx version > /dev/null 2>&1; then
        echo -e "${RED}Docker buildx is not available. Please ensure you have Docker 19.03 or newer with experimental features enabled.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Docker buildx is available.${NC}"

    # Create a new builder instance if it doesn't exist
    BUILDER_NAME="ck-x-multiarch-builder"
    if ! docker buildx inspect ${BUILDER_NAME} > /dev/null 2>&1; then
        echo -e "${YELLOW}Creating new buildx builder: ${BUILDER_NAME}${NC}"
        docker buildx create --name ${BUILDER_NAME} --use --bootstrap
    else
        echo -e "${YELLOW}Using existing buildx builder: ${BUILDER_NAME}${NC}"
        docker buildx use ${BUILDER_NAME}
    fi

    # Ensure the builder is running
    echo -e "${YELLOW}Bootstrapping buildx builder...${NC}"
    docker buildx inspect --bootstrap
    echo -e "${GREEN}Buildx builder is ready.${NC}"
elif [ "$CONTAINER_ENGINE" = "podman" ]; then
    echo -e "${YELLOW}Checking Podman version and capabilities...${NC}"
    if ! podman --version | grep -q "podman version"; then
        echo -e "${RED}Podman command not functioning properly.${NC}"
        exit 1
    fi
    
    # Check if podman can build multi-architecture images
    if ! podman build --help | grep -q -- "--platform"; then
        echo -e "${RED}This version of Podman doesn't support multi-architecture builds.${NC}"
        echo -e "${YELLOW}Please upgrade to Podman 4.0 or newer for full multi-architecture support.${NC}"
        
        # Ask if user wants to continue with single architecture builds
        read -p "Continue with single architecture builds? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Operation cancelled by user.${NC}"
            exit 0
        fi
        # Set platforms to current architecture only
        PLATFORMS="$(podman info --format '{{.Host.Arch}}')"
        echo -e "${YELLOW}Continuing with single architecture: ${PLATFORMS}${NC}"
    else
        echo -e "${GREEN}Podman with multi-architecture support is available.${NC}"
    fi
fi
echo

# Check if user is logged in to container registry (with option to skip)
if [ "$SKIP_LOGIN_CHECK" != "true" ]; then
    echo -e "${YELLOW}Checking registry login status...${NC}"
    
    if [ "$CONTAINER_ENGINE" = "docker" ]; then
        # Try multiple methods to check login status for Docker
        if [ -f ~/.docker/config.json ]; then
            if grep -q "auth" ~/.docker/config.json; then
                echo -e "${GREEN}Docker credentials found in config file.${NC}"
                LOGIN_STATUS=0
            else
                echo -e "${RED}No credentials found in Docker config file.${NC}"
                LOGIN_STATUS=1
            fi
        else
            # Try the docker info method
            docker info 2>/dev/null | grep -q Username
            LOGIN_STATUS=$?
            
            if [ $LOGIN_STATUS -ne 0 ]; then
                echo -e "${RED}You do not appear to be logged in to Docker Hub.${NC}"
            else
                echo -e "${GREEN}You appear to be logged in to Docker Hub.${NC}"
            fi
        fi
    elif [ "$CONTAINER_ENGINE" = "podman" ]; then
        # Check login status for Podman
        if podman login --get-login docker.io > /dev/null 2>&1; then
            echo -e "${GREEN}You appear to be logged in to Docker Hub with Podman.${NC}"
            LOGIN_STATUS=0
        else
            echo -e "${RED}You do not appear to be logged in to Docker Hub with Podman.${NC}"
            LOGIN_STATUS=1
        fi
    fi
    
    # Allow user to continue anyway
    if [ $LOGIN_STATUS -ne 0 ]; then
        echo -e "${YELLOW}You might need to log in using: ${CONTAINER_ENGINE} login${NC}"
        echo -e "${YELLOW}However, you can still continue if you're sure you're logged in.${NC}"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Operation cancelled by user.${NC}"
            exit 0
        fi
        echo -e "${GREEN}Continuing with build and push process...${NC}"
    else
        echo -e "${GREEN}You are logged in to container registry.${NC}"
    fi
else
    echo -e "${YELLOW}Skipping registry login check as requested.${NC}"
fi
echo

# Ask for tag
echo -e "${YELLOW}Please enter tag for the images (default: latest):${NC}"
read -r TAG_INPUT
TAG="${TAG_INPUT:-latest}"
echo -e "${GREEN}Using tag: ${TAG}${NC}"
echo

# Function to build and push a single image with multi-architecture support
build_and_push() {
    local COMPONENT=$1
    local CONTEXT_PATH=$2
    local IMAGE_NAME="${REGISTRY}/ck-x-simulator-${COMPONENT}:${TAG}"
    
    echo -e "${YELLOW}Building multi-architecture image: ${IMAGE_NAME}${NC}"
    echo -e "Context path: ${CONTEXT_PATH}"
    echo -e "Platforms: ${PLATFORMS}"
    
    # Check if the context path exists
    if [ ! -d "${CONTEXT_PATH}" ]; then
        echo -e "${RED}Error: Context path '${CONTEXT_PATH}' does not exist!${NC}"
        exit 1
    fi
    
    # Build and push based on container engine
    if [ "$CONTAINER_ENGINE" = "docker" ]; then
        # Docker with buildx
        echo -e "${YELLOW}Building and pushing image with Docker buildx...${NC}"
        docker buildx build \
            --platform=${PLATFORMS} \
            --tag ${IMAGE_NAME} \
            --push \
            ${CONTEXT_PATH}
        BUILD_STATUS=$?
    elif [ "$CONTAINER_ENGINE" = "podman" ]; then
        # Podman approach
        echo -e "${YELLOW}Building and pushing image with Podman...${NC}"
        
        # Check if we're doing multi-arch build
        if [[ "$PLATFORMS" == *","* ]]; then
            # Multi-arch build with podman
            # We need to build separately for each platform and create a manifest
            MANIFEST_NAME="${IMAGE_NAME}"
            PLATFORM_LIST=(${PLATFORMS//,/ })
            
            # Remove any existing manifest with this name
            podman manifest rm ${MANIFEST_NAME} 2>/dev/null || true
            
            # Create a new manifest
            podman manifest create ${MANIFEST_NAME}
            
            for PLATFORM in "${PLATFORM_LIST[@]}"; do
                PLATFORM_TAG="${IMAGE_NAME}-${PLATFORM//\//-}"
                echo -e "${YELLOW}Building for platform: ${PLATFORM}${NC}"
                
                podman build \
                    --platform=${PLATFORM} \
                    --tag ${PLATFORM_TAG} \
                    ${CONTEXT_PATH}
                
                if [ $? -ne 0 ]; then
                    echo -e "${RED}Failed to build image for platform ${PLATFORM}${NC}"
                    continue
                fi
                
                # Push the platform-specific image
                podman push ${PLATFORM_TAG}
                
                if [ $? -ne 0 ]; then
                    echo -e "${RED}Failed to push image for platform ${PLATFORM}${NC}"
                    continue
                fi
                
                # Add to manifest
                podman manifest add ${MANIFEST_NAME} ${PLATFORM_TAG}
            done
            
            # Push the manifest
            podman manifest push ${MANIFEST_NAME} docker://${MANIFEST_NAME}
            BUILD_STATUS=$?
        else
            # Single architecture build
            podman build \
                --platform=${PLATFORMS} \
                --tag ${IMAGE_NAME} \
                ${CONTEXT_PATH}
                
            if [ $? -eq 0 ]; then
                podman push ${IMAGE_NAME}
                BUILD_STATUS=$?
            else
                BUILD_STATUS=1
            fi
        fi
    fi
    
    if [ $BUILD_STATUS -eq 0 ]; then
        echo -e "${GREEN}Successfully built and pushed ${IMAGE_NAME} for platforms: ${PLATFORMS}${NC}"
    else
        echo -e "${RED}Failed to build/push ${IMAGE_NAME}${NC}"
        exit 1
    fi
    
    echo
}

# Confirm before proceeding
echo -e "${YELLOW}This script will build and push the following multi-architecture images (${PLATFORMS}) with tag '${TAG}':${NC}"
echo " - ${REGISTRY}/ck-x-simulator-remote-desktop:${TAG}"
echo " - ${REGISTRY}/ck-x-simulator-webapp:${TAG}"
echo " - ${REGISTRY}/ck-x-simulator-nginx:${TAG}"
echo " - ${REGISTRY}/ck-x-simulator-jumphost:${TAG}"
echo " - ${REGISTRY}/ck-x-simulator-remote-terminal:${TAG}"
echo " - ${REGISTRY}/ck-x-simulator-cluster:${TAG}"
echo " - ${REGISTRY}/ck-x-simulator-facilitator:${TAG}"
echo -e "${YELLOW}Using container engine: ${CONTAINER_ENGINE}${NC}"
echo
read -p "Do you want to continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Operation cancelled by user.${NC}"
    exit 0
fi

# Build and push each image
echo -e "${GREEN}Starting multi-architecture build and push process...${NC}"
echo

# Remote Desktop
build_and_push "remote-desktop" "${PROJECT_ROOT}/remote-desktop"

# Web Application
build_and_push "webapp" "${PROJECT_ROOT}/app"

# Nginx
build_and_push "nginx" "${PROJECT_ROOT}/nginx"

# Jump Host
build_and_push "jumphost" "${PROJECT_ROOT}/jumphost"

# Remote Terminal
build_and_push "remote-terminal" "${PROJECT_ROOT}/remote-terminal"

# Kubernetes Cluster
build_and_push "cluster" "${PROJECT_ROOT}/kind-cluster"

# Facilitator
build_and_push "facilitator" "${PROJECT_ROOT}/facilitator"

echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}  All multi-architecture images built and pushed successfully!  ${NC}"
echo -e "${GREEN}  Tag: ${TAG}  ${NC}"
echo -e "${GREEN}  Platforms: ${PLATFORMS}  ${NC}"
echo -e "${GREEN}  Container Engine: ${CONTAINER_ENGINE}  ${NC}"
echo -e "${GREEN}=======================================${NC}"

# Done
exit 0 
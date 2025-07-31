#!/bin/bash

# AWS Security Hub SOC - Optimized Multi-Stage Docker Build Script
# This script builds the Docker image using multi-stage builds for optimization

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="aws-security-hub-soc"
TAG="${1:-latest}"
BUILD_CONTEXT="."

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}AWS Security Hub SOC - Multi-Stage Build${NC}"
echo -e "${BLUE}===========================================${NC}"

echo -e "\n${YELLOW}Building optimized Docker image...${NC}"
echo "Image: ${IMAGE_NAME}:${TAG}"
echo "Build Context: ${BUILD_CONTEXT}"

# Check if Dockerfile exists
if [ ! -f "Dockerfile" ]; then
    echo -e "${RED}Error: Dockerfile not found in current directory${NC}"
    exit 1
fi

# Build the image with multi-stage optimization
echo -e "\n${BLUE}Starting multi-stage build...${NC}"

docker build \
    --tag "${IMAGE_NAME}:${TAG}" \
    --target final \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    "${BUILD_CONTEXT}"

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ Build completed successfully!${NC}"
    
    # Show image information
    echo -e "\n${BLUE}Image Information:${NC}"
    docker images "${IMAGE_NAME}:${TAG}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    
    # Show image layers (optional)
    echo -e "\n${BLUE}Image History (last 10 layers):${NC}"
    docker history "${IMAGE_NAME}:${TAG}" | head -10
    
    echo -e "\n${GREEN}Multi-stage build optimization benefits:${NC}"
    echo "• Reduced final image size by excluding build dependencies"
    echo "• Improved security by minimizing attack surface"
    echo "• Faster deployment due to smaller image size"
    echo "• Cleaner runtime environment"
    
    echo -e "\n${BLUE}To run the container:${NC}"
    echo "docker run -it --rm ${IMAGE_NAME}:${TAG}"
    
    echo -e "\n${BLUE}To use with docker-compose:${NC}"
    echo "Update docker-compose.yml to use: ${IMAGE_NAME}:${TAG}"
    
else
    echo -e "\n${RED}✗ Build failed!${NC}"
    exit 1
fi

echo -e "\n${GREEN}Build process completed!${NC}"

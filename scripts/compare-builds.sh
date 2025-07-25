#!/bin/bash

# AWS Security Hub SOC - Build Comparison Script
# This script compares single-stage vs multi-stage Docker builds

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

IMAGE_NAME="aws-security-hub-soc"

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Docker Build Comparison Tool${NC}"
echo -e "${BLUE}==========================================${NC}"

# Function to get image size
get_image_size() {
    local image=$1
    docker images "$image" --format "{{.Size}}" 2>/dev/null || echo "N/A"
}

# Function to build and time
build_and_time() {
    local dockerfile=$1
    local tag=$2
    local description=$3
    
    echo -e "\n${YELLOW}Building $description...${NC}"
    
    local start_time=$(date +%s)
    
    if [ "$dockerfile" = "multi-stage" ]; then
        docker build --target final -t "${IMAGE_NAME}:${tag}" . >/dev/null 2>&1
    else
        # For single-stage, we'll create a temporary Dockerfile
        cat > Dockerfile.single << EOF
FROM amazon/aws-cli:latest

# Install jq for JSON processing and Python for data processor
RUN yum update -y && yum install -y jq python3 python3-pip curl wget tar gzip && yum clean all

# Install Python dependencies for data processor
COPY data-processor/requirements.txt /tmp/requirements.txt
RUN pip3 install -r /tmp/requirements.txt

# Copy all tools and dependencies
COPY data-processor/ /data-processor/

# Set working directory
WORKDIR /aws-scripts

# Default command
CMD ["/bin/bash"]
EOF
        docker build -f Dockerfile.single -t "${IMAGE_NAME}:${tag}" . >/dev/null 2>&1
        rm -f Dockerfile.single
    fi
    
    local end_time=$(date +%s)
    local build_time=$((end_time - start_time))
    
    local size=$(get_image_size "${IMAGE_NAME}:${tag}")
    
    echo -e "${GREEN}✓ Completed in ${build_time}s - Size: ${size}${NC}"
    
    return $build_time
}

echo -e "\n${BLUE}Starting build comparison...${NC}"

# Build single-stage
echo -e "\n${BLUE}1. Single-Stage Build${NC}"
build_and_time "single-stage" "single" "Single-Stage Build"
single_time=$?
single_size=$(get_image_size "${IMAGE_NAME}:single")

# Build multi-stage
echo -e "\n${BLUE}2. Multi-Stage Build${NC}"
build_and_time "multi-stage" "multi" "Multi-Stage Build"
multi_time=$?
multi_size=$(get_image_size "${IMAGE_NAME}:multi")

# Results comparison
echo -e "\n${BLUE}==========================================${NC}"
echo -e "${BLUE}BUILD COMPARISON RESULTS${NC}"
echo -e "${BLUE}==========================================${NC}"

printf "%-20s %-15s %-15s %-15s\n" "Metric" "Single-Stage" "Multi-Stage" "Improvement"
echo "---------------------------------------- --------------- --------------- ---------------"
printf "%-20s %-15s %-15s " "Build Time" "${single_time}s" "${multi_time}s"

if [ $multi_time -lt $single_time ]; then
    improvement=$((single_time - multi_time))
    echo -e "${GREEN}-${improvement}s${NC}"
else
    improvement=$((multi_time - single_time))
    echo -e "${RED}+${improvement}s${NC}"
fi

printf "%-20s %-15s %-15s " "Image Size" "$single_size" "$multi_size"

# Simple size comparison (this is approximate)
if [[ "$single_size" == *"MB"* ]] && [[ "$multi_size" == *"MB"* ]]; then
    single_mb=$(echo "$single_size" | sed 's/MB//')
    multi_mb=$(echo "$multi_size" | sed 's/MB//')
    if (( $(echo "$multi_mb < $single_mb" | bc -l) )); then
        savings=$(echo "$single_mb - $multi_mb" | bc -l)
        echo -e "${GREEN}-${savings}MB${NC}"
    else
        increase=$(echo "$multi_mb - $single_mb" | bc -l)
        echo -e "${RED}+${increase}MB${NC}"
    fi
else
    echo "Size varies"
fi

echo ""

# Show layer information
echo -e "\n${BLUE}Image Layer Analysis:${NC}"
echo -e "\n${YELLOW}Single-Stage Layers:${NC}"
docker history "${IMAGE_NAME}:single" --format "table {{.Size}}\t{{.CreatedBy}}" | head -5

echo -e "\n${YELLOW}Multi-Stage Layers:${NC}"
docker history "${IMAGE_NAME}:multi" --format "table {{.Size}}\t{{.CreatedBy}}" | head -5

# Recommendations
echo -e "\n${BLUE}==========================================${NC}"
echo -e "${BLUE}RECOMMENDATIONS${NC}"
echo -e "${BLUE}==========================================${NC}"

echo -e "\n${GREEN}✓ Benefits of Multi-Stage Build:${NC}"
echo "  • Smaller production image size"
echo "  • Improved security (fewer packages in final image)"
echo "  • Better layer caching"
echo "  • Cleaner runtime environment"

echo -e "\n${YELLOW}📋 Next Steps:${NC}"
echo "  1. Use multi-stage build for production deployments"
echo "  2. Update docker-compose.yml to use optimized image"
echo "  3. Configure CI/CD pipeline with multi-stage builds"
echo "  4. Regular image scanning for security vulnerabilities"

# Cleanup
echo -e "\n${BLUE}Cleaning up comparison images...${NC}"
docker rmi "${IMAGE_NAME}:single" "${IMAGE_NAME}:multi" >/dev/null 2>&1 || true

echo -e "\n${GREEN}Comparison completed!${NC}"

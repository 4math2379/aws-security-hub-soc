# Multi-Stage Docker Build Integration

This document describes the multi-stage Docker build implementation for AWS Security Hub SOC project.

## Overview

The multi-stage Docker build optimizes the final image by separating the build environment from the runtime environment. This approach provides several benefits:

- **Reduced Image Size**: Only runtime dependencies are included in the final image
- **Improved Security**: Build tools and unnecessary packages are excluded from production
- **Faster Deployments**: Smaller images deploy faster
- **Better Caching**: Docker layer caching is more effective

## Build Stages

### Stage 1: Builder (`builder`)
- **Base Image**: `amazon/aws-cli:latest`
- **Purpose**: Install build dependencies and Python packages
- **Components**:
  - System packages (jq, python3, pip, curl, wget, tar, gzip)
  - Python dependencies (boto3, pandas, requests, PyYAML, etc.)
  - Custom requirements from `data-processor/requirements.txt`

### Stage 2: Final Runtime (`final`)
- **Base Image**: `amazon/aws-cli:latest`
- **Purpose**: Minimal runtime environment
- **Components**:
  - Only essential runtime packages (jq, python3)
  - Python packages copied from builder stage
  - AWS CLI tools
  - Application scripts and data processor

## Usage

### Building the Optimized Image

#### Option 1: Using the Build Script (Recommended)
```bash
# Build with default tag (latest)
./scripts/build-optimized.sh

# Build with custom tag
./scripts/build-optimized.sh v1.2.0
```

#### Option 2: Direct Docker Build
```bash
# Build targeting the final stage
docker build --target final -t aws-security-hub-soc:latest .

# Build with BuildKit for better caching
DOCKER_BUILDKIT=1 docker build --target final -t aws-security-hub-soc:latest .
```

### Running the Container

```bash
# Interactive mode
docker run -it --rm aws-security-hub-soc:latest

# With volume mounts (as in docker-compose)
docker run -it --rm \
  -v ./aws-credentials/account1:/root/.aws:ro \
  -v ./aws-scripts:/aws-scripts:ro \
  -v ./output/account1:/output \
  aws-security-hub-soc:latest
```

## Integration with Docker Compose

Update your `docker-compose.yml` to use the optimized image:

```yaml
services:
  awscli-account1:
    image: aws-security-hub-soc:latest  # Use custom built image
    # Remove 'build: .' directive
    container_name: aws-security-hub-account1
    volumes:
      - ./aws-credentials/account1:/root/.aws:ro
      - ./aws-scripts:/aws-scripts:ro
      - ./output/account1:/output
    # ... rest of configuration
```

## Build Optimization Features

### Docker Layer Caching
- Separates dependency installation from application code
- Changes to scripts don't invalidate Python package cache
- Faster subsequent builds

### .dockerignore Integration
- Excludes unnecessary files from build context
- Reduces build time and context size
- Prevents sensitive files from being accidentally included

### BuildKit Support
- Parallel build stages
- Advanced caching mechanisms
- Better build performance

## File Structure Impact

```
aws-security-hub-soc/
├── Dockerfile                    # Multi-stage Dockerfile
├── .dockerignore                 # Build context optimization
├── scripts/
│   └── build-optimized.sh        # Automated build script
├── data-processor/
│   └── requirements.txt          # Python dependencies
└── docs/
    └── MULTI_STAGE_BUILD.md      # This documentation
```

## Size Comparison

| Build Type | Approximate Size | Components |
|------------|------------------|------------|
| Single-stage | ~800MB | All build and runtime dependencies |
| Multi-stage | ~500MB | Only runtime dependencies |
| **Savings** | **~300MB** | **37% size reduction** |

## Troubleshooting

### Build Issues

1. **Python package installation fails**
   ```bash
   # Check if requirements.txt exists and is readable
   cat data-processor/requirements.txt
   ```

2. **COPY commands fail**
   ```bash
   # Ensure source directories exist
   mkdir -p data-processor
   touch data-processor/requirements.txt
   ```

3. **Permission issues**
   ```bash
   # Make build script executable
   chmod +x scripts/build-optimized.sh
   ```

### Runtime Issues

1. **Python imports fail**
   ```bash
   # Check Python path in container
   docker run --rm aws-security-hub-soc:latest python3 -c "import sys; print(sys.path)"
   ```

2. **Missing tools**
   ```bash
   # Verify tools are available
   docker run --rm aws-security-hub-soc:latest which jq aws
   ```

## Best Practices

1. **Keep stages minimal**: Only install what's needed in each stage
2. **Use specific tags**: Pin base image versions for reproducibility
3. **Leverage caching**: Order Dockerfile commands from least to most frequently changing
4. **Regular cleanup**: Remove unused images with `docker image prune`
5. **Security scanning**: Regularly scan images for vulnerabilities

## Migration from Single-Stage

If upgrading from a single-stage build:

1. Backup existing Dockerfile: `cp Dockerfile Dockerfile.backup`
2. Update docker-compose.yml to use the new image
3. Test the new build: `./scripts/build-optimized.sh`
4. Verify all functionality works as expected
5. Update CI/CD pipelines if applicable

## Performance Metrics

Expected improvements with multi-stage build:
- **Build time**: 10-20% faster (with caching)
- **Image size**: 30-40% smaller
- **Deploy time**: 20-30% faster
- **Security**: Reduced attack surface

## Contributing

When modifying the multi-stage build:

1. Test both stages independently
2. Verify final image functionality
3. Update this documentation
4. Check image size impact
5. Test with docker-compose integration

# Stage 1: Build and install dependencies
FROM amazon/aws-cli:latest AS builder

# Install build dependencies and tools
RUN yum update -y && \
    yum install -y jq python3 python3-pip curl wget tar gzip && \
    yum clean all

# Create directories for dependencies
RUN mkdir -p /app/tools /app/python-deps

# Install common Python packages that might be needed
RUN pip3 install --target=/app/python-deps \
    boto3 \
    pandas \
    requests \
    PyYAML \
    jsonschema

# Copy and install any custom requirements if they exist
COPY data-processor/requirements.txt /tmp/requirements.txt 2>/dev/null || echo "# No custom requirements" > /tmp/requirements.txt
RUN pip3 install --target=/app/python-deps -r /tmp/requirements.txt 2>/dev/null || true

# Stage 2: Final runtime image
FROM amazon/aws-cli:latest AS final

# Install only runtime dependencies
RUN yum update -y && \
    yum install -y jq python3 && \
    yum clean all && \
    rm -rf /var/cache/yum

# Copy Python packages from builder
COPY --from=builder /app/python-deps /usr/local/lib/python3.7/site-packages/

# Copy any additional tools from builder
COPY --from=builder /app/tools /usr/local/bin/

# Set Python path
ENV PYTHONPATH="/usr/local/lib/python3.7/site-packages:${PYTHONPATH}"

# Copy data processor if it exists
COPY data-processor/ /data-processor/ 2>/dev/null || mkdir -p /data-processor

# Set working directory
WORKDIR /aws-scripts

# Add labels for better maintainability
LABEL maintainer="AWS Security Hub SOC Team" \
      description="Multi-stage Docker build for AWS Security Hub SOC operations" \
      version="1.0.0"

# Default command
CMD ["/bin/bash"]

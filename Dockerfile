FROM amazon/aws-cli:latest

# Install jq for JSON processing and Python for data processor
RUN yum update -y && yum install -y jq python3 python3-pip && yum clean all

# Install Python dependencies for data processor
COPY data-processor/requirements.txt /tmp/requirements.txt
RUN pip3 install -r /tmp/requirements.txt

# Copy data processor
COPY data-processor/ /data-processor/

# Set working directory
WORKDIR /aws-scripts

# Default command
CMD ["/bin/bash"]

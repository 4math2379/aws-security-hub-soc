FROM amazon/aws-cli:latest

# Install jq for JSON processing
RUN yum update -y && yum install -y jq && yum clean all

# Set working directory
WORKDIR /aws-scripts

# Default command
CMD ["/bin/bash"]

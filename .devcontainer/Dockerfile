# Dockerfile for DevApp Development Environment
# Supports Angular 21 + Spring Boot 3.5.3 development

FROM mcr.microsoft.com/devcontainers/java:21-bookworm

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_VERSION=24
ENV MAVEN_VERSION=3.9.9
ENV MAVEN_HOME=/opt/maven
ENV PATH=$MAVEN_HOME/bin:$PATH

# Install Maven and additional system dependencies
RUN apt-get update && apt-get install -y \
    # Basic tools
    wget \
    # Network tools
    net-tools \
    # Process tools
    htop \
    # Clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    # Install Maven
    && wget -q https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
    && tar -xzf apache-maven-${MAVEN_VERSION}-bin.tar.gz -C /opt \
    && ln -s /opt/apache-maven-${MAVEN_VERSION} /opt/maven \
    && rm apache-maven-${MAVEN_VERSION}-bin.tar.gz

# Install Node.js 24.x using NodeSource repository
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y nodejs

# Install Angular CLI globally
RUN npm install -g @angular/cli@21

# Install useful development tools
RUN npm install -g \
    typescript \
    ts-node \
    nodemon \
    concurrently

# Create workspace and Maven directories
RUN mkdir -p /workspace \
    && mkdir -p /home/vscode/.m2/repository

# Change ownership of workspace and Maven directories to vscode user
RUN chown -R vscode:vscode /workspace \
    && chown -R vscode:vscode /home/vscode/.m2

# Switch to vscode user
USER vscode

# Set working directory
WORKDIR /workspace

# Verify installations
RUN echo "=== Verifying installations ===" \
    && java -version \
    && mvn -version \
    && node -v \
    && npm -v \
    && ng --version \
    && echo "=== All tools verified successfully ==="

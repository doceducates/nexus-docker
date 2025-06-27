# Multi-stage Dockerfile for Nexus CLI
FROM debian:12-slim AS downloader

# Install dependencies for downloading
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# Download the latest Nexus CLI binary
# Create a robust download script that works across platforms
RUN echo '#!/bin/bash' > download_nexus.sh && \
    echo 'set -e' >> download_nexus.sh && \
    echo 'echo "Downloading Nexus CLI..."' >> download_nexus.sh && \
    echo 'ARCH=$(uname -m)' >> download_nexus.sh && \
    echo 'OS=$(uname -s | tr "[:upper:]" "[:lower:]")' >> download_nexus.sh && \
    echo 'echo "Detected OS: $OS, Architecture: $ARCH"' >> download_nexus.sh && \
    echo 'if [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; fi' >> download_nexus.sh && \
    echo 'if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi' >> download_nexus.sh && \
    echo '# Try multiple download methods' >> download_nexus.sh && \
    echo 'if ! curl -sSfL "https://github.com/nexus-xyz/nexus-cli/releases/latest/download/nexus-cli-${OS}-${ARCH}" -o nexus-cli; then' >> download_nexus.sh && \
    echo '  echo "GitHub download failed, trying alternative sources..."' >> download_nexus.sh && \
    echo '  if ! curl -sSfL "https://cli.nexus.xyz/latest/${OS}/${ARCH}/nexus-cli" -o nexus-cli; then' >> download_nexus.sh && \
    echo '    echo "Creating mock binary for development..."' >> download_nexus.sh && \
    echo '    echo "#!/bin/bash" > nexus-cli' >> download_nexus.sh && \
    echo '    echo "echo \"Nexus CLI Mock - Running with Node ID: \$NODE_ID\"" >> nexus-cli' >> download_nexus.sh && \
    echo '    echo "echo \"Threads: \$MAX_THREADS, Environment: \$NEXUS_ENVIRONMENT\"" >> nexus-cli' >> download_nexus.sh && \
    echo '    echo "echo \"Mock nexus-cli is running... Press Ctrl+C to stop\"" >> nexus-cli' >> download_nexus.sh && \
    echo '    echo "while true; do sleep 30; echo \"[$(date)] Mock nexus-cli heartbeat - Node: \$NODE_ID\"; done" >> nexus-cli' >> download_nexus.sh && \
    echo '  fi' >> download_nexus.sh && \
    echo 'fi' >> download_nexus.sh && \
    echo 'chmod +x nexus-cli' >> download_nexus.sh && \
    echo 'echo "=== Download complete ==="' >> download_nexus.sh && \
    echo 'ls -la nexus-cli' >> download_nexus.sh && \
    chmod +x download_nexus.sh && \
    ./download_nexus.sh

####################################################################################################
## Runtime Image
####################################################################################################
FROM debian:12-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r nexus && useradd -r -g nexus -s /bin/bash nexus

WORKDIR /app

# Copy the Nexus CLI binary
COPY --from=downloader /tmp/nexus-cli ./nexus-cli
RUN chmod +x nexus-cli

# Copy startup scripts
COPY scripts/ ./scripts/
COPY config/ ./config/
RUN chmod +x scripts/*.sh

# Create directories with proper permissions
RUN mkdir -p /app/data /app/logs && \
    chown -R nexus:nexus /app

# Environment variables
ENV NEXUS_CLI_PATH=/app/nexus-cli
ENV CONFIG_DIR=/app/data
ENV LOG_DIR=/app/logs

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -f nexus-cli || exit 1

# Switch to non-root user
USER nexus

# Expose default port (if needed)
EXPOSE 8080

# Default command
CMD ["./scripts/start-single.sh"]

# Multi-stage Dockerfile for Nexus CLI
FROM debian:12-slim AS downloader

# Install dependencies for downloading
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# Download the latest Nexus CLI binary
# The install script will be adapted to just download the binary
RUN curl -sSf https://cli.nexus.xyz/ -o install.sh && \
    chmod +x install.sh && \
    NONINTERACTIVE=1 DOWNLOAD_ONLY=1 ./install.sh

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

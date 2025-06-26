# Nexus CLI Docker Web Manager
FROM python:3.11-alpine

# Install Docker CLI and system dependencies
RUN apk add --no-cache \
    docker-cli \
    curl \
    bash \
    && rm -rf /var/cache/apk/*

# Create app user
RUN addgroup -g 1001 appgroup && \
    adduser -D -u 1001 -G appgroup appuser

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY app/ ./app/
COPY static/ ./static/
COPY templates/ ./templates/
COPY scripts/ ./scripts/

# Make scripts executable
RUN chmod +x scripts/*.sh

# Set permissions
RUN chown -R appuser:appgroup /app

# Environment variables
ENV FLASK_APP=app.main:app
ENV FLASK_ENV=production
ENV PYTHONPATH=/app

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

USER appuser

EXPOSE 5000

CMD ["python", "-m", "gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "--timeout", "120", "app.main:app"]

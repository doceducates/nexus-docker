#!/bin/bash
set -e

echo "Starting Nexus Web Manager..."

# Check if Docker socket is accessible
if [ ! -S /var/run/docker.sock ]; then
    echo "Error: Docker socket not found. Make sure to mount /var/run/docker.sock"
    exit 1
fi

# Test Docker access
docker info >/dev/null 2>&1 || {
    echo "Error: Cannot access Docker daemon. Check permissions."
    exit 1
}

# Start the Flask application
exec python -m gunicorn \
    --bind 0.0.0.0:5000 \
    --workers 4 \
    --timeout 120 \
    --access-logfile - \
    --error-logfile - \
    app.main:app

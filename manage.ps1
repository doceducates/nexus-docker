# Nexus Docker Manager - PowerShell Startup Script
# This script builds and starts the web management interface

param(
    [Parameter(Position=0)]
    [ValidateSet("build", "start", "stop", "status", "restart", "logs")]
    [string]$Action = "start"
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ComposeFile = Join-Path $ProjectRoot "compose\docker-compose-manager.yml"

Write-Host "=== Nexus Docker Manager Setup ===" -ForegroundColor Cyan
Write-Host "Project Root: $ProjectRoot" -ForegroundColor Gray
Write-Host "Compose File: $ComposeFile" -ForegroundColor Gray
Write-Host

# Function to build the Nexus CLI base image
function Build-NexusImage {
    Write-Host "Building Nexus CLI base image..." -ForegroundColor Yellow
    Set-Location $ProjectRoot
    docker build -f docker/Dockerfile -t nexus-cli:latest docker/
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Nexus CLI image built successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to build Nexus CLI image" -ForegroundColor Red
        exit 1
    }
}

# Function to start the web manager
function Start-WebManager {
    Write-Host "Starting Web Manager..." -ForegroundColor Yellow
    Set-Location (Join-Path $ProjectRoot "compose")
    docker-compose -f docker-compose-manager.yml up -d web-manager
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Web Manager started successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to start Web Manager" -ForegroundColor Red
        exit 1
    }
}

# Function to show status
function Show-Status {
    Write-Host "=== Container Status ===" -ForegroundColor Cyan
    Set-Location (Join-Path $ProjectRoot "compose")
    docker-compose -f docker-compose-manager.yml ps
    Write-Host
    Write-Host "=== Web Manager Logs (last 10 lines) ===" -ForegroundColor Cyan
    docker-compose -f docker-compose-manager.yml logs --tail=10 web-manager
}

# Function to stop all services
function Stop-Services {
    Write-Host "Stopping all services..." -ForegroundColor Yellow
    Set-Location (Join-Path $ProjectRoot "compose")
    docker-compose -f docker-compose-manager.yml down
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Services stopped" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to stop services" -ForegroundColor Red
    }
}

# Main script logic
switch ($Action) {
    "build" {
        Build-NexusImage
    }
    "start" {
        Write-Host "Building Nexus CLI image..." -ForegroundColor Yellow
        Build-NexusImage
        Write-Host
        Start-WebManager
        Write-Host
        Show-Status
        Write-Host
        Write-Host "🚀 Nexus Docker Manager is ready!" -ForegroundColor Green
        Write-Host "   Web Interface: http://localhost:5000" -ForegroundColor Cyan
        Write-Host "   Use 'docker logs nexus-web-manager' to view logs" -ForegroundColor Gray
        Write-Host "   Use '.\manage.ps1 stop' to stop all services" -ForegroundColor Gray
    }
    "stop" {
        Stop-Services
    }
    "status" {
        Show-Status
    }
    "restart" {
        Stop-Services
        Write-Host
        Build-NexusImage
        Write-Host
        Start-WebManager
        Write-Host
        Show-Status
    }
    "logs" {
        Set-Location (Join-Path $ProjectRoot "compose")
        docker-compose -f docker-compose-manager.yml logs -f web-manager
    }
}

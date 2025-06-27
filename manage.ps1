# Nexus CLI Manager - Simplified PowerShell Launcher
# Handles basic operations and delegates complex tasks to Python

param(
    [Parameter(Position=0)]
    [ValidateSet("setup", "start", "stop", "status", "logs", "standalone", "docker", "help")]
    [string]$Action = "help",
    
    [Parameter()]
    [switch]$DebugMode,
    
    [Parameter()]
    [int]$Port = 5000,
    
    [Parameter()]
    [string]$HostAddress = "127.0.0.1",
    
    [Parameter()]
    [switch]$Build,
    
    [Parameter()]
    [switch]$Upgrade,
    
    [Parameter()]
    [switch]$Background
)

$ProjectRoot = $PSScriptRoot
$WebManagerDir = Join-Path $ProjectRoot "web-manager"
$SetupScript = Join-Path $ProjectRoot "setup.py"

# Simple color functions
function Write-Success { 
    param([string]$Message) 
    Write-Host "✓ $Message" -ForegroundColor Green 
}

function Write-Error { 
    param([string]$Message) 
    Write-Host "✗ $Message" -ForegroundColor Red 
}

function Write-Warning { 
    param([string]$Message) 
    Write-Host "⚠ $Message" -ForegroundColor Yellow 
}

function Write-Info { 
    param([string]$Message) 
    Write-Host "ℹ $Message" -ForegroundColor Cyan 
}

function Show-Header {
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "          Nexus CLI Manager - Python Edition         " -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "Project Root: $ProjectRoot" -ForegroundColor Gray
    Write-Host ""
}

function Show-Help {
    Write-Host "Nexus CLI Manager - Simplified PowerShell Launcher" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Green
    Write-Host "  .\manage.ps1 <action> [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "ACTIONS:" -ForegroundColor Green
    Write-Host "  setup       Run Python setup script (install dependencies, etc.)" -ForegroundColor White
    Write-Host "  standalone  Start web manager in standalone mode" -ForegroundColor White
    Write-Host "  docker      Start web manager in Docker mode" -ForegroundColor White
    Write-Host "  stop        Stop running services" -ForegroundColor White
    Write-Host "  status      Show service status" -ForegroundColor White
    Write-Host "  logs        Show service logs" -ForegroundColor White
    Write-Host "  help        Show this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "OPTIONS:" -ForegroundColor Green
    Write-Host "  -DebugMode    Enable debug mode" -ForegroundColor White
    Write-Host "  -Port         Port to use (default: 5000)" -ForegroundColor White
    Write-Host "  -HostAddress  Host to bind to (default: 127.0.0.1)" -ForegroundColor White
    Write-Host "  -Build        Build Docker images during setup" -ForegroundColor White
    Write-Host "  -Upgrade      Upgrade dependencies during setup" -ForegroundColor White
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Green
    Write-Host "  .\manage.ps1 setup                        # Initial setup" -ForegroundColor Cyan
    Write-Host "  .\manage.ps1 setup -Build                 # Setup with Docker images" -ForegroundColor Cyan
    Write-Host "  .\manage.ps1 standalone                   # Run standalone mode" -ForegroundColor Cyan
    Write-Host "  .\manage.ps1 standalone -DebugMode -Port 8080 # Debug mode on port 8080" -ForegroundColor Cyan
    Write-Host "  .\manage.ps1 docker                       # Run Docker mode" -ForegroundColor Cyan
}

function Test-Python {
    try {
        $pythonVersion = python --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Python available: $pythonVersion"
            return $true
        }
    } catch {
        # Try python3
        try {
            $pythonVersion = python3 --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Python available: $pythonVersion"
                $script:PythonCmd = "python3"
                return $true
            }
        } catch {
            Write-Error "Python not found. Please install Python 3.8+ from https://python.org"
            return $false
        }
    }
    Write-Error "Python not found. Please install Python 3.8+ from https://python.org"
    return $false
}

function Invoke-Setup {
    Write-Info "Running Python setup script..."
    
    $setupArgs = @()
    if ($Build) { $setupArgs += "--build" }
    if ($Upgrade) { $setupArgs += "--upgrade" }
    if ($DebugMode) { $setupArgs += "--debug" }
    
    & python $SetupScript @setupArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Setup completed successfully!"
        return $true
    } else {
        Write-Error "Setup failed with exit code $LASTEXITCODE"
        return $false
    }
}

function Start-Standalone {
    Write-Info "Starting standalone web manager..."
    
    $LaunchScript = Join-Path $WebManagerDir "launch.py"
    if (-not (Test-Path $LaunchScript)) {
        Write-Error "Launch script not found: $LaunchScript"
        return $false
    }
    
    $launchArgs = @("--port", $Port, "--host", $HostAddress)
    if ($DebugMode) {
        $launchArgs += "--debug"
    }
    
    Write-Info "Starting on http://$HostAddress`:$Port"
    & python $LaunchScript @launchArgs
}

function Start-Docker {
    Write-Info "Starting Docker web manager..."
    
    $ComposeFile = Join-Path $ProjectRoot "compose" "docker-compose-manager.yml"
    if (-not (Test-Path $ComposeFile)) {
        Write-Error "Docker Compose file not found: $ComposeFile"
        return $false
    }
    
    $env:WEB_MANAGER_PORT = $Port
    if ($DebugMode) {
        $env:DEBUG_MODE = "true"
    }
    
    Write-Info "Starting Docker containers..."
    & docker-compose -f $ComposeFile up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker containers started successfully!"
        Write-Info "Web manager available at http://localhost:$Port"
    } else {
        Write-Error "Failed to start Docker containers"
    }
}

function Stop-Services {
    Write-Info "Stopping services..."
    
    # Stop Docker containers
    $ComposeFile = Join-Path $ProjectRoot "compose" "docker-compose-manager.yml"
    if (Test-Path $ComposeFile) {
        & docker-compose -f $ComposeFile down
    }
    
    Write-Success "Services stopped"
}

function Show-Status {
    Write-Info "Service Status:"
    
    # Check Docker containers
    $ComposeFile = Join-Path $ProjectRoot "compose" "docker-compose-manager.yml"
    if (Test-Path $ComposeFile) {
        & docker-compose -f $ComposeFile ps
    }
}

function Show-Logs {
    Write-Info "Service Logs:"
    
    # Show Docker logs
    $ComposeFile = Join-Path $ProjectRoot "compose" "docker-compose-manager.yml"
    if (Test-Path $ComposeFile) {
        & docker-compose -f $ComposeFile logs --tail=50 -f
    }
}

# Main execution
Show-Header

# Test Python availability
if (-not (Test-Python)) {
    exit 1
}

# Execute action
switch ($Action.ToLower()) {
    "setup" {
        if (-not (Invoke-Setup)) {
            exit 1
        }
    }
    "standalone" {
        Start-Standalone
    }
    "docker" {
        Start-Docker
    }
    "stop" {
        Stop-Services
    }
    "status" {
        Show-Status
    }
    "logs" {
        Show-Logs
    }
    "help" {
        Show-Help
    }
    default {
        Write-Warning "Unknown action: $Action"
        Show-Help
        exit 1
    }
}

Write-Success "Operation completed successfully!"

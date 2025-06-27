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
    [switch]$Upgrade
)

$ProjectRoot = $PSScriptRoot
$WebManagerDir = Join-Path $ProjectRoot "web-manager"
$SetupScript = Join-Path $ProjectRoot "setup.py"

# Simple color functions
function Write-Success { param($Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Error { param($Message) Write-Host "✗ $Message" -ForegroundColor Red }
function Write-Warning { param($Message) Write-Host "⚠ $Message" -ForegroundColor Yellow }
function Write-Info { param($Message) Write-Host "ℹ $Message" -ForegroundColor Cyan }

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
    Write-Host "  -DebugMode  Enable debug mode" -ForegroundColor White
    Write-Host "  -Port       Port to use (default: 5000)" -ForegroundColor White
    Write-Host "  -HostAddress  Host to bind to (default: 127.0.0.1)" -ForegroundColor White
    Write-Host "  -Build      Build Docker images during setup" -ForegroundColor White
    Write-Host "  -Upgrade    Upgrade dependencies during setup" -ForegroundColor White
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

function Run-Setup {
    Write-Info "Running Python setup script..."
    
    $args = @()
    if ($Build) { $args += "--build-images" }
    if ($Upgrade) { $args += "--upgrade" }
    
    $pythonCmd = if ($script:PythonCmd) { $script:PythonCmd } else { "python" }
    & $pythonCmd $SetupScript @args
    
    return $LASTEXITCODE -eq 0
}

function Start-Standalone {
    Write-Info "Starting standalone web manager..."
    
    # Check if launch.py exists
    $launchScript = Join-Path $WebManagerDir "launch.py"
    if (-not (Test-Path $launchScript)) {
        Write-Error "Launch script not found. Run setup first: .\manage.ps1 setup"
        return $false
    }
    
    Push-Location $WebManagerDir
    try {
        $env:DEBUG = $Debug.ToString().ToLower()
        
        $args = @()
        if ($Debug) { $args += "--debug" }
        $args += "--host", $HostAddress
        $args += "--port", $Port
        
        Write-Success "Starting web manager..."
        Write-Host "  Mode: $(if ($Debug) { 'Development' } else { 'Production' })" -ForegroundColor Gray
        Write-Host "  URL: http://${Host}:${Port}" -ForegroundColor Gray
        Write-Host ""
        Write-Warning "Press Ctrl+C to stop the server"
        Write-Host ""
        
        $pythonCmd = if ($script:PythonCmd) { $script:PythonCmd } else { "python" }
        & $pythonCmd launch.py @args
        
        return $true
    } finally {
        Pop-Location
    }
}

function Start-Docker {
    Write-Info "Starting Docker web manager..."
    
    # Check if Docker is available
    try {
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Docker not found. Please install Docker Desktop"
            return $false
        }
        Write-Success "Docker available: $dockerVersion"
    } catch {
        Write-Error "Docker not found. Please install Docker Desktop"
        return $false
    }
    
    $composeFile = Join-Path $ProjectRoot "compose\docker-compose-manager.yml"
    if (-not (Test-Path $composeFile)) {
        Write-Error "Docker compose file not found: $composeFile"
        return $false
    }
    
    Push-Location (Join-Path $ProjectRoot "compose")
    try {
        Write-Info "Starting Docker services..."
        docker-compose -f docker-compose-manager.yml up -d web-manager
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker services started"
            Write-Host ""
            Write-Info "Web manager available at: http://localhost:5000"
            Write-Info "View logs: .\manage.ps1 logs"
            Write-Info "Stop services: .\manage.ps1 stop"
            return $true
        } else {
            Write-Error "Failed to start Docker services"
            return $false
        }
    } finally {
        Pop-Location
    }
}

function Stop-Services {
    Write-Info "Stopping services..."
    
    # Try to stop Docker services
    try {
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Push-Location (Join-Path $ProjectRoot "compose")
            try {
                docker-compose -f docker-compose-manager.yml down
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Docker services stopped"
                } else {
                    Write-Warning "Some issues stopping Docker services"
                }
            } finally {
                Pop-Location
            }
        }
    } catch {
        Write-Warning "Docker not available"
    }
    
    # Try to stop standalone processes
    $pythonProcesses = Get-Process python -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -eq "python" -and $_.CommandLine -like "*launch.py*"
    }
    
    if ($pythonProcesses) {
        Write-Info "Stopping standalone processes..."
        $pythonProcesses | Stop-Process -Force
        Write-Success "Standalone processes stopped"
    }
}

function Show-Status {
    Write-Info "Checking service status..."
    
    # Check Docker services
    try {
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "=== Docker Services ===" -ForegroundColor Yellow
            Push-Location (Join-Path $ProjectRoot "compose")
            try {
                docker-compose -f docker-compose-manager.yml ps
            } finally {
                Pop-Location
            }
        }
    } catch {
        Write-Warning "Docker not available"
    }
    
    # Check standalone processes
    $pythonProcesses = Get-Process python -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -eq "python"
    }
    
    if ($pythonProcesses) {
        Write-Host ""
        Write-Host "=== Python Processes ===" -ForegroundColor Yellow
        $pythonProcesses | Format-Table Id, ProcessName, CPU, WorkingSet -AutoSize
    }
}

function Show-Logs {
    Write-Info "Showing logs..."
    
    try {
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Push-Location (Join-Path $ProjectRoot "compose")
            try {
                docker-compose -f docker-compose-manager.yml logs -f web-manager
            } finally {
                Pop-Location
            }
        } else {
            Write-Warning "Docker not available - no centralized logs for standalone mode"
        }
    } catch {
        Write-Warning "Docker not available - no centralized logs for standalone mode"
    }
}

# Main execution
Show-Header

# Set default Python command
$script:PythonCmd = "python"

# Test Python availability
if (-not (Test-Python)) {
    exit 1
}

# Execute action
switch ($Action.ToLower()) {
    "help" { 
        Show-Help 
    }
    "setup" {
        $success = Run-Setup
        if (-not $success) { 
            Write-Error "Setup failed"
            exit 1 
        }
    }
    "standalone" {
        $success = Start-Standalone
        if (-not $success) { exit 1 }
    }
    "docker" {
        $success = Start-Docker
        if (-not $success) { exit 1 }
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
    default {
        Write-Error "Unknown action: $Action"
        Show-Help
        exit 1
    }
}

Write-Host ""
Write-Success "Operation completed successfully!"

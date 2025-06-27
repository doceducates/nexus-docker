@echo off
REM Nexus CLI Manager - Windows Launcher
REM This script provides an easy way to start the Nexus CLI Manager on Windows

echo ===============================================
echo   Nexus CLI Manager - Windows Launcher
echo ===============================================
echo.

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.8 or later from https://python.org
    echo.
    pause
    exit /b 1
)

REM Get the directory where this script is located
set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"

REM Check if launch.py exists
if not exist "launch.py" (
    echo ERROR: launch.py not found in current directory
    echo Please make sure you're running this from the web-manager directory
    echo.
    pause
    exit /b 1
)

REM Parse command line arguments
set DEBUG_MODE=
set PORT=5000
set HOST=127.0.0.1
set INSTALL_ONLY=
set CHECK_ONLY=

:parse_args
if "%1"=="" goto :args_done
if /i "%1"=="--debug" set DEBUG_MODE=--debug
if /i "%1"=="--port" (
    shift
    set PORT=%1
)
if /i "%1"=="--host" (
    shift
    set HOST=%1
)
if /i "%1"=="--install" set INSTALL_ONLY=--install
if /i "%1"=="--check" set CHECK_ONLY=--check
if /i "%1"=="--help" goto :show_help
if /i "%1"=="-h" goto :show_help
shift
goto :parse_args

:args_done

REM Show help if requested
if defined INSTALL_ONLY goto :install_only
if defined CHECK_ONLY goto :check_only

echo Starting Nexus CLI Manager...
echo.
echo Configuration:
echo   Host: %HOST%
echo   Port: %PORT%
if defined DEBUG_MODE (
    echo   Mode: Debug
) else (
    echo   Mode: Production
)
echo.

REM Run the application
python launch.py %DEBUG_MODE% --host %HOST% --port %PORT%
if errorlevel 1 (
    echo.
    echo ERROR: Failed to start Nexus CLI Manager
    echo.
    pause
    exit /b 1
)

goto :end

:install_only
echo Installing Python dependencies...
echo.
python launch.py --install
if errorlevel 1 (
    echo.
    echo ERROR: Failed to install dependencies
    echo.
    pause
    exit /b 1
) else (
    echo.
    echo Dependencies installed successfully!
    echo You can now run: nexus-manager.bat
    echo.
    pause
)
goto :end

:check_only
echo Checking system requirements...
echo.
python launch.py --check
pause
goto :end

:show_help
echo.
echo Usage: nexus-manager.bat [options]
echo.
echo Options:
echo   --debug         Run in debug mode with auto-reload
echo   --port PORT     Port to listen on (default: 5000)
echo   --host HOST     Host to bind to (default: 127.0.0.1)
echo   --install       Install Python dependencies only
echo   --check         Check system requirements only
echo   --help, -h      Show this help message
echo.
echo Examples:
echo   nexus-manager.bat                    Start with default settings
echo   nexus-manager.bat --debug           Start in debug mode
echo   nexus-manager.bat --port 8080       Start on port 8080
echo   nexus-manager.bat --host 0.0.0.0    Listen on all interfaces
echo   nexus-manager.bat --install         Install dependencies
echo.
pause
goto :end

:end
exit /b 0

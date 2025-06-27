#!/usr/bin/env python3
"""
Nexus CLI Manager - Standalone Launcher
Runs the web management interface independently without Docker
"""

import os
import sys
import argparse
import subprocess
import platform
from pathlib import Path

def check_requirements():
    """Check if all requirements are installed"""
    try:
        import flask
        import psutil
        print("✓ Flask and required packages are available")
        return True
    except ImportError as e:
        print(f"✗ Missing required packages: {e}")
        return False

def install_requirements():
    """Install required packages"""
    requirements_file = Path(__file__).parent / "requirements.txt"
    if requirements_file.exists():
        print("Installing requirements...")
        subprocess.run([sys.executable, "-m", "pip", "install", "-r", str(requirements_file)], check=True)
        print("✓ Requirements installed")
    else:
        print("Installing basic requirements...")
        subprocess.run([sys.executable, "-m", "pip", "install", "flask", "psutil", "flask-socketio"], check=True)
        print("✓ Basic requirements installed")

def setup_environment(debug=False, port=5000, host="127.0.0.1"):
    """Setup environment variables"""
    os.environ.setdefault("FLASK_APP", "app.main")
    os.environ.setdefault("FLASK_ENV", "development" if debug else "production")
    os.environ.setdefault("SECRET_KEY", "nexus-standalone-secret-key")
    os.environ.setdefault("DEBUG", str(debug).lower())
    os.environ.setdefault("PORT", str(port))
    os.environ.setdefault("HOST", host)
    
    # Disable Docker features when running standalone
    os.environ.setdefault("DOCKER_AVAILABLE", "false")
    
    print(f"✓ Environment configured for {'development' if debug else 'production'}")

def check_nexus_cli():
    """Check if Nexus CLI is available"""
    try:
        result = subprocess.run(["nexus", "--version"], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            print("✓ Nexus CLI is available for native deployments")
            return True
        else:
            print("⚠ Nexus CLI not found - native deployments will be disabled")
            return False
    except (subprocess.TimeoutExpired, FileNotFoundError):
        print("⚠ Nexus CLI not found - native deployments will be disabled")
        return False

def check_docker():
    """Check if Docker is available"""
    try:
        result = subprocess.run(["docker", "--version"], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            print("✓ Docker is available for container deployments")
            return True
        else:
            print("⚠ Docker not found - container deployments will be disabled")
            return False
    except (subprocess.TimeoutExpired, FileNotFoundError):
        print("⚠ Docker not found - container deployments will be disabled")
        return False

def run_server(debug=False, port=5000, host="127.0.0.1"):
    """Run the Flask development server"""
    app_dir = Path(__file__).parent / "app"
    os.chdir(app_dir.parent)
    
    if debug:
        # Use Flask's built-in development server
        from app.main import app, socketio
        socketio.run(app, debug=True, host=host, port=port, allow_unsafe_werkzeug=True)
    else:
        # Use Gunicorn for production
        try:
            import gunicorn
            cmd = [
                sys.executable, "-m", "gunicorn",
                "--bind", f"{host}:{port}",
                "--workers", "1",
                "--worker-class", "eventlet",
                "--timeout", "120",
                "--worker-connections", "1000",
                "app.main:app"
            ]
            subprocess.run(cmd, check=True)
        except ImportError:
            print("Gunicorn not available, falling back to Flask development server")
            from app.main import app, socketio
            socketio.run(app, debug=False, host=host, port=port)

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Nexus CLI Manager - Standalone Web Interface",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python launch.py                    # Run with default settings
  python launch.py --debug           # Run in debug mode
  python launch.py --port 8080       # Run on port 8080
  python launch.py --host 0.0.0.0    # Listen on all interfaces
  python launch.py --install         # Install requirements and exit
        """
    )
    
    parser.add_argument("--debug", action="store_true", help="Run in debug mode")
    parser.add_argument("--port", type=int, default=5000, help="Port to listen on (default: 5000)")
    parser.add_argument("--host", default="127.0.0.1", help="Host to bind to (default: 127.0.0.1)")
    parser.add_argument("--install", action="store_true", help="Install requirements and exit")
    parser.add_argument("--check", action="store_true", help="Check system requirements and exit")
    
    args = parser.parse_args()
    
    print("=== Nexus CLI Manager - Standalone Launcher ===")
    print(f"Platform: {platform.system()} {platform.release()}")
    print(f"Python: {sys.version}")
    print()
    
    # Install requirements if requested
    if args.install:
        install_requirements()
        return
    
    # Check system requirements
    print("Checking system requirements...")
    nexus_available = check_nexus_cli()
    docker_available = check_docker()
    
    if not check_requirements():
        print("\nMissing required Python packages. Install them with:")
        print(f"  {sys.executable} -m pip install -r requirements.txt")
        print("Or run with --install flag to install automatically")
        return 1
    
    if args.check:
        print("\nSystem check complete.")
        return 0
    
    # Setup environment
    setup_environment(debug=args.debug, port=args.port, host=args.host)
    
    # Display startup information
    print(f"\nStarting Nexus CLI Manager...")
    print(f"Mode: {'Development' if args.debug else 'Production'}")
    print(f"URL: http://{args.host}:{args.port}")
    print(f"Native deployments: {'Enabled' if nexus_available else 'Disabled'}")
    print(f"Docker deployments: {'Enabled' if docker_available else 'Disabled'}")
    print()
    
    if not nexus_available and not docker_available:
        print("⚠ Warning: No deployment methods available!")
        print("  Install Nexus CLI for native deployments or Docker for container deployments")
        print()
    
    print("Press Ctrl+C to stop the server")
    print("=" * 50)
    
    try:
        # Run the server
        run_server(debug=args.debug, port=args.port, host=args.host)
    except KeyboardInterrupt:
        print("\nShutting down...")
    except Exception as e:
        print(f"Error starting server: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())

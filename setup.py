#!/usr/bin/env python3
"""
Nexus CLI Manager Setup Script
Handles installation, dependency management, and system configuration
"""

import os
import sys
import subprocess
import platform
import shutil
import json
import argparse
from pathlib import Path
from typing import Dict, List, Optional, Tuple

class NexusSetup:
    def __init__(self, project_root: str = None):
        self.project_root = Path(project_root or os.path.dirname(os.path.abspath(__file__)))
        self.web_manager_dir = self.project_root / "web-manager"
        self.requirements_file = self.web_manager_dir / "requirements.txt"
        self.system = platform.system().lower()
        
        # Colors for console output
        self.colors = {
            'RED': '\033[91m',
            'GREEN': '\033[92m',
            'YELLOW': '\033[93m',
            'BLUE': '\033[94m',
            'CYAN': '\033[96m',
            'WHITE': '\033[97m',
            'RESET': '\033[0m',
            'BOLD': '\033[1m'
        }
        
    def print_colored(self, text: str, color: str = 'WHITE'):
        """Print colored text to console"""
        if self.system == 'windows':
            # Windows may not support ANSI colors in all terminals
            print(text)
        else:
            print(f"{self.colors.get(color, '')}{text}{self.colors['RESET']}")
    
    def print_success(self, text: str):
        self.print_colored(f"✓ {text}", 'GREEN')
    
    def print_error(self, text: str):
        self.print_colored(f"✗ {text}", 'RED')
    
    def print_warning(self, text: str):
        self.print_colored(f"⚠ {text}", 'YELLOW')
    
    def print_info(self, text: str):
        self.print_colored(f"ℹ {text}", 'CYAN')
    
    def print_header(self, text: str):
        self.print_colored(f"\n{'='*60}", 'CYAN')
        self.print_colored(f"  {text}", 'CYAN')
        self.print_colored(f"{'='*60}", 'CYAN')
    
    def run_command(self, cmd: List[str], capture_output: bool = True, check: bool = True) -> Tuple[bool, str, str]:
        """Run a system command and return success, stdout, stderr"""
        try:
            result = subprocess.run(
                cmd, 
                capture_output=capture_output, 
                text=True, 
                check=check,
                cwd=str(self.project_root)
            )
            return True, result.stdout, result.stderr
        except subprocess.CalledProcessError as e:
            return False, e.stdout or "", e.stderr or str(e)
        except FileNotFoundError:
            return False, "", f"Command not found: {cmd[0]}"
    
    def check_python_version(self) -> bool:
        """Check if Python version is compatible"""
        version = sys.version_info
        if version.major < 3 or (version.major == 3 and version.minor < 8):
            self.print_error(f"Python 3.8+ required, found {version.major}.{version.minor}")
            return False
        
        self.print_success(f"Python {version.major}.{version.minor}.{version.micro} detected")
        return True
    
    def check_pip(self) -> bool:
        """Check if pip is available"""
        success, _, _ = self.run_command([sys.executable, "-m", "pip", "--version"])
        if success:
            self.print_success("pip is available")
            return True
        else:
            self.print_error("pip not found")
            return False
    
    def check_docker(self) -> bool:
        """Check if Docker is available"""
        success, stdout, _ = self.run_command(["docker", "--version"], check=False)
        if success:
            self.print_success(f"Docker available: {stdout.strip()}")
            return True
        else:
            self.print_warning("Docker not found - Docker deployments will be disabled")
            return False
    
    def check_docker_compose(self) -> bool:
        """Check if Docker Compose is available"""
        # Try docker-compose first
        success, stdout, _ = self.run_command(["docker-compose", "--version"], check=False)
        if success:
            self.print_success(f"Docker Compose available: {stdout.strip()}")
            return True
        
        # Try docker compose (newer syntax)
        success, stdout, _ = self.run_command(["docker", "compose", "version"], check=False)
        if success:
            self.print_success(f"Docker Compose (v2) available: {stdout.strip()}")
            return True
        
        self.print_warning("Docker Compose not found - Compose deployments will be disabled")
        return False
    
    def check_nexus_cli(self) -> bool:
        """Check if Nexus CLI is available"""
        success, stdout, _ = self.run_command(["nexus", "--version"], check=False)
        if success:
            self.print_success(f"Nexus CLI available: {stdout.strip()}")
            return True
        else:
            self.print_warning("Nexus CLI not found - Native deployments will be limited")
            return False
    
    def check_system_requirements(self) -> Dict[str, bool]:
        """Check all system requirements"""
        self.print_header("System Requirements Check")
        
        requirements = {
            'python': self.check_python_version() and self.check_pip(),
            'docker': self.check_docker(),
            'docker_compose': self.check_docker_compose(),
            'nexus_cli': self.check_nexus_cli()
        }
        
        print()
        if requirements['python']:
            self.print_success("Core requirements met - can run in standalone mode")
        else:
            self.print_error("Core requirements not met - please install Python 3.8+")
        
        return requirements
    
    def install_python_dependencies(self, upgrade: bool = False) -> bool:
        """Install Python dependencies"""
        self.print_header("Installing Python Dependencies")
        
        if not self.requirements_file.exists():
            self.print_error(f"Requirements file not found: {self.requirements_file}")
            return False
        
        cmd = [sys.executable, "-m", "pip", "install", "-r", str(self.requirements_file)]
        if upgrade:
            cmd.append("--upgrade")
        
        self.print_info("Installing from requirements.txt...")
        success, stdout, stderr = self.run_command(cmd, capture_output=False)
        
        if success:
            self.print_success("Python dependencies installed successfully")
            return True
        else:
            self.print_error("Failed to install Python dependencies")
            if stderr:
                print(stderr)
            return False
    
    def create_virtual_environment(self, venv_path: str = None) -> bool:
        """Create a Python virtual environment"""
        if not venv_path:
            venv_path = str(self.project_root / "venv")
        
        self.print_header("Creating Virtual Environment")
        self.print_info(f"Creating virtual environment at: {venv_path}")
        
        success, _, stderr = self.run_command([sys.executable, "-m", "venv", venv_path])
        
        if success:
            self.print_success("Virtual environment created")
            
            # Provide activation instructions
            if self.system == 'windows':
                activate_script = os.path.join(venv_path, "Scripts", "activate.bat")
                self.print_info(f"To activate: {activate_script}")
            else:
                activate_script = os.path.join(venv_path, "bin", "activate")
                self.print_info(f"To activate: source {activate_script}")
            
            return True
        else:
            self.print_error("Failed to create virtual environment")
            if stderr:
                print(stderr)
            return False
    
    def build_docker_images(self) -> bool:
        """Build Docker images"""
        self.print_header("Building Docker Images")
        
        # Build Nexus CLI base image
        self.print_info("Building Nexus CLI base image...")
        docker_dir = self.project_root / "docker"
        success, _, stderr = self.run_command([
            "docker", "build", "-f", str(docker_dir / "Dockerfile"), 
            "-t", "nexus-cli:latest", str(docker_dir)
        ])
        
        if not success:
            self.print_error("Failed to build Nexus CLI image")
            if stderr:
                print(stderr)
            return False
        
        self.print_success("Nexus CLI image built")
        
        # Build web manager image
        self.print_info("Building web manager image...")
        compose_dir = self.project_root / "compose"
        success, _, stderr = self.run_command([
            "docker-compose", "-f", str(compose_dir / "docker-compose-manager.yml"),
            "build", "web-manager"
        ], cwd=str(compose_dir))
        
        if not success:
            self.print_error("Failed to build web manager image")
            if stderr:
                print(stderr)
            return False
        
        self.print_success("Web manager image built")
        return True
    
    def create_config_files(self) -> bool:
        """Create default configuration files"""
        self.print_header("Creating Configuration Files")
        
        # Create .env file for Docker
        env_file = self.project_root / ".env"
        if not env_file.exists():
            env_content = """# Nexus CLI Manager Configuration
SECRET_KEY=nexus-docker-secret-key-change-me-in-production
DEBUG=false
WEB_MANAGER_PORT=5000
RESTART_POLICY=unless-stopped
COMPOSE_PROJECT_NAME=nexus-docker
"""
            with open(env_file, 'w') as f:
                f.write(env_content)
            self.print_success("Created .env configuration file")
        
        # Create launch configuration
        launch_config = self.web_manager_dir / "config.json"
        if not launch_config.exists():
            config = {
                "host": "127.0.0.1",
                "port": 5000,
                "debug": False,
                "secret_key": "nexus-standalone-secret-key",
                "log_level": "INFO"
            }
            with open(launch_config, 'w') as f:
                json.dump(config, f, indent=2)
            self.print_success("Created launch configuration file")
        
        return True
    
    def setup_project(self, 
                     create_venv: bool = False, 
                     install_deps: bool = True,
                     build_images: bool = False,
                     upgrade_deps: bool = False) -> bool:
        """Complete project setup"""
        
        self.print_colored(f"\n{'='*60}", 'BOLD')
        self.print_colored("  Nexus CLI Manager Setup", 'BOLD')
        self.print_colored(f"{'='*60}\n", 'BOLD')
        
        # Check requirements
        requirements = self.check_system_requirements()
        
        if not requirements['python']:
            self.print_error("Cannot proceed without Python 3.8+")
            return False
        
        # Create virtual environment if requested
        if create_venv:
            if not self.create_virtual_environment():
                return False
        
        # Install Python dependencies
        if install_deps:
            if not self.install_python_dependencies(upgrade=upgrade_deps):
                return False
        
        # Create configuration files
        if not self.create_config_files():
            return False
        
        # Build Docker images if requested and Docker is available
        if build_images and requirements['docker']:
            if not self.build_docker_images():
                return False
        
        # Summary
        self.print_header("Setup Complete")
        self.print_success("Nexus CLI Manager setup completed successfully!")
        
        print("\nAvailable deployment modes:")
        if requirements['python']:
            self.print_success("✓ Standalone mode (Python)")
        if requirements['docker']:
            self.print_success("✓ Docker mode")
        if requirements['docker_compose']:
            self.print_success("✓ Docker Compose mode")
        if requirements['nexus_cli']:
            self.print_success("✓ Native Nexus CLI deployments")
        
        print("\nNext steps:")
        self.print_info("1. Run standalone: python web-manager/launch.py")
        if requirements['docker']:
            self.print_info("2. Run Docker mode: docker-compose -f compose/docker-compose-manager.yml up -d")
        self.print_info("3. Open web interface: http://localhost:5000")
        
        return True

def main():
    parser = argparse.ArgumentParser(description="Nexus CLI Manager Setup")
    parser.add_argument("--venv", action="store_true", help="Create virtual environment")
    parser.add_argument("--no-deps", action="store_true", help="Skip dependency installation")
    parser.add_argument("--build-images", action="store_true", help="Build Docker images")
    parser.add_argument("--upgrade", action="store_true", help="Upgrade existing dependencies")
    parser.add_argument("--check-only", action="store_true", help="Only check requirements")
    
    args = parser.parse_args()
    
    setup = NexusSetup()
    
    if args.check_only:
        setup.check_system_requirements()
        return
    
    success = setup.setup_project(
        create_venv=args.venv,
        install_deps=not args.no_deps,
        build_images=args.build_images,
        upgrade_deps=args.upgrade
    )
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()

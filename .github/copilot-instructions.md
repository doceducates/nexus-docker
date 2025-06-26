<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

# Nexus Docker Project Instructions

This project provides Docker deployment solutions for the Nexus CLI with support for multiple node instances.

## Project Context

- **Technology Stack**: Docker, Docker Compose, Shell scripting, Kubernetes
- **Purpose**: Containerized deployment of Nexus CLI with multi-instance support
- **Target Environment**: Production and development Docker environments

## Code Style Guidelines

### Shell Scripts
- Use bash for all shell scripts
- Include proper error handling with `set -e`
- Use meaningful variable names and comments
- Include usage information and help text

### Docker Files
- Use multi-stage builds for optimization
- Minimize image layers
- Use specific version tags, not `latest`
- Include health checks where appropriate
- Follow security best practices (non-root user, minimal base images)

### Configuration Files
- Use environment variables for configuration
- Provide sensible defaults
- Include comprehensive comments
- Follow established naming conventions

## Architecture Principles

1. **Isolation**: Each node instance should be properly isolated
2. **Scalability**: Support both horizontal and vertical scaling
3. **Observability**: Include proper logging and monitoring
4. **Security**: Use security best practices for container deployment
5. **Simplicity**: Provide simple management interfaces

## File Organization

- `docker/`: Core Docker configurations and scripts
- `compose/`: Docker Compose files for different environments
- `k8s/`: Kubernetes deployment manifests
- `scripts/`: Management and utility scripts
- `docs/`: Comprehensive documentation

## Development Guidelines

- Test all Docker configurations in both single and multi-instance modes
- Ensure scripts work on different platforms (Linux, macOS, Windows with WSL)
- Include proper error handling and user feedback
- Document all configuration options and environment variables
- Provide clear examples and usage instructions

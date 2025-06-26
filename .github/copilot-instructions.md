<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

# Nexus Docker Project Instructions

This project provides Docker deployment solutions for the Nexus CLI with support for multiple node instances and web-based management.

## Project Context

- **Technology Stack**: Docker, Docker Compose, Shell scripting, Kubernetes, Python Flask, HTML/CSS/JavaScript
- **Purpose**: Containerized deployment of Nexus CLI with multi-instance support and web management interface
- **Target Environment**: Production and development Docker environments with web-based monitoring and control

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

### Python/Flask (Web Manager)
- Follow PEP 8 style guidelines
- Use type hints where appropriate
- Include proper error handling and logging
- Use Flask best practices for API design
- Implement proper security for Docker API access

### JavaScript/HTML/CSS
- Use modern ES6+ features
- Follow semantic HTML structure
- Use CSS Grid/Flexbox for layouts
- Implement responsive design principles
- Use vanilla JavaScript or minimal dependencies

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
6. **Web Management**: Centralized web-based container management with Docker-in-Docker support

## File Organization

- `docker/`: Core Docker configurations and scripts
- `compose/`: Docker Compose files for different environments
- `k8s/`: Kubernetes deployment manifests
- `scripts/`: Management and utility scripts
- `web-manager/`: Flask-based web management interface
- `docs/`: Comprehensive documentation

## Development Guidelines

- Test all Docker configurations in both single and multi-instance modes
- Ensure scripts work on different platforms (Linux, macOS, Windows with WSL)
- Include proper error handling and user feedback
- Document all configuration options and environment variables
- Provide clear examples and usage instructions
- Test web manager functionality with Docker-in-Docker scenarios
- Ensure web interface is responsive and user-friendly

## Web Manager Specifics

### Flask Application Structure
- `web-manager/app/main.py`: Main Flask application with Docker API integration
- `web-manager/templates/`: Jinja2 templates for web interface
- `web-manager/requirements.txt`: Python dependencies
- `web-manager/Dockerfile`: Container build for web manager

### Docker-in-Docker Integration
- Web manager runs with Docker socket mounted for container management
- Use Docker Python SDK for programmatic container control
- Implement proper error handling for Docker API calls
- Secure access to Docker daemon within container

### API Design
- RESTful endpoints for container operations (start, stop, logs, status)
- JSON responses for AJAX calls
- Real-time updates using polling or WebSockets
- Proper HTTP status codes and error messages

### Security Considerations
- Validate all user inputs for container operations
- Implement session management for web interface
- Secure Docker socket access patterns
- Rate limiting for API endpoints

<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

# Nexus CLI Manager Project Instructions

This project provides a comprehensive management solution for Nexus CLI deployments with support for multiple deployment modes, beautiful web interface, and flexible infrastructure options.

## Project Overview

**Vision**: A beautiful, user-friendly web application that can run independently or in Docker, capable of managing multiple Nexus CLI instances across different deployment modes.

### Core Features
- 🚀 **Multi-Mode Deployment**: Native host, Docker single/multi-instance, Docker Compose
- 🎨 **Modern Web UI**: Beautiful, responsive interface with real-time updates
- 📊 **System Monitoring**: Live metrics, resource usage, and health monitoring
- 🔧 **Instance Management**: Create, start, stop, and monitor Nexus CLI instances
- 📱 **Cross-Platform**: Works on Windows, Linux, macOS
- 🐳 **Docker Integration**: Full container lifecycle management
- 📝 **Comprehensive Logging**: Real-time log viewing and debugging

## Technology Stack

### Backend
- **Python 3.8+**: Core application runtime
- **Flask**: Web framework with RESTful API
- **Flask-SocketIO**: Real-time WebSocket communication
- **Docker Python SDK**: Container management
- **psutil**: System metrics and process monitoring
- **Gunicorn**: Production WSGI server

### Frontend
- **HTML5**: Semantic markup structure
- **Tailwind CSS**: Utility-first CSS framework
- **Alpine.js**: Lightweight reactive framework
- **Chart.js**: Data visualization and metrics
- **Font Awesome**: Icon library
- **Socket.IO Client**: Real-time communication

### Infrastructure
- **Docker & Docker Compose**: Containerization
- **Kubernetes**: Optional orchestration (k8s/ directory)
- **Shell Scripts**: Cross-platform automation
- **PowerShell**: Windows-specific management

## Architecture Principles

### 1. **Flexible Deployment**
- Support standalone execution without Docker dependencies
- Graceful degradation when components are unavailable
- Auto-detection of system capabilities

### 2. **Modular Design**
- Clear separation between deployment modes
- Pluggable architecture for new deployment types
- Independent frontend and backend components

### 3. **User Experience First**
- Intuitive step-by-step instance creation
- Real-time feedback and status updates
- Responsive design for all screen sizes
- Comprehensive error handling and messaging

### 4. **Production Ready**
- Proper security configurations
- Resource management and limits
- Health checks and monitoring
- Scalable architecture
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

## Project Structure

```
nexus-docker/
├── web-manager/                 # Main web application
│   ├── app/
│   │   └── main.py             # Flask application with unified manager
│   ├── templates/              # HTML templates (Jinja2)
│   │   ├── base.html          # Modern base template
│   │   ├── dashboard.html     # Real-time dashboard
│   │   ├── create.html        # Step-by-step instance creation
│   │   └── instances.html     # Instance management
│   ├── static/                # Static assets
│   ├── launch.py              # Standalone launcher
│   ├── nexus-manager.bat      # Windows launcher
│   ├── nexus-manager.sh       # Unix launcher
│   └── requirements.txt       # Python dependencies
├── compose/                    # Docker Compose configurations
│   ├── docker-compose-manager.yml  # Web manager deployment
│   ├── docker-compose.yml     # Main Nexus services
│   └── docker-compose.dev.yml # Development environment
├── docker/                    # Docker images
│   ├── Dockerfile             # Nexus CLI image
│   └── config/               # Configuration templates
├── k8s/                       # Kubernetes deployments
└── scripts/                   # Management scripts
```

## Code Style Guidelines

### Python (Flask Application)
- **Type Hints**: Use comprehensive type annotations
- **Error Handling**: Implement try-catch with specific exceptions
- **Logging**: Use app.logger for consistent logging
- **API Design**: RESTful endpoints with proper HTTP status codes
- **Async Support**: Use Flask-SocketIO for real-time features

```python
# Example: Proper method signature with type hints
def start_instance(self, mode: str, node_id: str, **kwargs) -> Dict[str, Any]:
    """Start an instance using the specified mode"""
    try:
        if mode == 'native':
            return self.start_native_instance(node_id, **kwargs)
        # ... implementation
    except Exception as e:
        app.logger.error(f"Failed to start instance {node_id}: {str(e)}")
        return {"success": False, "error": str(e)}
```

### Frontend (HTML/CSS/JS)
- **Alpine.js**: Use for reactive components and state management
- **Tailwind CSS**: Utility-first approach with custom components
- **Responsive Design**: Mobile-first with progressive enhancement
- **Accessibility**: Proper ARIA labels and semantic HTML

```html
<!-- Example: Proper Alpine.js component structure -->
<div x-data="instanceData()" x-init="init()">
    <template x-for="instance in instances" :key="instance.id">
        <div class="instance-card" :class="getStatusClass(instance.status)">
            <!-- Instance content -->
        </div>
    </template>
</div>
```

### Shell Scripts
- **Cross-Platform**: Support Windows (PowerShell/Batch) and Unix (Bash)
- **Error Handling**: Proper exit codes and error messages
- **User Feedback**: Clear progress indicators and status messages
- **Help Text**: Comprehensive usage information

```bash
# Example: Proper argument parsing and error handling
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG_MODE="--debug"
            shift
            ;;
        *)
            echo "ERROR: Unknown option $1"
            show_help
            exit 1
            ;;
    esac
done
```

### Docker Configuration
- **Multi-Stage Builds**: Optimize image size and security
- **Health Checks**: Implement proper container health monitoring
- **Security**: Non-root users, minimal attack surface
- **Environment Variables**: Configurable without rebuilding

```dockerfile
# Example: Proper Dockerfile structure
FROM python:3.11-alpine AS base
RUN addgroup -g 1001 appgroup && \
    adduser -D -u 1001 -G appgroup appuser

FROM base AS dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM dependencies AS runtime
USER appuser
COPY --chown=appuser:appgroup app/ ./app/
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:5000/api/health || exit 1
```

## Development Guidelines

### Instance Management Patterns
- **Unified Interface**: Single manager class handling all deployment modes
- **Graceful Degradation**: Disable features when dependencies unavailable
- **State Management**: Consistent instance state across all modes
- **Resource Monitoring**: Real-time metrics for all deployment types

### API Design Patterns
- **RESTful Endpoints**: Consistent URL structure and HTTP methods
- **Error Responses**: Standardized error format with details
- **WebSocket Events**: Real-time updates for UI synchronization
- **Authentication**: Secure API access (future enhancement)

```python
# Example: Standardized API response format
@app.route('/api/instances', methods=['POST'])
def api_create_instance():
    try:
        data = request.get_json()
        result = nexus_manager.start_instance(**data)
        
        if result['success']:
            socketio.emit('instance_created', result)
            return jsonify(result), 201
        else:
            return jsonify(result), 400
            
    except Exception as e:
        error_response = {"success": False, "error": str(e)}
        return jsonify(error_response), 500
```

### UI/UX Patterns
- **Progressive Disclosure**: Step-by-step workflows for complex tasks
- **Real-time Feedback**: Immediate response to user actions
- **Status Indicators**: Clear visual feedback for system state
- **Error Recovery**: Helpful error messages with suggested actions

## Testing Strategy

### Unit Tests
- **Manager Methods**: Test all deployment mode functions
- **API Endpoints**: Validate request/response handling
- **Error Conditions**: Test failure scenarios and edge cases

### Integration Tests
- **Docker Integration**: Test container lifecycle management
- **Native Process**: Test host process management
- **WebSocket Communication**: Test real-time update delivery

### Manual Testing Scenarios
1. **Fresh Installation**: Test first-time setup on clean system
2. **Capability Detection**: Verify proper handling of missing dependencies
3. **Multi-Mode Operation**: Test switching between deployment modes
4. **Resource Limits**: Test system behavior under resource constraints
5. **Error Recovery**: Test recovery from various failure scenarios

## Security Considerations

### Docker Socket Access
- **Principle of Least Privilege**: Minimal required permissions
- **Volume Binding**: Read-only mounts where possible
- **Network Isolation**: Proper container networking

### Web Interface Security
- **Input Validation**: Sanitize all user inputs
- **CSRF Protection**: Implement cross-site request forgery protection
- **Session Management**: Secure session handling
- **API Rate Limiting**: Prevent abuse of API endpoints

### Native Process Management
- **Process Isolation**: Proper sandboxing of native processes
- **Resource Limits**: Prevent resource exhaustion
- **Log Sanitization**: Clean sensitive data from logs

## Performance Optimization

### Frontend Performance
- **Lazy Loading**: Load components and data on demand
- **Efficient Updates**: Minimize DOM manipulation
- **Caching**: Cache static resources and API responses
- **Bundle Optimization**: Minimize JavaScript and CSS payload

### Backend Performance
- **Connection Pooling**: Efficient database/Docker connections
- **Async Operations**: Non-blocking I/O for better concurrency
- **Caching**: Cache expensive operations and API calls
- **Resource Monitoring**: Track and optimize resource usage

## Troubleshooting Guide

### Common Issues
1. **Port Conflicts**: Handle gracefully with clear error messages
2. **Permission Errors**: Provide specific guidance for resolution
3. **Missing Dependencies**: Clear instructions for installation
4. **Resource Exhaustion**: Guidance for resource management

### Debugging Tools
- **Comprehensive Logging**: Structured logging with appropriate levels
- **Health Endpoints**: API endpoints for system health checking
- **Diagnostic Commands**: Built-in tools for system diagnosis
- **Error Reporting**: Detailed error context and stack traces

When working on this project, prioritize user experience, system reliability, and code maintainability. Always consider the multi-platform nature and ensure features work across all supported deployment modes.
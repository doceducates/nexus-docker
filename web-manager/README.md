# Nexus CLI Manager

A beautiful, modern web interface for managing Nexus CLI instances across multiple deployment modes. This application can run independently or within Docker containers, supporting native host deployments, single Docker containers, multi-instance containers, and Docker Compose orchestration.

## Features

- 🚀 **Multiple Deployment Modes**: Native host, Docker single/multi-instance, Docker Compose
- 🎨 **Modern Web UI**: Beautiful, responsive interface built with Tailwind CSS and Alpine.js
- 📊 **Real-time Monitoring**: Live system metrics and instance status updates
- 🔧 **Easy Management**: Create, start, stop, and monitor Nexus CLI instances
- 📱 **Mobile Friendly**: Responsive design that works on all devices
- 🔄 **Auto-refresh**: Real-time updates via WebSocket connections
- 📝 **Comprehensive Logging**: View logs for all instances in real-time

## Deployment Options

### 1. Standalone (No Docker Required)

Run the web manager directly on your host system without Docker.

#### Quick Start

**Windows:**

```cmd
cd web-manager
nexus-manager.bat --install  # Install dependencies
nexus-manager.bat            # Start the application
```

**Linux/macOS:**

```bash
cd web-manager
./nexus-manager.sh --install  # Install dependencies
./nexus-manager.sh            # Start the application
```

**Python Direct:**

```bash
cd web-manager
python launch.py --install   # Install dependencies
python launch.py             # Start the application
```

#### Standalone Features

- ✅ Native Nexus CLI management (if Nexus CLI is installed)
- ✅ Docker container management (if Docker is available)
- ✅ System metrics monitoring
- ✅ Real-time updates
- ✅ Works without Docker dependencies

### 2. Docker Container (Recommended)

Run the web manager inside a Docker container with full Docker management capabilities.

```bash
# Build and start the web manager
docker-compose -f compose/docker-compose-manager.yml up -d web-manager

# Or use the PowerShell script
.\manage.ps1 start
```

#### Docker Features

- ✅ Full Docker container management
- ✅ Docker Compose orchestration
- ✅ Network isolation
- ✅ Volume management
- ✅ Built-in Nexus CLI image building

### 3. Development Environment

For development with hot reloading and debugging.

```bash
cd web-manager
python launch.py --debug    # Start in debug mode
# or
nexus-manager.bat --debug   # Windows
./nexus-manager.sh --debug  # Linux/macOS
```

## System Requirements

### Minimum Requirements

- Python 3.8 or later
- 2GB RAM
- 1GB disk space

### Optional Components

- **Nexus CLI**: For native host deployments
- **Docker**: For container deployments
- **Docker Compose**: For orchestrated deployments

### Supported Platforms

- Windows 10/11
- Linux (Ubuntu, CentOS, RHEL, etc.)
- macOS 10.15+

## Installation

### 1. Clone the Repository

```bash
git clone <repository-url>
cd nexus-docker
```

### 2. Choose Your Installation Method

#### Option A: Standalone Installation

```bash
cd web-manager
# Windows
nexus-manager.bat --install

# Linux/macOS
./nexus-manager.sh --install
```

#### Option B: Docker Installation

```bash
# Build the Docker images
docker-compose -f compose/docker-compose-manager.yml build

# Start the services
docker-compose -f compose/docker-compose-manager.yml up -d
```

### 3. Access the Web Interface

Open your browser and navigate to:

- **Standalone**: http://localhost:5000
- **Docker**: http://localhost:5000 (or the port specified in your compose file)

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SECRET_KEY` | auto-generated | Flask secret key for sessions |
| `DEBUG` | `false` | Enable debug mode |
| `PORT` | `5000` | Port to listen on |
| `HOST` | `127.0.0.1` | Host to bind to |
| `COMPOSE_PROJECT_NAME` | `nexus-docker` | Docker Compose project name |

### Standalone Configuration

Edit the configuration in `launch.py` or use command-line arguments:

```bash
python launch.py --help  # See all options
```

### Docker Configuration

Edit the environment variables in `compose/docker-compose-manager.yml`:

```yaml
environment:
  - SECRET_KEY=your-secret-key
  - DEBUG=false
  - WEB_MANAGER_PORT=5000
```

## Usage

### Creating Instances

1. Navigate to the **Create Instance** page
2. Choose your deployment mode:
   - **Native Host**: Run directly on the host system
   - **Single Docker Container**: One instance per container
   - **Multi-Instance Container**: Multiple instances in one container
   - **Docker Compose Stack**: Orchestrated deployment
3. Configure the instance parameters
4. Deploy and monitor

### Managing Instances

- **Dashboard**: Overview of all instances and system metrics
- **Instances**: Detailed view and management of all instances
- **Logs**: Real-time log viewing for debugging
- **Settings**: Application configuration

### Monitoring

The dashboard provides real-time monitoring of:

- System CPU and memory usage
- Instance status and resource consumption
- Network and disk I/O metrics
- Container health and uptime

## API Reference

The application provides a REST API for automation and integration:

### Endpoints

- `GET /api/capabilities` - Get system capabilities
- `GET /api/deployment-modes` - Get available deployment modes
- `GET /api/instances` - Get all instances
- `POST /api/instances` - Create a new instance
- `GET /api/instances/{id}/logs` - Get instance logs
- `POST /api/instances/{id}/start` - Start an instance
- `POST /api/instances/{id}/stop` - Stop an instance
- `GET /api/system-metrics` - Get system metrics
- `GET /api/health` - Health check

### WebSocket Events

- `connect` - Client connection
- `data_update` - Real-time data updates
- `notification` - System notifications

## Troubleshooting

### Common Issues

1. **Port Already in Use**

   ```bash
   # Change the port
   python launch.py --port 8080
   ```

2. **Docker Not Available**
   - Install Docker Desktop or Docker Engine
   - Ensure Docker daemon is running
   - Check user permissions for Docker access

3. **Nexus CLI Not Found**
   - Install Nexus CLI for native deployments
   - Add Nexus CLI to system PATH
   - Use Docker deployments as alternative

4. **Permission Errors (Linux/macOS)**

   ```bash
   # Make scripts executable
   chmod +x nexus-manager.sh
   chmod +x launch.py
   ```

### Logs and Debugging

**Standalone Mode:**

```bash
python launch.py --debug  # Enable debug mode
```

**Docker Mode:**

```bash
docker-compose -f compose/docker-compose-manager.yml logs -f web-manager
```

### Performance Tuning

For production deployments:

1. **Use Gunicorn** (automatically used in production mode)
2. **Set appropriate resource limits** in Docker
3. **Configure reverse proxy** (Nginx, Apache) for SSL and load balancing
4. **Monitor system resources** and scale as needed

## Development

### Setting up Development Environment

```bash
cd web-manager
python -m venv venv
source venv/bin/activate  # Linux/macOS
# or
venv\Scripts\activate     # Windows

pip install -r requirements.txt
python launch.py --debug
```

### Project Structure

```
web-manager/
├── app/
│   └── main.py          # Main Flask application
├── templates/           # HTML templates
├── static/             # Static assets (CSS, JS, images)
├── requirements.txt    # Python dependencies
├── launch.py          # Standalone launcher
├── nexus-manager.bat  # Windows launcher
└── nexus-manager.sh   # Unix launcher
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:

1. Check the troubleshooting section
2. Review the logs for error messages
3. Open an issue on GitHub
4. Check the API documentation for integration questions

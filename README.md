# Nexus Docker Management System

A comprehensive web-based management system for creating and managing Nexus CLI Docker containers dynamically.

## Features

� **Dynamic Container Creation**
- Create single-node containers (one Nexus CLI instance per container)
- Create multi-node containers (multiple Nexus CLI instances in one container)
- Real-time resource allocation and monitoring

�️ **Web Management Interface**
- Intuitive web UI for container management
- Real-time container status and metrics
- Container logs viewing
- Start/stop/restart/remove containers

📊 **Monitoring & Metrics**
- System resource monitoring (CPU, Memory, Disk)
- Container health checks
- Live container statistics

� **Flexible Configuration**
- Configurable resource limits (CPU, Memory)
- Custom thread allocation
- Environment-specific settings

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- PowerShell (Windows) or Bash (Linux/macOS)
- At least 4GB RAM available

### 1. Clone and Setup

```bash
git clone <repository-url>
cd nexus-docker
```

### 2. Start the Management System

**Windows (PowerShell):**
```powershell
.\manage.ps1 start
```

**Linux/macOS (Bash):**
```bash
chmod +x manage.sh
./manage.sh start
```

### 3. Access the Web Interface

Open your browser and navigate to: **http://localhost:5000**

## Usage Guide

### Creating Containers

The web interface provides two main options:

#### 1. Single Node Container
- **Use case**: Testing, development, or isolated deployments
- **Configuration**:
  - Node ID: Unique identifier for your Nexus node
  - CPU Threads: Number of threads (1-16)
  - Memory Limit: Container memory limit (1GB-8GB)
  - CPU Limit: CPU cores allocation (0.5-8)

#### 2. Multi-Node Container
- **Use case**: Production deployments with resource sharing
- **Configuration**:
  - Node IDs: Comma-separated list of node IDs
  - Total Threads: Total threads shared among all nodes
  - Memory Limit: Container memory limit (2GB-16GB)
  - CPU Limit: CPU cores allocation (1-16)

### Managing Containers

From the web interface, you can:
- **Start/Stop** containers
- **Restart** containers for updates
- **View logs** in real-time
- **Remove** unused containers
- **Monitor** resource usage

## Commands Reference

### Management Scripts

| Command | Description |
|---------|-------------|
| `build` | Build the Nexus CLI base image |
| `start` | Start the entire management system |
| `stop` | Stop all services |
| `status` | Show container status |
| `restart` | Restart all services |
| `logs` | Follow web manager logs |

### Usage Examples

```bash
# Build and start everything
./manage.sh start

# View status
./manage.sh status

# Stop all services
./manage.sh stop

# View logs
./manage.sh logs
```

## Troubleshooting

### Common Issues

1. **Port Already in Use**
   - Change `WEB_MANAGER_PORT` in `compose/.env.manager`

2. **Docker Permission Denied**
   - Add user to docker group: `sudo usermod -aG docker $USER`

3. **Container Creation Fails**
   - Check if base image exists: `docker images nexus-cli`
   - Verify Docker access: `docker info`

4. **Web Interface Not Loading**
   - Check logs: `docker logs nexus-web-manager`
   - Restart: `./manage.sh restart`

## Architecture

```
Web Interface (Browser) ◄──► Flask Backend ◄──► Docker Engine
                                    │
                                    ▼
                            Docker Socket Access
```

The system uses:
- **Flask web application** for the management interface
- **Docker API** for container lifecycle management
- **Custom Docker network** for container communication
- **Persistent volumes** for data storage

## Security

- Use strong secret keys in production
- Restrict web interface access
- Monitor container resource usage
- Regular security updates

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes
4. Submit a pull request

## License

MIT License - see LICENSE file for details
./scripts/manage.sh logs
```

## Deployment Options

### Option 1: Single Instance per Container (Recommended)

Best for production environments requiring maximum isolation:

```bash
docker-compose up -d node-1 node-2 node-3
```

### Option 2: Multiple Instances in One Container

Best for development or resource-constrained environments:

```bash
docker-compose --profile multi up -d multi-node
```

### Option 3: Kubernetes

For enterprise deployments:

```bash
kubectl apply -f k8s/
```

## Web Management UI

The project includes a web-based management interface that allows you to monitor and control your Nexus CLI containers from a browser.

### Web Manager Features

- Real-time container status monitoring
- Start/stop individual containers
- View container logs
- Resource usage statistics
- Multi-container deployment management

### Starting the Web Manager

```bash
# Start web manager only
./scripts/manage.sh start-manager

# Start with single instance
./scripts/manage.sh start-single-with-manager

# Start with multi-instance setup
./scripts/manage.sh start-multi-with-manager
```

The web interface will be available at: <http://localhost:3000>

## Configuration

### Environment Variables

Edit `.env` file:

```bash
# Single instances
NODE_ID_1=123456
NODE_ID_2=789012
NODE_ID_3=345678

# Multi-instance
NODE_IDS=123456,789012,345678,901234,567890
MAX_THREADS_MULTI=20
```

## Management Commands

```bash
# Build and deployment
./scripts/manage.sh build              # Build Docker image
./scripts/manage.sh start-single       # Start single instances
./scripts/manage.sh start-multi        # Start multi-instance
./scripts/manage.sh stop               # Stop all containers

# Monitoring
./scripts/manage.sh status             # Show container status
./scripts/manage.sh logs [service]     # Show logs
./scripts/manage.sh stats              # Show resource usage

# Maintenance
./scripts/manage.sh restart            # Restart all containers
./scripts/manage.sh clean              # Clean up containers and volumes
./scripts/manage.sh update             # Update to latest image
```

## Architecture

```text
nexus-docker/
├── docker/
│   ├── Dockerfile              # Multi-stage build
│   ├── scripts/
│   │   ├── start-single.sh     # Single instance startup
│   │   └── start-multi.sh      # Multi-instance startup
│   └── config/
│       └── nexus-template.json # Configuration template
├── compose/
│   ├── docker-compose.yml      # Main compose file
│   ├── docker-compose.dev.yml  # Development overrides
│   └── docker-compose.prod.yml # Production overrides
├── k8s/
│   ├── deployment.yaml         # Kubernetes deployment
│   ├── configmap.yaml         # Configuration
│   └── service.yaml           # Service definition
├── scripts/
│   ├── manage.sh              # Main management script
│   ├── monitor.sh             # Monitoring utilities
│   └── backup.sh              # Backup configurations
├── docs/
│   ├── deployment.md          # Deployment guide
│   ├── scaling.md             # Scaling strategies
│   └── troubleshooting.md     # Common issues
├── .env.example               # Environment template
└── README.md                  # This file
```

## Resource Requirements

### Minimum Requirements

- **CPU**: 2 cores per node instance
- **Memory**: 1GB per node instance
- **Storage**: 10GB for logs and configurations

### Recommended Requirements

- **CPU**: 4+ cores per node instance
- **Memory**: 2GB+ per node instance
- **Storage**: 50GB+ for production deployments

## Scaling

### Horizontal Scaling

Add more node instances by updating the configuration:

```bash
# Edit .env to add more node IDs
NODE_IDS=node1,node2,node3,node4,node5

# Restart services
./scripts/manage.sh restart
```

### Vertical Scaling

Increase resources per instance:

```bash
# Edit docker-compose.yml to increase resource limits
deploy:
  resources:
    limits:
      cpus: '4.0'
      memory: 4G
```

## Monitoring and Logging

### Built-in Monitoring

- Container health checks
- Resource usage monitoring
- Automatic restart on failure

### Log Management

- Centralized logging with Docker Compose
- Log rotation and archival
- Structured log output with timestamps

### Metrics Collection

- Prometheus-compatible metrics endpoint
- Grafana dashboard templates
- Custom alerting rules

## Security

- Non-root container execution
- Minimal base image (distroless)
- Network isolation between containers
- Encrypted configuration storage

## Support

- [Documentation](./docs/)
- [GitHub Issues](https://github.com/nexus-xyz/nexus-docker/issues)
- [Discord Community](https://discord.gg/nexus-xyz)

## License

This project is licensed under the same terms as the Nexus CLI.

---

**Note**: This is a community-maintained Docker deployment solution for Nexus CLI. For the official CLI, visit [nexus-xyz/nexus-cli](https://github.com/nexus-xyz/nexus-cli).

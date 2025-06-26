# Nexus CLI Docker Deployment

A comprehensive Docker deployment solution for running Nexus CLI with support for multiple node instances.

## Features

- 🐳 **Multi-container support**: Run each node in its own container for maximum isolation
- 🔄 **Multi-instance support**: Run multiple nodes within a single container for resource efficiency
- 📊 **Easy management**: Simple scripts for deployment, monitoring, and scaling
- ⚙️ **Flexible configuration**: Environment-based configuration with Docker Compose
- 🚀 **Auto-scaling**: Support for horizontal and vertical scaling
- 📈 **Monitoring**: Built-in logging and status monitoring
- ☸️ **Kubernetes ready**: Includes Kubernetes deployment configurations

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Valid Nexus node IDs

### 1. Clone and Setup

```bash
git clone <repository-url>
cd nexus-docker
cp .env.example .env
# Edit .env with your node IDs
```

### 2. Build and Deploy

```bash
# Build the image
./scripts/manage.sh build

# Deploy single instance
./scripts/manage.sh start-single

# Or deploy multi-instance
./scripts/manage.sh start-multi
```

### 3. Monitor

```bash
# Check status
./scripts/manage.sh status

# View logs
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

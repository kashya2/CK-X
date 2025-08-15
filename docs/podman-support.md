# Using CK-X Simulator with Podman

The CK-X Simulator now supports both Docker and Podman as container engines. This document provides instructions for using Podman with the CK-X Simulator.

## Prerequisites

1. **Podman**: Ensure you have Podman installed on your system.
   - For installation instructions, visit [Podman Installation Guide](https://podman.io/getting-started/installation)

2. **Podman Compose**: You'll need podman-compose for orchestrating multiple containers.
   - Install using: `pip3 install podman-compose`

## Automatic Installation

The installation script will automatically detect whether you have Docker or Podman installed and use the appropriate commands:

```bash
curl -fsSL https://raw.githubusercontent.com/nishanb/ck-x/master/scripts/install.sh | bash
```

The script will:
1. Detect if you have Docker or Podman installed
2. Check for the appropriate compose tool (docker compose or podman-compose)
3. Configure and start the environment using the available container engine

## Manual Installation and Management

If you prefer to manually manage the environment, you can use the following commands with Podman:

### Basic Podman Commands

```bash
# Pull and start all services
podman-compose up -d

# Check service status
podman-compose ps

# View logs
podman-compose logs -f

# Stop and remove services
podman-compose down

# Restart services
podman-compose restart
```

### Building Images with Podman

For multi-architecture builds, use:

```bash
# Build and push with podman
./scripts/house-keeping/build-and-push.sh
```

The script automatically detects and uses Podman if it's available.

## Troubleshooting

### Common Podman Issues

1. **Root vs Rootless Mode**: Podman can run in rootless mode by default. If you encounter permission issues, you may need to:
   ```bash
   # Run podman commands with sudo
   sudo podman-compose up -d
   
   # Or configure rootless mode properly
   podman system migrate
   ```

2. **Network Connectivity**: If containers can't communicate with each other:
   ```bash
   # Check the podman network
   podman network ls
   
   # You may need to create a new network
   podman network create ckx-network
   ```

3. **Compatibility with Docker Compose Files**: While podman-compose aims to be compatible with docker-compose files, there might be some differences:
   - Volume mounting syntax might differ
   - Some Docker-specific features might not be supported

### Getting Help

If you encounter issues specific to Podman, please:
1. Check the [Podman documentation](https://podman.io/docs)
2. Join our [Discord Community](https://discord.gg/6FPQMXNgG9) for support
3. Open an issue on GitHub describing your problem in detail

## Notes on Performance and Compatibility

- Podman generally provides similar performance to Docker
- The CK-X Simulator has been tested with Podman 3.0+ and podman-compose
- For best results, use the latest version of Podman and podman-compose

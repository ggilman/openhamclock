# OpenHamClock (Docker)

A lightweight, headless Docker container for [OpenHamClock](https://github.com/accius/openhamclock).

This image is optimized for server environments (NAS, Raspberry Pi, Docker Swarm). It strips out the heavy Electron desktop components, running the raw Node.js server directly.

**Size:** ~50MB (vs ~400MB original)  
**Architecture:** Multi-arch (ARM64/AMD64)  
**Security:** Non-root user, minimal dependencies.

## Features
* **Headless:** Runs the web server only. Access via browser.
* **Tiny Footprint:** Aggressively pruned to remove Electron and build tools.
* **Swarm Ready:** Configured for Docker Swarm and Traefik.
* **Secure:** Runs as a non-root user (`hamuser`, UID 1000).

## Quick Start (Docker Compose)

Save this as `docker-compose.yml`:

```yaml
version: '3.8'

services:
  openhamclock:
    image: ggilman/openhamclock:latest
    container_name: openhamclock
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - TZ=America/Chicago
    volumes:
      - ./config:/config
```

**Deploy:**

```bash
docker-compose up -d
```

Access at: http://localhost:3000

## Docker Swarm Deployment

This image is designed for Swarm. It respects standard environment variables for Traefik integration.

```yaml
version: '3.8'

services:
  openhamclock:
    image: ggilman/openhamclock:latest
    networks:
      - traefik_proxy
    environment:
      - TZ=America/Chicago
    volumes:
      - /mnt/nas/docker/openhamclock:/config
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
      labels:
        - "traefik.enable=true"
        - "traefik.docker.network=traefik_proxy"
        - "traefik.http.routers.openhamclock.rule=Host(`openhamclock.yourdomain.com`)"
        - "traefik.http.routers.openhamclock.entrypoints=websecure"
        - "traefik.http.services.openhamclock.loadbalancer.server.port=3000"

networks:
  traefik_proxy:
    external: true
```

## Configuration

| Variable | Default | Description |
|---|---|---|
| TZ | UTC | Timezone (e.g., America/Chicago). |

### User Permissions
This container runs as a fixed non-root user (`hamuser`) with **UID 1000** and **GID 1000**.
The `PUID` and `PGID` environment variables are **not** supported in this lightweight version.
Ensure your mounted volumes are writable by UID 1000.

## Persistent Storage

Mount a volume to `/config` to persist settings.

**Important Note on Permissions:** Because this container runs as a non-root user (UID 1000) for security, the host folder must be writable by user 1000.

If your container crashes immediately with "Permission Denied," run this on your host machine:

```bash
mkdir -p /path/to/config
sudo chown -R 1000:1000 /path/to/config
```

## Development / Building

To build this image locally:

```bash
# Clone the repo
git clone https://github.com/ggilman/openhamclock.git
cd openhamclock

# Build
docker build -t openhamclock:local .
```

## Credits

* Original Application: [OpenHamClock](https://github.com/accius/openhamclock) by Accius.
* Container Maintenance: Gregory Gilman

## License

MIT License. See LICENSE file for details.

# OpenHamClock (Docker)

A lightweight, headless Docker container for [OpenHamClock](https://github.com/accius/openhamclock).
**Source Code:** [github.com/ggilman/openhamclock](https://github.com/ggilman/openhamclock)

**OpenHamClock** is a modern, modular amateur radio dashboard built with React. It displays real-time space weather, band conditions, DX cluster spots, POTA activations, propagation predictions, and more.

This image is optimized for server environments (NAS, Raspberry Pi, Docker Swarm). It strips out the heavy Electron desktop components, running the raw Node.js server directly.

**Size:** ~50MB (vs ~400MB original)  
**Architecture:** Multi-arch (ARM64/AMD64)  
**Security:** Non-root user, minimal dependencies.

## Features
* **Headless:** Runs the web server only. Access via browser.
* **Tiny Footprint:** Aggressively pruned to remove Electron and build tools.
* **Swarm Ready:** Configured for Docker Swarm and Traefik.
* **Secure:** Runs as a non-root user (`hamuser`, UID 1000).

## Deployment

### Standard Deployment (Docker Compose)

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
      - CALLSIGN=N0CALL # Optional: Set your callsign
      - LOCATOR=FN31    # Optional: Set your grid square
    volumes:
      - ./config:/config
```

**Run:**

```bash
docker-compose up -d
```

### Simple Deployment (Docker CLI)

If you prefer to run it with a single command:

```bash
docker run -d \
  --name openhamclock \
  --restart unless-stopped \
  -p 3000:3000 \
  -e TZ=America/Chicago \
  -e CALLSIGN=N0CALL \
  -e LOCATOR=FN31 \
  -v $(pwd)/config:/config \
  ggilman/openhamclock:latest
```

Access at: http://localhost:3000

### Docker Swarm Deployment

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
      - CALLSIGN=N0CALL
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

The application can be configured via Environment Variables.

| Variable | Default | Description |
|---|---|---|
| `CALLSIGN` | N0CALL | Your station callsign. |
| `LOCATOR` | AB12 | Your Grid Square (e.g., `FN31`). |
| `TZ` | UTC | Timezone (e.g., `America/Chicago`). |
| `OPENWEATHER_API_KEY` | | Optional: API key for local weather. |
| `SHOW_SATELLITES` | `true` | Show satellite tracking. |
| `SHOW_POTA` | `true` | Show Parks on the Air. |
| `THEME` | `dark` | `dark`, `light`, `legacy`, `retro` |

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
* Container Maintenance: Gregory Gilman <ggilman@gmail.com>

## License

MIT License. See [LICENSE](LICENSE) file for details.

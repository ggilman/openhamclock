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
services:
  openhamclock:
    image: ggilman/openhamclock:latest
    container_name: openhamclock
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - TZ=America/Chicago
      - CALLSIGN=N0CALL  # Optional: set your callsign
      - LOCATOR=FN31     # Optional: set your grid square
    volumes:
      - ./config:/config
```

**Run:**

```bash
docker compose up -d
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
services:
  openhamclock:
    image: ggilman/openhamclock:latest
    networks:
      - traefik_proxy
    environment:
      - TZ=America/Chicago
      - CALLSIGN=N0CALL
      - PORT=3000
      - HOST=0.0.0.0
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

On first run the container creates `/app/.env` from the bundled `.env.example`. The entrypoint script then patches `PORT` and `HOST` in that file so Docker environment variables always take precedence over the dotenv defaults. All other variables can be set via `environment:` in your compose file or passed with `docker run -e`.

| Variable | Default | Description |
|---|---|---|
| `PORT` | `3000` | Port the Node.js server binds to. |
| `HOST` | `0.0.0.0` | Interface the server listens on. |
| `CALLSIGN` | N0CALL | Your station callsign. |
| `LOCATOR` | FN31 | Your Maidenhead grid square (4 or 6 characters). |
| `TZ` | UTC | Timezone (e.g., `America/Chicago`). |
| `OPENWEATHER_API_KEY` | | Optional: API key for cloud map overlay. |
| `SHOW_SATELLITES` | `true` | Show satellite tracking panel. |
| `SHOW_POTA` | `true` | Show Parks on the Air panel. |
| `THEME` | `dark` | UI theme: `dark`, `light`, `legacy`, or `retro`. |
| `SETTINGS_SYNC` | `false` | Persist UI settings server-side (recommended for self-hosted). |

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

### Build Arguments

| Argument | Default | Description |
|---|---|---|
| `NODE_VERSION` | `20` | Node.js major version |
| `ALPINE_TAG` | `3.23` | Alpine Linux version |
| `GIT_REPO` | `https://github.com/accius/openhamclock.git` | Source repository URL |
| `GIT_BRANCH` | `main` | Branch, tag, or commit to build from |

**Examples:**

```bash
# Build from a specific upstream tag
docker build --build-arg GIT_BRANCH=v2.1.0 -t openhamclock:local .

# Use a fork
docker build \
  --build-arg GIT_REPO=https://github.com/yourfork/openhamclock.git \
  --build-arg GIT_BRANCH=my-feature \
  -t openhamclock:local .

# Pin to a specific Node/Alpine version
docker build \
  --build-arg NODE_VERSION=22 \
  --build-arg ALPINE_TAG=3.21 \
  -t openhamclock:local .
```

## Credits

* Original Application: [OpenHamClock](https://github.com/accius/openhamclock) by Accius.
* Container Maintenance: George Gilman <ggilman@gmail.com>

## License

MIT License. See [LICENSE](LICENSE) file for details.

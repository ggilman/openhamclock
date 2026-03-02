# =============================================================================
# Build Arguments (all overridable at build time via --build-arg)
# -----------------------------------------------------------------------------
# NODE_VERSION  - Node.js major version          (default: 20)
# ALPINE_TAG    - Alpine Linux version           (default: 3.23)
# GIT_REPO      - Source repository URL         (default: accius/openhamclock)
# GIT_BRANCH    - Branch, tag, or commit to use (default: main)
# =============================================================================
ARG NODE_VERSION=20
ARG ALPINE_TAG=3.23
ARG GIT_REPO=https://github.com/accius/openhamclock.git
ARG GIT_BRANCH=main

# Stage 1: Build & Prune
FROM node:${NODE_VERSION}-alpine${ALPINE_TAG} AS builder

# Re-declare ARGs after FROM so they are available within this build stage
ARG GIT_REPO
ARG GIT_BRANCH

WORKDIR /build

# Install native build tools required for some dependencies
RUN apk add --no-cache git python3 make g++ curl

# Clone the repository to temporary location
# --depth 1 performs a shallow clone for faster builds
# --branch allows pinning to specific tag/branch/commit
RUN git clone --branch ${GIT_BRANCH} --depth 1 ${GIT_REPO} /tmp/repo

# Copy only package files first for better dependency caching
# This layer will be cached until package.json or package-lock.json changes
RUN cp /tmp/repo/package*.json ./

# Remove Electron and related packages (including @electron/rebuild)
RUN npm ci --loglevel=error && \
    (npm audit fix || true) && \
    npm uninstall electron electron-builder electron-packager @electron/rebuild || true

# Copy the rest of the application code
# Any code changes will only invalidate from this point forward
RUN cp -r /tmp/repo/* /tmp/repo/.[!.]* . 2>/dev/null || true && \
    rm -rf /tmp/repo

# Download vendor assets for self-hosting (Leaflet map library, fonts)
# Ensures map renders correctly without relying on external CDNs at runtime
RUN bash scripts/vendor-download.sh || true

# Build the React frontend (requires devDependencies - must happen before prune)
RUN npm run build

# Prune devDependencies and clear cache now that build is complete
# --omit=dev replaces deprecated --production flag
RUN npm prune --omit=dev && \
    npm cache clean --force

# Strip unnecessary files to reduce what gets copied to the runtime stage
RUN rm -rf .git .github .gitignore *.md LICENSE docs/ test/ tests/ examples/ 2>/dev/null || true

# Stage 2: Runtime
ARG NODE_VERSION=20
ARG ALPINE_TAG=3.23
FROM node:${NODE_VERSION}-alpine${ALPINE_TAG}

# OCI metadata labels
LABEL org.opencontainers.image.authors="ggilman@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/ggilman/openhamclock"
LABEL org.opencontainers.image.description="OpenHamClock server container"
LABEL org.opencontainers.image.licenses="MIT"

# Set Node.js to production mode for better performance
# PORT=3000 matches the upstream default so the server binds on the expected port
# HOST=0.0.0.0 ensures the server is accessible from outside the container
# NODE_OPTIONS enables periodic GC and sets heap limit for long-running stability
ENV NODE_ENV=production \
    PORT=3000 \
    HOST=0.0.0.0 \
    NODE_OPTIONS="--max-old-space-size=2048 --expose-gc"

# Install tini for init process and wget for healthcheck
# No need for 'shadow' - Alpine's built-in BusyBox commands handle user management
RUN apk add --no-cache tini wget

WORKDIR /app

# --- User/Permission Setup & Entrypoint Script ---
# Delete default 'node' user (ID 1000), create 'hamuser', setup config directory
# Create entrypoint script that patches .env before Node reads it via dotenv
# (dotenv overrides process.env by default; patching the file ensures Docker ENV wins)
RUN deluser --remove-home node 2>/dev/null || true && \
    addgroup -g 1000 hamuser && \
    adduser -u 1000 -G hamuser -h /home/hamuser -D hamuser && \
    chown hamuser:hamuser /app && \
    mkdir -p /config && \
    chown -R hamuser:hamuser /config && \
    ln -s /config /home/hamuser/.openhamclock && \
    printf '#!/bin/sh\nset -e\n\n# Bootstrap .env from example if it does not exist yet\nif [ ! -f /app/.env ] && [ -f /app/.env.example ]; then\n    cp /app/.env.example /app/.env\nfi\n\n# Patch PORT and HOST so Docker ENV always wins over dotenv values\nif [ -f /app/.env ]; then\n    sed -i "s|^PORT=.*|PORT=${PORT:-3000}|" /app/.env\n    sed -i "s|^HOST=.*|HOST=${HOST:-0.0.0.0}|" /app/.env\nfi\n\nexec /sbin/tini -- "$@"\n' > /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

# --- Optimized Copy ---
# COPY --chown is crucial here. It prevents the "70-second delay" during build
# by setting permissions instantly, avoiding a massive duplicate layer.
COPY --chown=hamuser:hamuser --from=builder /build .

# Declare persistent config volume
VOLUME ["/config"]

# OpenHamClock standard port
EXPOSE 3000

# Healthcheck
# --start-period gives Node.js and all services time to initialize before failures count
# App startup includes RBN connection, CTY loading, etc. - allow 90s grace period
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1

# Drop to non-root user for security
USER hamuser

# Entrypoint patches .env PORT/HOST before Node starts, then execs tini as PID 1
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["node", "server.js"]

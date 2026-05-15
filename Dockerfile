# syntax=docker/dockerfile:1
# =============================================================================
# Build Arguments (all overridable at build time via --build-arg)
# -----------------------------------------------------------------------------
# NODE_VERSION  - Node.js major version          (default: 20)
# BASE_OS_TAG   - Base OS image version tag       (default: 3.23)
# GIT_REPO      - Source repository URL           (default: accius/openhamclock)
# APP_VERSION   - Upstream release tag to build   (no default: required)
# =============================================================================
ARG NODE_VERSION=20
ARG BASE_OS_TAG=3.23
ARG GIT_REPO=https://github.com/accius/openhamclock.git
ARG APP_VERSION

# Stage 1: Build & Prune
FROM node:${NODE_VERSION}-alpine${BASE_OS_TAG} AS builder

# Re-declare ARGs after FROM so they are available within this build stage
ARG GIT_REPO
ARG APP_VERSION

WORKDIR /build

# Install native build tools required for some dependencies
# bash is required by scripts/vendor-download.sh (Alpine ships only sh/ash by default)
RUN apk add --no-cache git python3 make g++ curl bash

# Clone the repository to temporary location
# --depth 1 performs a shallow clone for faster builds
# Tag format: v<APP_VERSION> (e.g. v26.3.3)
RUN git clone --branch v${APP_VERSION} --depth 1 ${GIT_REPO} /tmp/repo

# Copy only package files first for better dependency caching
# This layer will be cached until package.json or package-lock.json changes
RUN cp /tmp/repo/package*.json ./

# Remove Electron and related packages (including @electron/rebuild)
# HUSKY=0 prevents the prepare script from erroring on missing .git directory
RUN HUSKY=0 npm ci --loglevel=error && \
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
# Force-update transitive packages with known HIGH CVEs to their minimum safe versions:
#   node-tar  >= 7.5.11  (CVE-2026-23745/23950/24842/31802)
#   minimatch >= 10.2.3  (CVE-2026-26996/27903)
#   cross-spawn >= 7.0.5 (CVE-2024-21538)
RUN npm prune --omit=dev && \
    npm update --ignore-scripts node-tar minimatch cross-spawn && \
    npm cache clean --force

# Strip unnecessary files to reduce what gets copied to the runtime stage
RUN rm -rf .git .github .gitignore *.md LICENSE docs/ test/ tests/ examples/ 2>/dev/null || true

# Stage 2: Runtime
ARG NODE_VERSION
ARG BASE_OS_TAG
FROM node:${NODE_VERSION}-alpine${BASE_OS_TAG}

ARG APP_VERSION

# OCI metadata labels
LABEL org.opencontainers.image.authors="ggilman@gmail.com" \
      org.opencontainers.image.source="https://github.com/ggilman/openhamclock" \
      org.opencontainers.image.description="OpenHamClock server container" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${APP_VERSION}"

# Set Node.js to production mode for better performance
# PORT=3000 matches the upstream default so the server binds on the expected port
# HOST=0.0.0.0 ensures the server is accessible from outside the container
# NODE_OPTIONS enables periodic GC and sets heap limit for long-running stability
ENV NODE_ENV=production \
    PORT=3000 \
    HOST=0.0.0.0 \
    NODE_OPTIONS="--max-old-space-size=2048 --expose-gc"

WORKDIR /app

# Install tini, delete default node user, create hamuser, set up config directory
# Update npm so its own bundled copies of node-tar/minimatch/cross-spawn are patched
RUN apk add --no-cache tini && \
    npm install -g npm@latest --ignore-scripts && \
    deluser --remove-home node 2>/dev/null || true && \
    addgroup -g 1000 hamuser && \
    adduser -u 1000 -G hamuser -h /home/hamuser -D hamuser && \
    chown hamuser:hamuser /app && \
    mkdir -p /config && \
    chown -R hamuser:hamuser /config && \
    ln -s /config /home/hamuser/.openhamclock

# Entrypoint: patches .env PORT/HOST so Docker ENV always wins over dotenv values
COPY --chmod=755 <<'EOF' /usr/local/bin/docker-entrypoint.sh
#!/bin/sh
set -e

# Bootstrap .env from example if it does not exist yet
if [ ! -f /app/.env ] && [ -f /app/.env.example ]; then
    cp /app/.env.example /app/.env
fi

# Patch PORT and HOST so Docker ENV always wins over dotenv values
if [ -f /app/.env ]; then
    sed -i "s|^PORT=.*|PORT=${PORT:-3000}|" /app/.env
    sed -i "s|^HOST=.*|HOST=${HOST:-0.0.0.0}|" /app/.env
fi

exec /sbin/tini -- "$@"
EOF

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
  CMD node -e "require('http').get('http://localhost:3000/api/health', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

# Drop to non-root user for security
USER hamuser

# Entrypoint patches .env PORT/HOST before Node starts, then execs tini as PID 1
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["node", "server.js"]

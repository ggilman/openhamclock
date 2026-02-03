# Stage 1: Build & Prune
FROM node:20-alpine AS builder
WORKDIR /build

# Install native build tools required for some dependencies
RUN apk add --no-cache git python3 make g++

# Clone the repository
RUN git clone https://github.com/accius/openhamclock.git .

# Install Dependencies & Clean Bloat
# 1. Update npm to latest to handle audits correctly
# 2. Install dependencies (hiding deprecation warnings)
# 3. Audit fix: Attempts to patch security holes (like 'tar')
# 4. REMOVE ELECTRON: This shrinks the image from ~370MB to ~150MB
# 5. Prune: Removes all other devDependencies
RUN npm install -g npm@latest && \
    npm install --loglevel=error && \
    (npm audit fix || true) && \
    npm uninstall electron electron-builder electron-packager || true && \
    npm prune --production && \
    rm -rf .git

# Stage 2: Runtime
FROM node:20-alpine
LABEL org.opencontainers.image.authors="ggilman@gmail.com"

# Install shadow for user management and tini for init process
RUN apk add --no-cache shadow tini

WORKDIR /app

# --- User/Permission Setup ---
# We delete the default 'node' user (ID 1000) to safely create 'hamuser'
RUN userdel -r node 2>/dev/null || true && \
    groupadd -g 1000 hamuser && \
    useradd -u 1000 -g hamuser -m -d /home/hamuser hamuser

# --- Optimized Copy ---
# COPY --chown is crucial here. It prevents the "70-second delay" during build
# by setting permissions instantly, avoiding a massive duplicate layer.
COPY --chown=hamuser:hamuser --from=builder /build .

# --- Persistence Setup ---
# Create config directory and ensure ownership
RUN mkdir -p /config && \
    chown -R hamuser:hamuser /config

# Link internal app settings to the persistent volume
# OpenHamClock looks for config in ~/.openhamclock
RUN ln -s /config /home/hamuser/.openhamclock

# OpenHamClock standard port
EXPOSE 3000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

# Drop to non-root user for security
USER hamuser

# --- FINAL FIX: Run Node Directly ---
# Bypassing 'npm start' ensures the container doesn't crash in Swarm
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]

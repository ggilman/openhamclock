#!/bin/bash
set -e

# --- Environment Defaults ---
PUID=${PUID:-1000}
PGID=${PGID:-1000}
USER_NAME="hamuser"
GROUP_NAME="hamuser"

# --- Permissions Management ---
# Update the hamuser UID/GID to match your environment (Synology NAS)
echo "Setting permissions for $USER_NAME ($PUID:$PGID)..."
groupmod -o -g "$PGID" "$GROUP_NAME" > /dev/null 2>&1
usermod -o -u "$PUID" "$USER_NAME" > /dev/null 2>&1

# Ensure the /config directory (NFS mount) is owned by hamuser
# This prevents permission errors when the app tries to save state
chown -R "$USER_NAME":"$GROUP_NAME" /app /config

# --- OpenHamClock Logic ---
# OpenHamClock stores settings in its own config directory.
# We ensure the symlink from the container's expected path to your 
# persistent /config mount is intact.
if [ ! -L "/home/hamuser/.openhamclock" ]; then
    ln -s /config /home/hamuser/.openhamclock
fi

# --- Execution ---
# We use su-exec to drop privileges from root to hamuser
# This is crucial for maintaining security on your DietPi/Swarm nodes
echo "Starting OpenHamClock..."
exec su-exec "$USER_NAME" "$@"

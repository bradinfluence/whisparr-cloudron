#!/bin/bash
set -eu

echo "==> Starting Whisparr..."

# Create required runtime directories
mkdir -p /run/app

# Note: We don't try to make /etc/s6-overlay writable anymore
# Cloudron containers don't have the capabilities to mount tmpfs or bind mount
# Our modifications are baked into the image at build time, so they should be in /etc/s6-overlay
# The read-only filesystem is fine - s6-overlay reads from /etc/s6-overlay but doesn't need to write to it
# (except for init-perms which we've stubbed out)

# Initialize data directory on first run
if [[ ! -f /app/data/.initialized ]]; then
    echo "==> First run, initializing data directory..."
    
    # Create required subdirectories
    mkdir -p /app/data/config
    mkdir -p /app/data/logs
    
    touch /app/data/.initialized
    echo "==> Initialization complete."
fi

# CRITICAL: Fix file ownership (not preserved across backup/restore)
# Use UID/GID directly since user might not exist yet (hotio init will create it)
echo "==> Fixing file ownership..."
chown -R 1000:1000 /app/data 2>/dev/null || true

# Create symlink from /config to /app/data/config
# Hotio images expect /config as the data directory
# On Cloudron, /config might be a mount point, so we can't remove it
# Instead, we'll copy contents if needed and ensure the symlink exists
if [[ -d /config ]] && [[ ! -L /config ]]; then
    # If /config exists as a directory, copy its contents to /app/data/config
    echo "==> Copying existing /config contents to /app/data/config..."
    if [[ "$(ls -A /config 2>/dev/null)" ]]; then
        cp -a /config/* /app/data/config/ 2>/dev/null || true
    fi
    # Don't try to remove /config - it might be a mount point on Cloudron
    echo "==> Note: /config exists as directory, but cannot be removed (read-only filesystem)"
fi
# Only create symlink if /config doesn't exist at all
# If it's already a mount point or directory, we'll work with what we have
if [[ ! -e /config ]]; then
    echo "==> Creating /config symlink..."
    ln -sf /app/data/config /config 2>/dev/null || true
fi
# If /config is already a symlink pointing to the right place, we're good
if [[ -L /config ]] && [[ "$(readlink /config)" == "/app/data/config" ]]; then
    echo "==> /config symlink already points to /app/data/config"
fi

# Set environment variables for hotio image
# PUID/PGID for cloudron user (UID 1000, GID 1000)
export PUID=1000
export PGID=1000
export UMASK=002

# Disable VPN services (not needed for Cloudron)
# This prevents s6-overlay from trying to configure VPN services
export VPN_ENABLED=false
export VPN_TYPE=""
export VPN_USER=""
export VPN_PASS=""

# Set Whisparr configuration via environment variables
# Port is 6969 (Whisparr default, matches CloudronManifest.json)
export WHISPARR__PORT=6969
export WHISPARR__BRANCH=nightly

# Set timezone if available from Cloudron (optional)
export TZ=${TZ:-UTC}

# Ensure Whisparr config.xml has the correct port (6969)
# Whisparr reads from /config/config.xml
# On Cloudron, /config is a mount point to /app/data/config
# So we write to /app/data/config/config.xml (the actual location)
CONFIG_DIR="/app/data/config"
CONFIG_FILE="${CONFIG_DIR}/config.xml"  # Write to the actual location
CONFIG_FILE_MOUNT="/config/config.xml"  # Whisparr reads from here (mount point)

# Ensure config directory exists
mkdir -p "$CONFIG_DIR"

# Function to update config.xml port
update_config_port() {
    local file="$1"
    if [[ -f "$file" ]]; then
        echo "==> Updating $file to use port 6969..."
        # Use sed to update the port in config.xml if it exists
        # Whisparr config.xml format: <Port>6969</Port>
        if grep -q "<Port>" "$file"; then
            sed -i 's|<Port>[0-9]*</Port>|<Port>6969</Port>|g' "$file"
            echo "==> Port updated to 6969 in $file"
            return 0
        else
            # If Port tag doesn't exist, add it after <Config>
            if grep -q "<Config>" "$file"; then
                sed -i 's|<Config>|<Config>\n  <Port>6969</Port>|' "$file"
                echo "==> Port added to $file"
                return 0
            fi
        fi
    fi
    return 1
}

# Create or update config.xml with port 6969
# Try to update existing file (could be at mount point or actual location)
if [[ -f "$CONFIG_FILE" ]]; then
    update_config_port "$CONFIG_FILE"
elif [[ -f "$CONFIG_FILE_MOUNT" ]]; then
    # If file exists at mount point, copy it first, then update
    cp "$CONFIG_FILE_MOUNT" "$CONFIG_FILE" 2>/dev/null || true
    update_config_port "$CONFIG_FILE"
else
    echo "==> Creating default config.xml with port 6969 at $CONFIG_FILE..."
    # Create a minimal config.xml with port 6969
    # Write to the actual location (/app/data/config/config.xml)
    cat > "$CONFIG_FILE" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<Config>
  <Port>6969</Port>
  <BindAddress>*</BindAddress>
  <EnableSsl>False</EnableSsl>
  <LogLevel>Info</LogLevel>
</Config>
EOF
    chown 1000:1000 "$CONFIG_FILE" 2>/dev/null || true
    echo "==> Default config.xml created with port 6969"
fi

# Ensure file is readable from mount point location
# On Cloudron, /config is mounted to /app/data/config, so this should already be the same file
# But if /config is a separate location, copy the file there
if [[ -f "$CONFIG_FILE" ]] && [[ "$CONFIG_FILE" != "$CONFIG_FILE_MOUNT" ]] && [[ ! -f "$CONFIG_FILE_MOUNT" ]]; then
    # Only copy if they're different locations and mount point doesn't have the file
    cp "$CONFIG_FILE" "$CONFIG_FILE_MOUNT" 2>/dev/null || true
fi

# Start the application using the hotio entrypoint
# The hotio image runs Whisparr via s6-overlay service
# Since we're already running inside s6-overlay (as a service), we don't exec /init
# Instead, we just exit and let s6-overlay handle running Whisparr via the service-whisparr service
# The service-whisparr service will run Whisparr with the correct user and environment
echo "==> Starting Whisparr on port 6969..."
echo "==> Configuration complete. Whisparr will be started by s6-overlay service system."

# Exit successfully - s6-overlay will start Whisparr via the service-whisparr service
exit 0


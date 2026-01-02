#!/bin/bash
set -eu

echo "==> Starting Whisparr..."

# Create required runtime directories
mkdir -p /run/app

# Initialize data directory on first run
if [[ ! -f /app/data/.initialized ]]; then
    echo "==> First run, initializing data directory..."
    mkdir -p /app/data/config
    mkdir -p /app/data/logs
    touch /app/data/.initialized
    echo "==> Initialization complete."
fi

# Fix file ownership (not preserved across backup/restore)
echo "==> Fixing file ownership..."
chown -R 1000:1000 /app/data 2>/dev/null || true

# Set up /config symlink to /app/data/config
# Whisparr expects /config, but Cloudron mounts /app/data
# Create symlink if /config doesn't exist
if [[ ! -e /config ]]; then
    echo "==> Creating /config symlink to /app/data/config..."
    ln -sf /app/data/config /config 2>/dev/null || true
fi

# Set environment variables
export PUID=1000
export PGID=1000
export UMASK=002
export TZ=${TZ:-UTC}

# Set Whisparr configuration via environment variables
export WHISPARR__PORT=6969
export WHISPARR__BRANCH=master

# Ensure Whisparr config.xml has the correct port (6969)
CONFIG_DIR="/app/data/config"
CONFIG_FILE="${CONFIG_DIR}/config.xml"

# Ensure config directory exists
mkdir -p "$CONFIG_DIR"
chown 1000:1000 "$CONFIG_DIR" 2>/dev/null || true

# Function to update config.xml port
update_config_port() {
    local file="$1"
    if [[ -f "$file" ]]; then
        echo "==> Updating $file to use port 6969..."
        if grep -q "<Port>" "$file"; then
            sed -i 's|<Port>[0-9]*</Port>|<Port>6969</Port>|g' "$file"
            echo "==> Port updated to 6969 in $file"
            return 0
        else
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
if [[ -f "$CONFIG_FILE" ]]; then
    update_config_port "$CONFIG_FILE"
else
    echo "==> Creating default config.xml with port 6969 at $CONFIG_FILE..."
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

echo "==> Starting Whisparr..."

# Change to Whisparr directory
cd /app/code

# Run Whisparr directly
# Whisparr will use /config for its configuration directory (via symlink)
exec dotnet Whisparr.dll

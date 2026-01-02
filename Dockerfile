FROM --platform=linux/amd64 ghcr.io/hotio/whisparr

# Install runtime dependencies (hotio images are Alpine-based)
RUN apk add --no-cache \
    gosu \
    curl \
    ca-certificates \
    shadow

# Create cloudron user (UID 1000, GID 1000)
RUN addgroup -g 1000 cloudron || true && \
    adduser -u 1000 -G cloudron -h /home/cloudron -s /bin/sh -D cloudron || true

# Create required directories
RUN mkdir -p /app/code /app/data /run/app /run/s6-overlay

# Remove /config if it exists in the base image (it's a VOLUME declaration)
# We need /config to be available for Cloudron to mount, but the base image
# might create it as a volume which causes issues
# Note: We can't remove VOLUME declarations, but we can ensure /config doesn't
# exist as a directory if it's causing issues
RUN if [ -d /config ] && [ ! -L /config ]; then \
        # If /config exists as a directory (not a symlink), it's from the base image
        # We'll leave it - Cloudron should mount to it
        echo "Note: /config directory exists in base image"; \
    fi

# Remove VPN services from original /etc/s6-overlay to prevent read-only filesystem errors
# The init-hook tries to modify these at runtime, so we remove them at build time
RUN if [ -d /etc/s6-overlay ]; then \
        # Remove VPN service definitions from original location
        rm -rf /etc/s6-overlay/s6-rc.d/user/contents.d/service-privoxy 2>/dev/null || true; \
        rm -rf /etc/s6-overlay/s6-rc.d/user/contents.d/service-unbound 2>/dev/null || true; \
        rm -rf /etc/s6-overlay/s6-rc.d/user/contents.d/service-proton 2>/dev/null || true; \
        rm -rf /etc/s6-overlay/s6-rc.d/user/contents.d/service-pia 2>/dev/null || true; \
        rm -rf /etc/s6-overlay/s6-rc.d/user/contents.d/service-forwarder 2>/dev/null || true; \
        rm -rf /etc/s6-overlay/s6-rc.d/user/contents.d/service-healthcheck 2>/dev/null || true; \
        # Create stub init-wireguard service (empty, does nothing) instead of removing it
        # This prevents "undefined service name" errors while keeping it non-functional
        rm -rf /etc/s6-overlay/s6-rc.d/init-wireguard 2>/dev/null || true; \
        mkdir -p /etc/s6-overlay/s6-rc.d/init-wireguard 2>/dev/null || true; \
        printf '#!/bin/sh\n# Disabled for Cloudron - no VPN needed\nexit 0\n' > /etc/s6-overlay/s6-rc.d/init-wireguard/run 2>/dev/null || true; \
        chmod +x /etc/s6-overlay/s6-rc.d/init-wireguard/run 2>/dev/null || true; \
        # Create required 'up' file for oneshot service
        printf '#!/bin/sh\n# Service is up immediately\nexit 0\n' > /etc/s6-overlay/s6-rc.d/init-wireguard/up 2>/dev/null || true; \
        chmod +x /etc/s6-overlay/s6-rc.d/init-wireguard/up 2>/dev/null || true; \
        # Also create run.up file (s6-overlay may use this instead)
        printf '#!/bin/sh\n# Service is up immediately\nexit 0\n' > /etc/s6-overlay/s6-rc.d/init-wireguard/run.up 2>/dev/null || true; \
        chmod +x /etc/s6-overlay/s6-rc.d/init-wireguard/run.up 2>/dev/null || true; \
        echo 'oneshot' > /etc/s6-overlay/s6-rc.d/init-wireguard/type 2>/dev/null || true; \
        # Remove dependency files that reference VPN services (but keep init-wireguard since we're stubbing it)
        rm -f /etc/s6-overlay/s6-rc.d/user/dependencies.d/init-wireguard-* 2>/dev/null || true; \
        # Remove references to VPN services (but keep init-wireguard since we're stubbing it)
        # Specifically target bundle dependencies and type files
        [ -f /etc/s6-overlay/s6-rc.d/user/type ] && sed -i '/service-privoxy/d; /service-unbound/d; /service-proton/d; /service-pia/d; /service-forwarder/d; /service-healthcheck/d' /etc/s6-overlay/s6-rc.d/user/type 2>/dev/null || true; \
        [ -f /etc/s6-overlay/s6-rc.d/user/dependencies ] && sed -i '/service-privoxy/d; /service-unbound/d; /service-proton/d; /service-pia/d; /service-forwarder/d; /service-healthcheck/d' /etc/s6-overlay/s6-rc.d/user/dependencies 2>/dev/null || true; \
        find /etc/s6-overlay/s6-rc.d/user/dependencies.d -type f 2>/dev/null -exec sed -i '/service-privoxy/d; /service-unbound/d; /service-proton/d; /service-pia/d; /service-forwarder/d; /service-healthcheck/d' {} \; 2>/dev/null || true; \
        # Also search all files recursively for VPN services (but not init-wireguard)
        find /etc/s6-overlay -type f 2>/dev/null -exec sh -c 'grep -q "service-privoxy\|service-unbound\|service-proton\|service-pia\|service-forwarder\|service-healthcheck" "$1" && sed -i "/service-privoxy/d; /service-unbound/d; /service-proton/d; /service-pia/d; /service-forwarder/d; /service-healthcheck/d" "$1" 2>/dev/null || true' _ {} \; || true; \
        # Disable init-hook completely (don't run original at all)
        if [ -f /etc/s6-overlay/init-hook ]; then \
            echo '#!/bin/sh' > /etc/s6-overlay/init-hook; \
            echo '# Disabled for Cloudron - no VPN services needed' >> /etc/s6-overlay/init-hook; \
            echo 'exit 0' >> /etc/s6-overlay/init-hook; \
            chmod +x /etc/s6-overlay/init-hook; \
        fi; \
        # Create stub init-perms service (empty, does nothing) instead of removing it
        # This prevents "undefined service name" errors while keeping it non-functional
        # Remove entire directory first to ensure clean state, including any backup files
        rm -rf /etc/s6-overlay/s6-rc.d/init-perms 2>/dev/null || true; \
        find /etc/s6-overlay -name '*init-perms*' -type f -delete 2>/dev/null || true; \
        # Recreate directory and stub script
        mkdir -p /etc/s6-overlay/s6-rc.d/init-perms 2>/dev/null || true; \
        # Create stub run script that does nothing (use printf to avoid heredoc issues)
        # Make absolutely sure this is a clean file
        rm -f /etc/s6-overlay/s6-rc.d/init-perms/run* 2>/dev/null || true; \
        printf '#!/bin/sh\n# Disabled for Cloudron - read-only filesystem, cannot change permissions\nexit 0\n' > /etc/s6-overlay/s6-rc.d/init-perms/run || true; \
        chmod +x /etc/s6-overlay/s6-rc.d/init-perms/run 2>/dev/null || true; \
        # Create required 'up' file for oneshot service (signals when service is ready)
        printf '#!/bin/sh\n# Service is up immediately\nexit 0\n' > /etc/s6-overlay/s6-rc.d/init-perms/up || true; \
        chmod +x /etc/s6-overlay/s6-rc.d/init-perms/up 2>/dev/null || true; \
        # Set service type to oneshot
        echo 'oneshot' > /etc/s6-overlay/s6-rc.d/init-perms/type 2>/dev/null || true; \
        # Verify the stub was created correctly
        test -f /etc/s6-overlay/s6-rc.d/init-perms/run || echo "WARNING: init-perms stub not created" || true; \
        test -f /etc/s6-overlay/s6-rc.d/init-perms/up || echo "WARNING: init-perms up file not created" || true; \
        # Remove any dependencies.d files that might reference init-perms
        rm -f /etc/s6-overlay/s6-rc.d/user/dependencies.d/*init-perms* 2>/dev/null || true; \
        # Create stub init-setup service (empty, does nothing) instead of removing it
        # This prevents "undefined service name" errors while keeping it non-functional
        # init-setup tries to run usermod which fails on read-only filesystem
        # We create the user in the Dockerfile, so we don't need this at runtime
        rm -rf /etc/s6-overlay/s6-rc.d/init-setup 2>/dev/null || true; \
        find /etc/s6-overlay -name '*init-setup*' -type f -delete 2>/dev/null || true; \
        # Recreate directory and stub script
        mkdir -p /etc/s6-overlay/s6-rc.d/init-setup 2>/dev/null || true; \
        # Create stub run script that does nothing
        rm -f /etc/s6-overlay/s6-rc.d/init-setup/run* 2>/dev/null || true; \
        printf '#!/bin/sh\n# Disabled for Cloudron - read-only filesystem, cannot modify users\nexit 0\n' > /etc/s6-overlay/s6-rc.d/init-setup/run || true; \
        chmod +x /etc/s6-overlay/s6-rc.d/init-setup/run 2>/dev/null || true; \
        # Create required 'up' file for oneshot service (signals when service is ready)
        printf '#!/bin/sh\n# Service is up immediately\nexit 0\n' > /etc/s6-overlay/s6-rc.d/init-setup/up || true; \
        chmod +x /etc/s6-overlay/s6-rc.d/init-setup/up 2>/dev/null || true; \
        # Set service type to oneshot
        echo 'oneshot' > /etc/s6-overlay/s6-rc.d/init-setup/type 2>/dev/null || true; \
        # Verify the stub was created correctly
        test -f /etc/s6-overlay/s6-rc.d/init-setup/run || echo "WARNING: init-setup stub not created" || true; \
        test -f /etc/s6-overlay/s6-rc.d/init-setup/up || echo "WARNING: init-setup up file not created" || true; \
        # Remove any dependencies.d files that might reference init-setup
        rm -f /etc/s6-overlay/s6-rc.d/user/dependencies.d/*init-setup* 2>/dev/null || true; \
        # Ensure all s6-overlay service scripts have execute permissions
        # Since init-perms and init-setup are stubbed, we need to set permissions at build time
        find /etc/s6-overlay/s6-rc.d -type f -name "run" -exec chmod +x {} \; 2>/dev/null || true; \
        find /etc/s6-overlay/s6-rc.d -type f -name "up" -exec chmod +x {} \; 2>/dev/null || true; \
        find /etc/s6-overlay/s6-rc.d -type f -name "down" -exec chmod +x {} \; 2>/dev/null || true; \
        find /etc/s6-overlay/s6-rc.d -type f -name "finish" -exec chmod +x {} \; 2>/dev/null || true; \
    fi

# Set working directory
WORKDIR /app/code

# Copy start script
COPY start.sh /app/code/start.sh
RUN chmod +x /app/code/start.sh

# Use the original hotio entrypoint (/init) which starts s6-overlay
# Our start.sh will be called by the init-setup-app service via s6-overlay
# Don't override CMD - let hotio's /init run as PID 1
EXPOSE 6969

# Keep the original entrypoint from hotio image
# ENTRYPOINT and CMD are inherited from the base image


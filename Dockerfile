FROM --platform=linux/amd64 alpine:latest

# Install .NET runtime and dependencies
# Whisparr requires .NET 8.0 runtime
RUN apk add --no-cache \
    dotnet8-runtime \
    curl \
    ca-certificates \
    icu-libs \
    libintl \
    libgcc \
    libstdc++ \
    sqlite-libs \
    && rm -rf /var/cache/apk/*

# Create cloudron user (UID 1000, GID 1000)
RUN addgroup -g 1000 cloudron && \
    adduser -u 1000 -G cloudron -h /home/cloudron -s /bin/sh -D cloudron

# Create required directories
RUN mkdir -p /app/code /app/data/config /app/data/logs /run/app && \
    chown -R 1000:1000 /app/data

# Set working directory
WORKDIR /app/code

# Download and install Whisparr
# Using the latest release from GitHub
RUN WHISPARR_VERSION=$(curl -s https://api.github.com/repos/Whisparr/Whisparr/releases/latest | grep -oP '"tag_name": "\K[^"]*' | head -1) && \
    echo "Installing Whisparr version: $WHISPARR_VERSION" && \
    VERSION_NUM=$(echo "$WHISPARR_VERSION" | sed 's/v//') && \
    curl -L -o /tmp/whisparr.tar.gz \
        "https://github.com/Whisparr/Whisparr/releases/download/${WHISPARR_VERSION}/Whisparr.master.${VERSION_NUM}.linux-core-x64.tar.gz" && \
    tar -xzf /tmp/whisparr.tar.gz -C /app/code --strip-components=1 && \
    rm -f /tmp/whisparr.tar.gz && \
    chown -R 1000:1000 /app/code

# Copy start script
COPY start.sh /app/code/start.sh
RUN chmod +x /app/code/start.sh

# Set environment variables
ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH="${PATH}:${DOTNET_ROOT}"
ENV WHISPARR__PORT=6969
ENV WHISPARR__BRANCH=master
ENV PUID=1000
ENV PGID=1000
ENV UMASK=002
ENV TZ=UTC

# Expose Whisparr port
EXPOSE 6969

# Switch to cloudron user
USER cloudron

# Set entrypoint
ENTRYPOINT ["/app/code/start.sh"]

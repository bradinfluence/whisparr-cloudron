# Whisparr Cloudron App

[Whisparr](https://whisparr.org) is an adult movie collection manager for Usenet and BitTorrent users. It monitors multiple RSS feeds for new movies and interfaces with clients and indexers to grab, sort, and rename them. Whisparr can also be configured to automatically upgrade the quality of existing files in the library when a better quality format becomes available.

This package provides Whisparr as a Cloudron app, making it easy to install and manage on your Cloudron server.

## Features

- **Automated Movie Management**: Monitors RSS feeds for new adult movies and manages downloads automatically
- **Quality Upgrades**: Automatically upgrades existing files to better quality formats when available
- **Failed Download Handling**: Automatically handles failed downloads by attempting alternative releases
- **Download Client Integration**: Full integration with major download clients (qBittorrent, Transmission, Deluge, etc.)
- **Indexer Support**: Supports multiple indexers for comprehensive content discovery
- **Metadata Management**: Imports and manages metadata to enhance your movie collection
- **Custom Formats**: Advanced custom format support for fine-grained quality control
- **Import Lists**: Import movies from various sources including Trakt, Plex, and more

## Installation

### Prerequisites

- A Cloudron server with Docker support
- At least 512MB of available memory (recommended: 1GB or more)
- Sufficient disk space for your movie library

### Installation Steps

1. **Clone or download this repository:**
   ```bash
   git clone https://git.bradinfluence.co.uk/bradinfluence/whisparr.git
   cd whisparr-cloudronapp
   ```

2. **Build the Docker image:**
   ```bash
   cloudron build
   ```

3. **Install the app on Cloudron:**
   ```bash
   cloudron install
   ```

   Or install via the Cloudron web interface by uploading the app package.

## Configuration

### Initial Setup

After installation, access Whisparr at `https://your-app-domain.cloudron.me` (or your custom domain). The initial setup wizard will guide you through:

1. **Setting Up Indexers**: Configure one or more indexers to fetch movie information
2. **Configuring Download Clients**: Integrate with your preferred download clients
3. **Library Management**: Set up your movie library paths and preferences
4. **Quality Profiles**: Configure quality profiles to match your preferences
5. **Media Management**: Set up naming conventions and file organization

### Port Configuration

Whisparr runs on port **6969** by default. The Cloudron manifest is configured to use this port. If you need to change the port, you can do so in Whisparr's settings under **Settings → General → Port**.

### Data Storage

All Whisparr data (configuration, database, logs) is stored in the Cloudron app's data directory at `/app/data`. This data is automatically backed up by Cloudron's backup system.

### Memory Requirements

The app is configured with a 512MB memory limit to handle large metadata responses. If you experience OutOfMemoryException errors, you can increase the memory limit in `CloudronManifest.json`:

```json
"memoryLimit": 1073741824  // 1GB in bytes
```

## Usage

### Adding Movies

1. Navigate to **Movies** in the Whisparr interface
2. Click **Add New** or use the search function
3. Search for the movie you want to add
4. Select the movie and configure monitoring options
5. Click **Add Movie**

### Monitoring

Whisparr will automatically:
- Monitor your added movies for new releases
- Search for and download movies based on your quality profiles
- Upgrade existing files when better quality becomes available
- Handle failed downloads by trying alternative releases

### Download Clients

Whisparr supports integration with various download clients:
- **qBittorrent**
- **Transmission**
- **Deluge**
- **rTorrent**
- **uTorrent**
- **Vuze**
- **NZBGet**
- **SABnzbd**
- And more...

### Indexers

Whisparr supports multiple indexer types:
- **Newznab** (Usenet indexers)
- **Torznab** (Torrent indexers)
- **Cardigann** (Generic indexer support)

## Troubleshooting

### Container Won't Start

If the container fails to start, check the logs:
```bash
cloudron logs whisparr
```

Common issues:
- **Read-only filesystem errors**: These are expected and harmless - the app is configured to work with Cloudron's read-only filesystem
- **Permission errors**: The app uses UID/GID 1000 (cloudron user) - ensure data directory permissions are correct
- **Port conflicts**: Ensure port 6969 is available (configured in CloudronManifest.json)

### OutOfMemoryException

If you see OutOfMemoryException errors:
1. Increase the memory limit in `CloudronManifest.json`
2. Restart the app
3. Consider reducing the number of monitored movies or indexers

### Port Configuration Issues

If Whisparr is not accessible:
1. Verify the port is set to 6969 in Whisparr settings
2. Check Cloudron's reverse proxy configuration
3. Ensure the app is running: `cloudron status whisparr`

## Technical Details

### Base Image

This app is based on the [hotio/whisparr](https://hotio.dev/containers/whisparr) Docker image, which provides:
- Alpine Linux base
- s6-overlay for process management
- Automatic updates support
- VPN support (disabled for Cloudron)

### Modifications for Cloudron

This Cloudron package includes several modifications to work with Cloudron's constraints:

- **Read-only filesystem compatibility**: Stubbed out services that require write access to `/etc`
- **VPN services removed**: VPN functionality is disabled as it's not needed in Cloudron
- **User management**: Configured to use Cloudron's user system (UID/GID 1000)
- **Data directory**: Uses `/app/data` for persistent storage, mounted to Cloudron's data directory
- **Port configuration**: Automatically configures Whisparr to use the correct port

### File Structure

```
whisparr-cloudronapp/
├── CloudronManifest.json  # Cloudron app manifest
├── Dockerfile             # Docker image definition
├── start.sh              # Startup script
├── icon.png             # App icon
└── README.md            # This file
```

## Support

### Whisparr Support

For issues related to Whisparr itself:
- **Website**: [https://whisparr.org](https://whisparr.org)
- **GitHub**: [https://github.com/Whisparr/Whisparr](https://github.com/Whisparr/Whisparr)
- **Wiki**: [https://wiki.servarr.com/whisparr](https://wiki.servarr.com/whisparr)
- **Discord**: [https://discord.gg/whisparr](https://discord.gg/whisparr)

### Cloudron Package Support

For issues related to this Cloudron package:
- **Repository**: [https://git.bradinfluence.co.uk/bradinfluence/whisparr](https://git.bradinfluence.co.uk/bradinfluence/whisparr)
- **Contact**: support@bradinfluence.net

## License

Whisparr is licensed under the **GNU GPL v3** license. For more details, see the [Whisparr LICENSE file](https://github.com/Whisparr/Whisparr/blob/develop/LICENSE).

This Cloudron package is provided as-is for use with Cloudron. The package maintainer is not affiliated with the Whisparr project.

## Version History

### 1.0.0
- Initial Cloudron package release
- Based on hotio/whisparr:latest
- Configured for Cloudron's read-only filesystem
- Memory limit set to 512MB
- Port configured to 6969

## Contributing

Contributions to improve this Cloudron package are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Acknowledgments

- **Whisparr Team**: For creating and maintaining Whisparr
- **hotio**: For providing the excellent Docker base image
- **Cloudron**: For providing the platform and framework

---

*This package is maintained independently and is not officially affiliated with Whisparr or Cloudron.*





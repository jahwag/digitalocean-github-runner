# GitHub Runner for DigitalOcean

One-command deployment of GitHub Actions runner on DigitalOcean droplet.

## Quick Start

```bash
# Download and run
curl -sSL https://raw.githubusercontent.com/jahwag/digitalocean-github-runner/main/quick-deploy.sh | bash
```

The script will:
1. Install DigitalOcean CLI (if needed)
2. Ask for your DigitalOcean API token (first time only)
3. Ask for your GitHub Personal Access Token
4. Let you choose droplet size (2GB/4GB/8GB RAM)
5. Deploy everything automatically

## Costs

- **Small**: 2GB RAM, 1 CPU - $12/month
- **Medium**: 4GB RAM, 2 CPU - $24/month  
- **Large**: 8GB RAM, 4 CPU - $48/month

## Requirements

- GitHub PAT with `admin:org` scope ([Create here](https://github.com/settings/tokens))
- DigitalOcean account ([Sign up](https://www.digitalocean.com/))
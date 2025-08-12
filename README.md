# GitHub Actions Multi-Runner for DigitalOcean

Deploy multiple concurrent GitHub Actions runners that automatically scale based on CPU cores (3 runners per core).

## Smart Scaling

Single runners only use ~40% CPU per job. This setup automatically deploys 3 runners per CPU core:
- **1 CPU**: 3 runners (3 concurrent jobs)
- **2 CPU**: 6 runners (6 concurrent jobs)
- **4 CPU**: 12 runners (12 concurrent jobs)
- **Optimal resource usage**: ~120% CPU utilization per core
- **Same cost, 3x throughput per core**

## Quick Start

```bash
# Download and run
curl -sSL https://raw.githubusercontent.com/jahwag/bytelope-github-runner/main/quick-deploy.sh | bash
```

The script will:
1. Install DigitalOcean CLI (if needed)
2. Ask for your DigitalOcean API token (first time only)
3. Ask for your GitHub Personal Access Token
4. Let you choose droplet size
5. Automatically deploy runners (3 per CPU core)

## Costs & Capacity

| Plan | Specs | Monthly Cost | Runners | Concurrent Jobs |
|------|-------|--------------|---------|-----------------|
| **Basic** | 1 CPU, 2GB RAM | $12 | 3 | 3 jobs |
| **Standard** | 2 CPU, 2GB RAM | $18 | 6 | 6 jobs |
| **Performance** | 2 CPU, 4GB RAM | $24 | 6 | 6 jobs |
| **Heavy** | 4 CPU, 8GB RAM | $48 | 12 | 12 jobs |

## Requirements

- GitHub PAT with `admin:org` scope ([Create here](https://github.com/settings/tokens))
- DigitalOcean account ([Sign up](https://www.digitalocean.com/))
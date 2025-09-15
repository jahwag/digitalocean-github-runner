# GitHub Actions Runner for DigitalOcean

Deploy GitHub Actions runners on DigitalOcean droplets.

## Deploy via GitHub Actions

1. Add `DIGITALOCEAN_ACCESS_TOKEN` to your repo secrets
2. Run the "Deploy GitHub Runner" workflow
3. Enter your GitHub PAT and select tier

## Command Line

```bash
curl -sSL https://raw.githubusercontent.com/jahwag/digitalocean-github-runner/main/quick-deploy.sh | bash
```

## Pricing

| Tier | Specs | Cost | Runners |
|------|-------|------|---------|
| Micro | 1 CPU, 1GB | $6/mo | 2 |
| Basic | 1 CPU, 2GB | $12/mo | 3 |
| Standard | 2 CPU, 2GB | $18/mo | 5 |
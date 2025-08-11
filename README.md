# GitHub Runner for DigitalOcean

[![Deploy to DigitalOcean](https://www.deploytodo.com/do-btn-blue.svg)](https://cloud.digitalocean.com/apps/new?repo=https://github.com/jahwag/digitalocean-github-runner/tree/main)

## Setup

1. Create a [GitHub Personal Access Token](https://github.com/settings/tokens) with `admin:org` scope
2. Click the Deploy button
3. Set `GITHUB_TOKEN` and `GITHUB_ORG` environment variables
4. Deploy

Your runner will appear at: `https://github.com/organizations/YOUR_ORG/settings/actions/runners`
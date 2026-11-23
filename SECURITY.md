# Security

This file lists the security scans that run on EduShare, what they found, and how each finding was handled.

## Scans in the pipeline

The [Security workflow](.github/workflows/security.yml) runs on every pull request into `main` and again in the [CD pipeline](.github/workflows/cd.yml) before every deploy. Any failing scan fails the pull request's checks and stops the deploy.

| Scan | Tool | What it checks | Fails on |
|------|------|----------------|----------|
| Secret scan | Gitleaks | Passwords, tokens and keys in every commit of the Git history | Any secret found |
| Dependency scan | `npm audit --omit=dev` (backend and frontend) | Known vulnerabilities in the packages that reach the running app | HIGH or CRITICAL |
| IaC scan | Checkov | Terraform, Ansible and the Dockerfile | Any failed check |
| Container image scan | Trivy 0.58.1 | OS packages and libraries inside the built Docker image | HIGH or CRITICAL with a fix available |

After a merge into `main`, the CD pipeline pushes the image to the private Azure Container Registry (`edushareacrgvv9o.azurecr.io/edushare:<commit SHA>` and `:latest`) and deploys it, but only if all four scans passed. The pipeline's Azure credentials, deploy key and vault password are GitHub repository secrets, never stored in the code.

## Findings and how they were addressed

| # | Scan | Finding | Severity | Status | How it was handled |
|---|------|---------|----------|--------|--------------------|
| 1 | npm audit (backend) | `body-parser` below 1.20.9: denial of service via trailing bytes after a compressed request body ([GHSA-27r3-jxmh-p828](https://github.com/advisories/GHSA-27r3-jxmh-p828)) | High | **Fixed** | Upgraded through `npm audit fix` in `backend/package-lock.json` (commit `9f16f5f`). The scan now passes |
| 2 | Trivy (image) | `pacote` (CVE-2026-9496), `picomatch` (CVE-2026-33671), `sigstore` (CVE-2026-48815) and related packages, all bundled with the `npm` tool inside the `node:22-alpine` base image | High | **Fixed** | The runtime stage of the `Dockerfile` now deletes `npm`, `npx`, `corepack` and `yarn` after installing dependencies (commit `9f16f5f`). The container only runs `node server.js`, so it never needs them. This removes the vulnerable packages and shrinks the attack surface |
| 3 | Checkov (Terraform) | `CKV_AZURE_119`: a VM has a public IP | — | **Accepted** | Since the Summative, only the bastion has a public IP; the app VM is private. SSH (22) to the bastion is allowed only from the team's IP addresses (and the CD runner during a deploy) and HTTP (80) is public; the network security group denies everything else |
| 4 | Checkov (Ansible) | `CKV2_ANSIBLE_1`: the deployment health check uses HTTP instead of HTTPS | — | **Accepted** | The check calls `http://localhost` on the server itself, so the traffic never leaves the VM. The reason is recorded inline in `ansible/roles/app/tasks/main.yml` |
| 5 | npm audit (frontend, dev only) | `vite` | High | **Accepted** | Development-only build tool: it is not in the Docker image (only the built static files are), so the CI audit checks runtime packages only (`--omit=dev`) |
| 6 | Gitleaks | No secrets found | — | **Clean** | Secrets live in git-ignored `.env` and `terraform.tfvars` files, GitHub repository secrets, and an Ansible Vault file encrypted with AES-256 |
| 7 | Checkov (Terraform) | `CKV_AZURE_160` (port 80 open), `CKV_AZURE_137` (ACR admin user), `CKV_AZURE_100/101/140` (Cosmos DB), and `CKV_AZURE_139/163/164/165/166/167/233/237` (ACR Premium-tier features) | — | **Accepted** | Each skip has its reason inline in the code and in [terraform/README.md](terraform/README.md#accepted-risks-checkov). Port 80 serves the public website; the deploy identity cannot create role assignments, so ACR uses admin credentials kept in GitHub secrets and Ansible Vault; Cosmos DB is locked to the private subnet; images are scanned by Trivy before they are pushed. Terraform: 49 passed, 0 failed, 15 skipped |

**Evidence:** the first scan run failed on findings 1 and 2, and the fix made it pass. Screenshots are in [`docs/security/`](docs/security/):
- [`npm-audit-failed.png`](docs/security/npm-audit-failed.png): the `body-parser` finding failing the build
- [`trivy-failed.png`](docs/security/trivy-failed.png): Trivy failing on the npm-bundled packages
- [`scan-failed-pr.png`](docs/security/scan-failed-pr.png) and [`scan-passed-main.png`](docs/security/scan-passed-main.png): the pull request going from red to green

## Security measures in place

| Layer | Measures |
|-------|----------|
| Application | Query parameters must be plain strings (blocks NoSQL injection such as `?subject[$ne]=x`), search input is escaped, resource ids are validated |
| Container | Multi-stage build, runs as the non-root `node` user, health check, no package managers in the final image, all Linux capabilities dropped, `no-new-privileges` |
| Infrastructure (Terraform) | Only the bastion has a public IP; the app VM sits in a private subnet reachable only from the bastion (ports 22 and 4000); SSH only from approved IPs, key-only login (no passwords); all other inbound traffic denied; Cosmos DB reachable only from the private subnet; private container registry; no hardcoded secrets |
| Server (Ansible) | UFW firewall per host (bastion: 22 and 80; app VM: 22 and 4000 from the bastion subnet only), SSH hardening (no root login, no passwords), fail2ban, automatic security updates, Nginx with security headers and its version hidden, database connection string and registry password in Ansible Vault, `.env` on the server readable by root only |
| Pipeline | Secret, dependency, IaC and image scans on every pull request and before every deploy; image published and deployed only when every scan passes; Azure service principal limited to the project's resource group; SSH opened for the runner's IP only during a deploy and always closed afterwards; `main` protected by required reviews and checks |

## Known limitations

- The `helpful` and `flag` endpoints have no user accounts or rate limiting, so one person can vote or flag repeatedly.
- The site is served over plain HTTP, because there is no domain name for a TLS certificate yet. Adding a domain and HTTPS on the bastion's Nginx is the next improvement.

## Reporting a vulnerability

Please do not open a public issue. Contact a team member directly.

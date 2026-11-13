# Security

This file lists the security scans that run on EduShare, what they found, and how each finding was handled.

## Scans in the pipeline

The [Security workflow](.github/workflows/security.yml) runs on every pull request into `main` and again after every merge. Any failing scan fails the pull request's checks.

| Scan | Tool | What it checks | Fails on |
|------|------|----------------|----------|
| Secret scan | Gitleaks | Passwords, tokens and keys in every commit of the Git history | Any secret found |
| Dependency scan | `npm audit --omit=dev` (backend and frontend) | Known vulnerabilities in the packages that reach the running app | HIGH or CRITICAL |
| Container image scan | Trivy 0.58.1 | OS packages and libraries inside the built Docker image | HIGH or CRITICAL with a fix available |

After a merge into `main`, the image is pushed to Docker Hub (`iannah/edushare:latest` and `iannah/edushare:<commit SHA>`), but only if all three scans passed. Docker Hub credentials are GitHub repository secrets, never stored in the code.

Infrastructure code was also scanned with **Checkov** before merging (see below).

## Findings and how they were addressed

| # | Scan | Finding | Severity | Status | How it was handled |
|---|------|---------|----------|--------|--------------------|
| 1 | npm audit (backend) | `body-parser` below 1.20.9: denial of service via trailing bytes after a compressed request body ([GHSA-27r3-jxmh-p828](https://github.com/advisories/GHSA-27r3-jxmh-p828)) | High | **Fixed** | Upgraded through `npm audit fix` in `backend/package-lock.json` (commit `9f16f5f`). The scan now passes |
| 2 | Trivy (image) | `pacote` (CVE-2026-9496), `picomatch` (CVE-2026-33671), `sigstore` (CVE-2026-48815) and related packages, all bundled with the `npm` tool inside the `node:22-alpine` base image | High | **Fixed** | The runtime stage of the `Dockerfile` now deletes `npm`, `npx`, `corepack` and `yarn` after installing dependencies (commit `9f16f5f`). The container only runs `node server.js`, so it never needs them. This removes the vulnerable packages and shrinks the attack surface |
| 3 | Checkov (Terraform) | `CKV_AZURE_119`: the VM has a public IP | — | **Accepted** | A public IP is required to serve the website and reach the VM. SSH (22) is allowed only from the team's IP addresses and HTTP (80) is public; the network security group denies everything else. 14 checks passed, 0 failed |
| 4 | Checkov (Ansible) | `CKV2_ANSIBLE_1`: the deployment health check uses HTTP instead of HTTPS | — | **Accepted** | The check calls `http://localhost` on the server itself, so the traffic never leaves the VM. The reason is recorded inline in `ansible/roles/app/tasks/main.yml` |
| 5 | npm audit (frontend, dev only) | `vite` | High | **Accepted** | Development-only build tool: it is not in the Docker image (only the built static files are), so the CI audit checks runtime packages only (`--omit=dev`) |
| 6 | Gitleaks | No secrets found | — | **Clean** | Secrets live in git-ignored `.env` and `terraform.tfvars` files, GitHub repository secrets, and an Ansible Vault file encrypted with AES-256 |

**Evidence:** the first scan run failed on findings 1 and 2, and the fix made it pass. Screenshots are in [`docs/security/`](docs/security/):
- [`npm-audit-failed.png`](docs/security/npm-audit-failed.png): the `body-parser` finding failing the build
- [`trivy-failed.png`](docs/security/trivy-failed.png): Trivy failing on the npm-bundled packages
- [`scan-failed-pr.png`](docs/security/scan-failed-pr.png) and [`scan-passed-main.png`](docs/security/scan-passed-main.png): the pull request going from red to green

## Security measures in place

| Layer | Measures |
|-------|----------|
| Application | Query parameters must be plain strings (blocks NoSQL injection such as `?subject[$ne]=x`), search input is escaped, resource ids are validated |
| Container | Multi-stage build, runs as the non-root `node` user, health check, no package managers in the final image |
| Infrastructure (Terraform) | SSH only from approved IPs, key-only login (no passwords), all other inbound traffic denied, no hardcoded secrets or regions |
| Server (Ansible) | UFW firewall (only 22 and 80), SSH hardening (no root login, no passwords), fail2ban, automatic security updates, MongoDB not exposed outside the Docker network, database password in Ansible Vault |
| Pipeline | Secret, dependency and image scans on every pull request; image published only when every scan passes |

## Known limitations

- The `helpful` and `flag` endpoints have no user accounts or rate limiting, so one person can vote or flag repeatedly.
- The site is served over plain HTTP. HTTPS with a TLS certificate is planned for the Summative.
- Checkov runs locally rather than in the pipeline; adding it as a CI job is a planned improvement.

## Reporting a vulnerability

Please do not open a public issue. Contact a team member directly.

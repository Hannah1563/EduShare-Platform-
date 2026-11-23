# Changelog

All notable changes to EduShare, by project phase. Newest first.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Pull request numbers up to #27 refer to the original repository ([maridadithierry/EduShare-Platform-](https://github.com/maridadithierry/EduShare-Platform-)); from #1 onwards in Formative 3 they refer to this fork.

---

## [Summative] Complete DevOps pipeline (2026-11-19 → 2026-11-23)

Production moved from one public VM to a private, multi-tier Azure environment that deploys automatically on every merge into `main`.

### Added

- **Terraform infrastructure, rebuilt as modules** (`network`, `compute`, `database`, `registry`) ([#6](https://github.com/Hannah1563/EduShare-Platform-/pull/6))
  - Virtual network `10.20.0.0/16` with a public subnet and a private subnet
  - Bastion VM as the only public entry point (SSH jump host and web proxy)
  - Private app VM with no public IP, and a NAT gateway for outbound traffic only
  - Network security groups with separate rule resources, so CD's temporary SSH rule is never removed by Terraform
  - Explicit deny of all other VNet traffic to the app port
  - Azure Cosmos DB for MongoDB (free tier), reachable only from the private subnet through a service endpoint
  - Private Azure Container Registry (ACR)
  - Remote Terraform state in Azure Storage, shared by the team
  - Input validation that rejects `0.0.0.0/0` for SSH
  - Team SSH keys and the CD deploy key
- **Ansible for the two-tier setup** ([#7](https://github.com/Hannah1563/EduShare-Platform-/pull/7))
  - Inventory with `bastion` and `app` groups; the app VM is reached through the bastion with `ProxyCommand`
  - New `proxy` role: Nginx reverse proxy on the bastion, with security headers and the server version hidden
  - Per-host UFW rules: the bastion allows 22 and 80; the app VM allows 22 and 4000 from the bastion subnet only
  - The `app` role logs in to ACR, pulls the image and runs it with Docker Compose
  - A `block`/`rescue` in the `app` role prints the container status and logs when a deploy fails
  - An end-to-end check of `/health` through the bastion
  - `-e app_image_tag=<commit SHA>` deploys one exact build
- **DevSecOps** ([#8](https://github.com/Hannah1563/EduShare-Platform-/pull/8))
  - New Checkov IaC scan job covering Terraform, Ansible and the Dockerfile, with hard failure on any finding
  - CI and Security workflows also run on pull requests into `summative`, and can be called by other workflows
- **CD pipeline** (`.github/workflows/cd.yml`) ([#8](https://github.com/Hannah1563/EduShare-Platform-/pull/8)). It runs on every push to `main`, in this order:
  1. Runs the same CI and security checks as pull requests
  2. Builds the image and pushes it to ACR, tagged with the commit SHA and `latest`
  3. Opens SSH on the bastion for the runner's IP only
  4. Runs the Ansible playbook to deploy that exact image
  5. Smoke-tests `/health` from the internet
  6. Always closes SSH again, even after a failure

  It also logs in to Azure with a service principal scoped to the project's resource group, and uses a `production` environment with one deploy at a time.
- **Branch protection on `main`:**
  - One approval required
  - All seven CI and security checks must pass
  - The branch must be up to date with `main`
  - Conversations must be resolved
  - No bypass
- **Documentation:**
  - README rewritten as an operations manual: architecture and pipeline diagrams, setup from scratch, operations, observability, troubleshooting
  - Per-folder READMEs for Terraform (design decisions, accepted Checkov risks) and Ansible
  - This changelog

### Changed

- **Container registry:** Docker Hub (`iannah/edushare`) → private ACR (`edushareacrgvv9o.azurecr.io/edushare`)
- **Database:** MongoDB container on the VM → managed Azure Cosmos DB for MongoDB
- **Public entry point:** the app VM's public IP → the bastion's public IP (`102.37.10.231`) with Nginx in front
- **Live site:** `http://20.164.222.7` → `http://102.37.10.231`
- **Security workflow:** no longer pushes images; publishing moved into the CD pipeline, after all checks pass

### Removed

- The F3 single-VM Terraform configuration
- Ansible's MongoDB container and the Azure dynamic inventory

### Fixed

- **Resources page failed in production.** Cosmos DB rejected the "most helpful, then newest" sort because it had no compound index. Indexes were added to the `resources` collection in Terraform ([#10](https://github.com/Hannah1563/EduShare-Platform-/pull/10)).
- **First CD deploy failed at the Ansible step.** The `SSH_PRIVATE_KEY` secret was missing the key's `BEGIN`/`END` lines. The secret was corrected and the deploy re-run successfully.

---

## [Formative 3] Infrastructure as Code and DevSecOps (2026-11-07 → 2026-11-13)

The team moved to the fork [Hannah1563/EduShare-Platform-](https://github.com/Hannah1563/EduShare-Platform-), after the original repository's GitHub Actions were blocked by a billing lock on the owner's account.

### Added

- **Terraform for Azure** ([#3](https://github.com/Hannah1563/EduShare-Platform-/pull/3)):
  - Resource group, virtual network, subnet and network security group (SSH from team IPs only, HTTP public, everything else denied)
  - One Ubuntu 24.04 VM with a static public IP in South Africa North
- **Ansible playbook** ([#4](https://github.com/Hannah1563/EduShare-Platform-/pull/4)) with four roles:
  - `common`: updates, base tools, automatic security updates
  - `docker`
  - `security`: UFW, SSH hardening, fail2ban
  - `app`: the app plus a MongoDB container, using the image from Docker Hub

  Secrets are kept in Ansible Vault.
- **Security workflow** ([#1](https://github.com/Hannah1563/EduShare-Platform-/pull/1)):
  - Gitleaks secret scan
  - npm audit dependency scan
  - Trivy image scan
  - Push to Docker Hub after a merge, only if every scan passed
- `SECURITY.md` with scan findings and how each was handled; F3 README sections and an AI Use Annex ([#5](https://github.com/Hannah1563/EduShare-Platform-/pull/5))
- Evidence screenshots for Terraform, Ansible and the security scans ([#2](https://github.com/Hannah1563/EduShare-Platform-/pull/2))

### Changed

- Ansible app port changed to 4000 to match the Dockerfile

### Security

- Upgraded `body-parser` to fix a high-severity denial-of-service issue reported by npm audit
- Removed `npm`, `npx`, `corepack` and `yarn` from the runtime image, which cleared the high-severity Trivy findings in npm's bundled packages
- Accepted Checkov finding `CKV_AZURE_119` (public IP on the VM), with the reason documented

---

## [Formative 2] Containerisation and CI (2026-10-27 → 2026-10-29)

### Added

- Backend linting (ESLint), and Express now serves the built React frontend ([#23](https://github.com/maridadithierry/EduShare-Platform-/pull/23))
- Multi-stage `Dockerfile` (React build, then Node runtime as the non-root `node` user, with a health check) and `.dockerignore` ([#24](https://github.com/maridadithierry/EduShare-Platform-/pull/24))
- `docker-compose.yml` with the app and a MongoDB service: private network, health-checked start order, named volume, credentials from `.env`
- **CI workflow** with backend lint and test, frontend lint and build, and a Docker build that runs only when both pass ([#26](https://github.com/maridadithierry/EduShare-Platform-/pull/26))
- Branch protection on `main` (pull request, one approval, passing checks) ([#26](https://github.com/maridadithierry/EduShare-Platform-/pull/26))
- README sections on Docker Compose, the CI pipeline and CI evidence, including a deliberately failed run and its fix ([#27](https://github.com/maridadithierry/EduShare-Platform-/pull/27), [#28](https://github.com/maridadithierry/EduShare-Platform-/pull/28))

### Fixed

- Test dependencies: moved to Mongoose 8 and pinned the in-memory MongoDB to 7.0.14 ([#21](https://github.com/maridadithierry/EduShare-Platform-/pull/21))
- The Docker build context now excludes nested `node_modules`, `dist` and `.env` files

---

## [Formative 1] First working version (2026-10-18 → 2026-10-27)

### Added

- **Frontend:** React + TypeScript app (Vite) with React Router, a layout shell (navbar, footer) and the Home and Resources pages
- **Frontend API integration:** a resources page that lists, filters by subject and level, and marks resources as helpful ([#6](https://github.com/maridadithierry/EduShare-Platform-/pull/6))
- **Backend:** Express API with MongoDB ([#20](https://github.com/maridadithierry/EduShare-Platform-/pull/20)):
  - List, search and filter resources
  - Create a resource
  - Mark a resource as helpful
  - Flag a resource (hidden after 3 flags)
  - Health check
- Mongoose model, repository layer and seed data
- API tests with Jest, Supertest and an in-memory MongoDB ([#18](https://github.com/maridadithierry/EduShare-Platform-/pull/18))
- **Input safety:** query parameters must be strings (blocks NoSQL injection), search input is escaped, and ids are validated
- README following the course template ([#19](https://github.com/maridadithierry/EduShare-Platform-/pull/19))

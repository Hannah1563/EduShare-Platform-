# Ansible: configure the Summative servers and deploy EduShare

This playbook configures the two VMs that Terraform creates (see `../terraform`) and deploys the app. The CD pipeline runs it on every merge to `main`, with the exact image it just built.

## What runs where

| Host | Reached how | Roles | Result |
|------|-------------|-------|--------|
| `edushare-bastion` (`102.37.10.231`, public subnet) | Directly over SSH | `common`, `security`, `proxy` | Nginx reverse proxy on port 80; UFW allows only 22 (rate-limited) and 80 |
| `edushare-app` (`10.20.2.4`, private subnet, no public IP) | SSH **through the bastion** (`ProxyCommand`) | `common`, `docker`, `security`, `app` | App container pulled from ACR, connected to Cosmos DB; UFW allows 22 and 4000 from the bastion subnet only |

A final step checks `http://localhost/health` on the bastion, which proves the whole path works: Nginx → private VM → app → database.

```
Internet ──80──▶ bastion: Nginx ──4000──▶ app VM: EduShare container ──▶ Cosmos DB
                     ▲                         ▲
Ansible / CD ──22────┘────────22 (jump)────────┘           image pulled from ACR
```

## Roles

| Role | What it does |
|------|--------------|
| `common` | Package updates, base tools, timezone, automatic daily security updates |
| `docker` | Docker Engine + Compose plugin from Docker's signed repository (app VM only) |
| `security` | UFW with per-host rules (`group_vars/bastion.yml`, `group_vars/app.yml`), SSH hardening (no root, no passwords, keys only, validated with `sshd -t`), fail2ban |
| `proxy` | Nginx reverse proxy to the app VM, default site removed, server version hidden, security headers, config checked with `nginx -t` |
| `app` | Logs in to ACR, writes `compose.yaml` and a `0600` `.env`, pulls and starts the container, waits for `/health`; on failure prints `docker compose ps` and logs; prunes old images |

## Layout

```
ansible/
├── ansible.cfg
├── playbook.yml              three plays: bastion, app VM, end-to-end check
├── requirements.yml          collections to install
├── inventory/hosts.ini       bastion + app groups (IPs from Terraform outputs)
├── group_vars/
│   ├── all/vars.yml          image, registry, ports, IPs, SSH key
│   ├── all/vault.yml         ENCRYPTED: Cosmos DB connection string, ACR password
│   ├── all/vault.yml.example template for vault.yml
│   ├── bastion.yml           bastion firewall rules
│   └── app.yml               jump-through-bastion SSH settings + app firewall rules
└── roles/  common  docker  security  proxy  app
```

## Run it

From this folder:

```bash
# 1. Collections
ansible-galaxy collection install -r requirements.yml

# 2. Secrets (once): copy the template, paste the two Terraform outputs, encrypt
cp group_vars/all/vault.yml.example group_vars/all/vault.yml
(cd ../terraform && terraform output -raw mongodb_connection_string; echo)
(cd ../terraform && terraform output -raw acr_admin_password; echo)
ansible-vault encrypt group_vars/all/vault.yml

# 3. Check Ansible can reach both VMs (the app VM through the bastion)
ansible edushare -m ping

# 4. Configure everything and deploy
ansible-playbook playbook.yml --ask-vault-pass
```

Other useful runs:

```bash
ansible-playbook playbook.yml --ask-vault-pass --check --diff          # dry run
ansible-playbook playbook.yml --ask-vault-pass --tags app,verify       # redeploy only
ansible-playbook playbook.yml --ask-vault-pass -e app_image_tag=<sha>  # deploy one exact build
```

Your SSH key defaults to `~/.ssh/alu-devops`. Use another with `export EDUSHARE_SSH_KEY=/path/to/key`. The CD pipeline uses this to point at its deploy key.

## How the CD pipeline uses it

The pipeline writes the deploy key and the vault password from GitHub secrets, opens SSH on the bastion for the runner's IP, then runs:

```bash
EDUSHARE_SSH_KEY=~/.ssh/deploy_key \
ansible-playbook playbook.yml --vault-password-file <file> -e app_image_tag=${GITHUB_SHA}
```

Because the tag is the commit SHA, every deploy is traceable to one commit and can be rolled back by redeploying an older SHA.

## Security notes

- **No public IP on the app VM**: it is reachable only through the bastion, on SSH and the app port.
- **Defence in depth**: Azure NSGs (Terraform) and UFW (Ansible) both restrict traffic. Docker-published ports bypass UFW, so for port 4000 the NSG is the enforcing layer; it allows only the bastion subnet.
- **Secrets**: only in the encrypted `vault.yml`; on the server in `/opt/edushare/.env` (`0600`, root only); tasks that handle them use `no_log`.
- **Container**: runs as the non-root `node` user with all Linux capabilities dropped and `no-new-privileges`.
- **Idempotent**: a second run changes nothing; services restart only through handlers when their config changed.

## Troubleshooting

| Problem | Fix |
|---|---|
| `UNREACHABLE` / timeout on the bastion | Your IP is not in Terraform's `allowed_ssh_cidrs`: add it and `terraform apply` |
| `UNREACHABLE` on the app VM only | Check the bastion works first; then `ssh-keygen -R 10.20.2.4` if the VM was rebuilt |
| `Attempting to decrypt but no vault secrets found` | Add `--ask-vault-pass` |
| `pull access denied` / `manifest unknown` | The image or tag is not in ACR yet: push it (CD pipeline or manual push) |
| Health check fails | Read the logs the rescue step prints; on the VM: `cd /opt/edushare && sudo docker compose logs` |

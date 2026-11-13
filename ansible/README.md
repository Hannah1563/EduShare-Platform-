# Ansible: configure and deploy EduShare

This playbook turns the empty Ubuntu VM that Terraform creates (see `../terraform`) into a running EduShare server. One command installs Docker, hardens the server and starts the app with MongoDB.

## What the playbook does

| Role | What it does |
|------|--------------|
| `common` | Updates packages, installs base tools, sets the timezone, turns on automatic security updates |
| `docker` | Installs Docker Engine and the Compose plugin from Docker's official repository |
| `security` | UFW firewall (deny all incoming except SSH and HTTP), SSH hardening (no root login, no passwords, keys only), fail2ban for repeated SSH failures |
| `app` | Writes the compose and `.env` files, pulls the app image from Docker Hub, starts app + MongoDB, checks `/health` |

The server **pulls** the image; it never builds it. MongoDB has no published port, so only the app container can reach it.

## Folder layout

```
ansible/
├── ansible.cfg                  # default inventory, SSH user and key
├── requirements.yml             # Ansible collections to install
├── playbook.yml                 # runs the four roles in order
├── inventory/
│   ├── hosts.ini                # static inventory (VM IP from Terraform)
│   └── azure_rm.yml             # dynamic Azure inventory
├── group_vars/edushare/
│   ├── vars.yml                 # image, ports, paths, security settings
│   ├── vault.yml.example        # template for secrets
│   └── vault.yml                # encrypted secrets (ansible-vault)
└── roles/
    ├── common/
    ├── docker/
    ├── security/
    └── app/
```

## Prerequisites

- Ansible 2.15+ on your machine: `pip install ansible` (or `brew install ansible` on macOS)
- The VM created with Terraform, with **your SSH public key** on it
- Your private key at `~/.ssh/alu-devops` (change `private_key_file` in `ansible.cfg` if yours is elsewhere)
- The app image pushed to Docker Hub (`iannah/edushare:latest` by default, see `vars.yml`)

## How to run it

All commands run from the `ansible/` folder.

**1. Install the collections**

```bash
ansible-galaxy collection install -r requirements.yml
```

**2. Point the inventory at the VM**

Get the IP and username from Terraform:

```bash
cd ../terraform && terraform output && cd ../ansible
```

Put the IP in `inventory/hosts.ini` in place of `REPLACE_WITH_VM_PUBLIC_IP`, and make sure `ansible_user` matches `admin_username`.

**3. Create the secrets file**

```bash
cp group_vars/edushare/vault.yml.example group_vars/edushare/vault.yml
# edit vault.yml and set a long random MongoDB password
ansible-vault encrypt group_vars/edushare/vault.yml
```

Share the vault password with teammates privately, never in the repo.

**4. Check the connection**

```bash
ansible edushare -m ping
```

**5. Run the playbook**

```bash
ansible-playbook playbook.yml --ask-vault-pass
```

Preview without changing anything: add `--check --diff`.

**6. Open the app**

`http://<vm_public_ip>` in a browser, or `curl http://<vm_public_ip>/health`.

## Using the dynamic Azure inventory instead

The dynamic inventory finds the VM by its resource group, so the IP never needs copying.

```bash
pip install -r ~/.ansible/collections/ansible_collections/azure/azcollection/requirements.txt
az login
export EDUSHARE_RESOURCE_GROUP=<resource group from terraform output>
ansible-inventory -i inventory/azure_rm.yml --graph
ansible-playbook -i inventory/azure_rm.yml playbook.yml --ask-vault-pass
```

## Security measures

- **Firewall:** UFW denies all incoming traffic except SSH (22, rate-limited) and HTTP (80). The Azure NSG adds a second layer and limits SSH to the team's IPs.
- **SSH:** root login and password logins are disabled; only key-based logins for the admin user are accepted. The config is checked with `sshd -t` before it is applied, so a mistake cannot lock everyone out.
- **fail2ban:** bans an IP for 1 hour after 5 failed SSH logins within 10 minutes.
- **Automatic security updates** through `unattended-upgrades`.
- **Secrets:** the MongoDB password is stored only in the encrypted `vault.yml`. On the server it is written to `/opt/edushare/.env` with `0600` permissions, and the tasks that handle it use `no_log`.
- **Database isolation:** MongoDB has no published port and is reachable only on the private Docker network.

## Useful commands on the server

```bash
ssh -i ~/.ssh/alu-devops azureuser@<vm_public_ip>
cd /opt/edushare && sudo docker compose ps        # container status
sudo docker compose logs -f app                   # app logs
sudo ufw status verbose                           # firewall rules
sudo fail2ban-client status sshd                  # banned IPs
```

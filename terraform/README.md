# EduShare infrastructure (Terraform, Azure)

This folder provisions the production environment for EduShare: a private network, a bastion host that is the only public entry point, a private application VM, a managed MongoDB-compatible database and a private container registry. Ansible (`../ansible`) then configures both VMs and deploys the app, and the CD pipeline (`../.github/workflows/cd.yml`) does that automatically on every merge to `main`.

## Architecture

```
                         Internet
                            │
             80 (website)   │   22 (team IPs + CD runner, temporary)
                            ▼
┌──────────────────────── edushare-prod-vnet 10.20.0.0/16 ────────────────────────┐
│                                                                                 │
│  public subnet 10.20.1.0/24          private subnet 10.20.2.0/24                │
│  ┌─────────────────────────┐         ┌────────────────────────────┐             │
│  │ edushare-prod-bastion-vm│ ──22──▶ │ edushare-prod-app-vm       │             │
│  │ public IP, Nginx proxy  │ ─4000─▶ │ no public IP, Docker + app │             │
│  └─────────────────────────┘         └──────┬──────────┬──────────┘             │
│   NSG: 22 team IPs, 80 internet             │          │   NSG: 22 + 4000 from   │
│                                             │          │   public subnet only    │
└─────────────────────────────────────────────┼──────────┼─────────────────────────┘
                                              │          │
                          service endpoint    │          │  NAT gateway (outbound only)
                                              ▼          ▼
                              Cosmos DB for MongoDB    internet: apt, Docker, ACR pull
                              (VNet filter: private         │
                               subnet only)                 ▼
                                                   Azure Container Registry (private)
```

| Resource | Name | Purpose |
|----------|------|---------|
| Virtual network | `edushare-prod-vnet` | Private network, two subnets |
| Bastion VM | `edushare-prod-bastion-vm` | Only public IP. SSH jump host and Nginx reverse proxy for the website |
| App VM | `edushare-prod-app-vm` | Runs the app container. Private subnet, no public IP |
| NSGs | `edushare-prod-public-nsg`, `edushare-prod-private-nsg` | Public: 22 from team IPs, 80 from internet. Private: 22 and 4000 from the bastion subnet only, everything else denied |
| NAT gateway | `edushare-prod-natgw` | Outbound internet for the private VM, with nothing inbound |
| Managed database | `edushare-prod-cosmos-<suffix>` | Azure Cosmos DB for MongoDB (free tier), reachable only from the private subnet |
| Container registry | `edushareacr<suffix>` | Private registry for the app image |

## Layout

```
terraform/
├── versions.tf               Terraform + provider versions, remote state backend
├── backend.hcl               where the remote state lives (no secrets)
├── variables.tf              all inputs, with validation rules
├── main.tf                   wires the modules together
├── outputs.tf                IPs, registry, DB connection string, SSH commands
├── terraform.tfvars.example  copy to terraform.tfvars and fill in
└── modules/
    ├── network/              VNet, public + private subnets, NAT gateway, NSGs
    ├── compute/              one Ubuntu 24.04 VM (used for bastion and app VM)
    ├── database/             Cosmos DB account, database, collection
    └── registry/             Azure Container Registry
```

## One-time setup (subscription owner)

The team deploys with a service principal that is **Contributor on one resource group only**, so it cannot touch anything else in the subscription. The owner does this once:

```bash
az group create --name edushare-summative-rg --location southafricanorth
az ad sp create-for-rbac --name edushare-summative-sp --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/edushare-summative-rg

# The service principal cannot register providers, so register these once:
az provider register --namespace Microsoft.DocumentDB
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Storage
```

Remote state lives in the storage account `edusharetfstate29373`, container `tfstate`, in the same resource group.

## Usage

```bash
# 1. Log in as the service principal (values from the subscription owner)
export ARM_CLIENT_ID=<appId>
export ARM_CLIENT_SECRET=<password>
export ARM_TENANT_ID=<tenant>
export ARM_SUBSCRIPTION_ID=<subscription id>

# 2. Fill in your settings
cd terraform
cp terraform.tfvars.example terraform.tfvars   # add your IP and public key

# 3. Initialise with the shared remote state, then preview and apply
terraform init -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Read the outputs that Ansible and the CD pipeline need:

```bash
terraform output                              # everything that is not secret
terraform output -raw mongodb_connection_string   # secret: goes into Ansible Vault / GitHub secret
terraform output -raw acr_admin_password          # secret
```

Tear everything down after grading: `terraform destroy`. The resource group and the state storage account stay, because they are not managed by this configuration.

## Design decisions

- **Bastion as the only public entry point.** The app VM has no public IP. The bastion runs Nginx as a reverse proxy for the website and is the SSH jump host. This is cheaper than an Azure Load Balancer and Azure Bastion, and keeps a single, small attack surface.
- **NSG rules as separate resources.** The CD pipeline adds a temporary SSH rule for its runner's IP and removes it after deploying. Separate rule resources mean Terraform never deletes a rule it does not own.
- **Explicit deny inside the VNet.** Azure allows all VNet traffic by default; the private NSG overrides that so only the bastion can reach the app VM, and only on ports 22 and 4000.
- **Private subnet with a NAT gateway.** The app VM gets outbound internet (packages, images) but nothing can connect in from outside.
- **Cosmos DB for MongoDB.** A managed database that works with the existing Mongoose code; locked to the private subnet with a service endpoint (free) instead of a private endpoint (paid).
- **Least-privilege deploy identity.** The service principal can only manage this resource group.
- **Remote state.** Every teammate and the pipeline share one state file, so `terraform plan` shows the real infrastructure.

## Accepted risks (Checkov)

| Check | Why it is accepted |
|-------|--------------------|
| `CKV_AZURE_119` public IP on a NIC | Only the bastion gets one; SSH is limited to team IPs |
| `CKV_AZURE_160` port 80 open | It serves the public website |
| `CKV_AZURE_137` ACR admin user | The service principal cannot create AcrPull role assignments; the credentials stay in GitHub secrets and Ansible Vault |
| `CKV_AZURE_100/140/101` Cosmos DB | Microsoft-managed encryption keys; the Mongo API needs key auth; public endpoint is locked to the private subnet |
| `CKV_AZURE_139/164/165/166/167/233/237` ACR | Premium-tier features; images are scanned by Trivy before they are pushed |

Checkov: 49 passed, 0 failed, 15 skipped (each with a reason inline in the code).

## Troubleshooting

| Problem | Fix |
|---|---|
| `SkuNotAvailable` | Try another size: `az vm list-skus --location southafricanorth --size Standard_B -o table` |
| `QuotaExceeded` (vCPUs) | The subscription allows 4 vCPUs here and each VM uses 2. Delete other VMs first |
| `MissingSubscriptionRegistration` | The owner runs the `az provider register` commands above |
| Free tier error on Cosmos DB | Only one free-tier account per subscription: set `cosmos_free_tier = false` |
| Backend `403` | Check the `ARM_*` variables are set in this terminal |

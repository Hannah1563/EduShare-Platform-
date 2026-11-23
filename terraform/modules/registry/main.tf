# Private container registry (Azure Container Registry, Basic tier).
# The CD pipeline pushes the app image here; the app VM pulls it.

resource "azurerm_container_registry" "main" {
  #checkov:skip=CKV_AZURE_137:Admin user is used for the VM's pull credentials: the service principal is Contributor only and cannot create AcrPull role assignments. Credentials stay in GitHub secrets / Ansible Vault (see SECURITY.md)
  #checkov:skip=CKV_AZURE_139:Private endpoints and network rules require the Premium tier
  #checkov:skip=CKV_AZURE_163:Built-in vulnerability scanning requires Defender for Cloud; images are scanned with Trivy in CI before they are pushed
  #checkov:skip=CKV_AZURE_164:Content trust (signed images) requires the Premium tier
  #checkov:skip=CKV_AZURE_165:Geo-replication requires the Premium tier and is not needed for one region
  #checkov:skip=CKV_AZURE_166:Quarantine requires the Premium tier; Trivy gates images in CI instead
  #checkov:skip=CKV_AZURE_167:Retention policy requires the Premium tier
  #checkov:skip=CKV_AZURE_233:Zone redundancy requires the Premium tier
  #checkov:skip=CKV_AZURE_237:Dedicated data endpoints require the Premium tier
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Basic"
  admin_enabled       = true
  tags                = var.tags
}

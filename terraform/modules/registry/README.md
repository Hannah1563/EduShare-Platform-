# registry module

Private Azure Container Registry (Basic tier). The CD pipeline pushes `<login_server>/edushare:<commit SHA>` and `:latest`; the app VM pulls with the registry credentials stored in Ansible Vault.

Outputs: `name`, `id`, `login_server`, `admin_username`, `admin_password` (sensitive).

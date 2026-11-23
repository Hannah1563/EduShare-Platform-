# Remote state location (no secrets here; access uses the ARM_* login).
resource_group_name  = "edushare-summative-rg"
storage_account_name = "edusharetfstate29373"
container_name       = "tfstate"
key                  = "summative.tfstate"

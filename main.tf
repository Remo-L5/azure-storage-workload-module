module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.6.7"

  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  account_kind                      = local.selected_account_type.account_kind
  account_tier                      = local.selected_account_type.account_tier
  account_replication_type          = local.resolved_account_replication_type
  access_tier                       = local.resolved_access_tier
  is_hns_enabled                    = local.selected_account_type.is_hns_enabled
  large_file_share_enabled          = local.resolved_large_file_share_enabled
  nfsv3_enabled                     = local.nfs_requested
  provisioned_billing_model_version = local.active_share_billing_model == "provisioned_v2" ? "V2" : null

  containers = local.final_containers
  shares     = local.final_shares

  azure_files_authentication    = var.azure_files_authentication
  customer_managed_key          = var.customer_managed_key
  enable_telemetry              = var.enable_telemetry
  https_traffic_only_enabled    = var.https_traffic_only_enabled
  managed_identities            = var.managed_identities
  min_tls_version               = var.min_tls_version
  network_rules                 = var.network_rules
  public_network_access_enabled = var.public_network_access_enabled
  role_assignments              = var.role_assignments
  routing                       = var.routing
  tags                          = var.tags
}

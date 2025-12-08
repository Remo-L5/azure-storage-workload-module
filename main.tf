module "storage_account" {
  for_each = local.storage_accounts

  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.6.7"

  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name

  account_kind                      = each.value.account_kind
  account_tier                      = each.value.account_tier
  account_replication_type          = each.value.account_replication_type
  access_tier                       = each.value.access_tier
  is_hns_enabled                    = each.value.is_hns_enabled
  large_file_share_enabled          = each.value.large_file_share_enabled
  nfsv3_enabled                     = each.value.nfsv3_enabled
  provisioned_billing_model_version = each.value.provisioned_billing_model_version

  containers = each.value.containers
  shares     = each.value.shares

  azure_files_authentication    = each.value.azure_files_authentication
  enable_telemetry              = var.enable_telemetry
  https_traffic_only_enabled    = each.value.https_traffic_only_enabled
  min_tls_version               = each.value.min_tls_version
  network_rules                 = each.value.network_rules
  public_network_access_enabled = each.value.public_network_access_enabled
  role_assignments              = each.value.role_assignments
  tags                          = each.value.tags
}

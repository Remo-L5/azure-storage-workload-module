output "resources" {
  description = "Full storage account objects returned by the AVM module, keyed by storage_accounts map key."
  value = {
    for key, mod in module.storage_account :
    key => mod.resource
  }
}

output "file_shares" {
  description = "File share outputs returned by the AVM module, keyed by storage_accounts map key."
  value = {
    for key, mod in module.storage_account :
    key => mod.shares
  }
  sensitive = true
}

output "containers" {
  description = "Blob container outputs returned by the AVM module, keyed by storage_accounts map key."
  value = {
    for key, mod in module.storage_account :
    key => mod.containers
  }
}

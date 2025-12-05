output "resource" {
  description = "Full storage account object returned by the AVM module."
  value       = module.storage_account.resource
}

output "shares" {
  description = "Map of file share outputs returned by the AVM module."
  value       = module.storage_account.shares
  sensitive   = true
}

output "containers" {
  description = "Map of blob container outputs returned by the AVM module."
  value       = module.storage_account.containers
}

variable "location" {
  description = "Azure region where all storage accounts will be created."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that will contain every storage account provisioned by this module."
  type        = string
}

variable "application_short_name" {
  description = "Short identifier used when generating storage account names (e.g. 'payments')."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", lower(var.application_short_name)))
    error_message = "application_short_name must be 2-20 characters containing lowercase letters, numbers, or hyphens."
  }
}

variable "enable_telemetry" {
  type        = bool
  description = "Enable AVM telemetry."
  default     = true
}

variable "tags" {
  description = "Global tags applied to every storage account. Account-specific tags can be supplied inside storage_accounts entries."
  type        = map(string)
  default     = {}
}

variable "storage_accounts" {
  description = "Map of storage account definitions to provision. Map keys are referenced by blob containers and file shares."
  type = map(object({
    account_type                  = string
    account_replication_type      = optional(string, "LRS")
    access_tier                   = optional(string)
    large_file_share_enabled      = optional(bool)
    public_network_access_enabled = optional(bool, false)
    domain_join_enabled           = optional(bool)
    file_share_billing_model      = optional(string)
    role_assignments = optional(map(object({
      role_definition_id_or_name       = string
      principal_id                     = string
      principal_type                   = optional(string, null)
      description                      = optional(string, null)
      skip_service_principal_aad_check = optional(bool, false)
      condition                        = optional(string, null)
      condition_version                = optional(string, null)
    })), {})
  }))

  validation {
    condition     = length(var.storage_accounts) > 0
    error_message = "Provide at least one storage account definition."
  }

  validation {
    condition = alltrue([
      for acct in values(var.storage_accounts) : contains(["blob_gpv2", "file_gpv2", "file_share_tx"], lower(acct.account_type))
    ])
    error_message = "storage_accounts.*.account_type must be blob_gpv2, file_gpv2, or file_share_tx."
  }

  validation {
    condition = alltrue([
      for acct in values(var.storage_accounts) : (
        acct.account_replication_type == null ||
        contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], upper(acct.account_replication_type))
      )
    ])
    error_message = "storage_accounts.*.account_replication_type must be one of LRS, GRS, RAGRS, ZRS, GZRS, or RAGZRS."
  }

  validation {
    condition = alltrue([
      for acct_k, acct_v in values(var.storage_accounts) : (
        lower(acct_v.account_type) != "file_share_tx" ||
        acct_v.account_replication_type == null ||
        contains(["LRS", "ZRS"], upper(acct_v.account_replication_type))
      )
    ])
    error_message = "file_share_tx accounts support only LRS or ZRS replication."
  }

  validation {
    condition = alltrue([
      for acct_k, acct_v in values(var.storage_accounts) : (
        (acct_v.access_tier == null && lower(acct_v.account_type) == "file_share_tx") ||
        contains(["HOT", "COOL", "COLD", "PREMIUM"], upper(acct_v.access_tier))
      )
    ])
    error_message = "storage_accounts.*.access_tier must be Hot, Cool, Cold, or Premium."
  }

  validation {
    condition = alltrue([
      for acct_k, acct_v in values(var.storage_accounts) : (
        lower(acct_v.account_type) != "file_share_tx" || acct_v.access_tier == null || upper(acct_v.access_tier) == "PREMIUM"
      )
    ])
    error_message = "file_share_tx entries must omit access_tier or set it to Premium."
  }

  validation {
    condition = alltrue([
      for acct_k, acct_v in values(var.storage_accounts) : (
        acct_v.file_share_billing_model == null ||
        contains(["paygo", "provisioned_v2"], lower(acct_v.file_share_billing_model))
      )
    ])
    error_message = "storage_accounts.*.file_share_billing_model must be paygo or provisioned_v2 when supplied."
  }

  validation {
    condition = alltrue([
      for acct_k, acct_v in values(var.storage_accounts) : (
        acct_v.file_share_billing_model == null ||
        (
          lower(acct_v.file_share_billing_model) == "paygo" && lower(acct_v.account_type) == "file_gpv2"
        ) ||
        (
          lower(acct_v.file_share_billing_model) == "provisioned_v2" && lower(acct_v.account_type) == "file_share_tx"
        )
      )
    ])
    error_message = "Use file_share_billing_model=paygo only with file_gpv2 accounts and provisioned_v2 only with file_share_tx accounts."
  }

  validation {
    condition = alltrue([
      for acct in values(var.storage_accounts) : lower(acct.account_type) != "blob_gpv2" || acct.file_share_billing_model == null
    ])
    error_message = "blob_gpv2 accounts do not expose Azure Files; omit file_share_billing_model."
  }

  validation {
    condition = alltrue([
      for acct in values(var.storage_accounts) : (
        !coalesce(acct.domain_join_enabled, false) ||
        contains(["file_gpv2", "file_share_tx"], lower(acct.account_type))
      )
    ])
    error_message = "domain_join_enabled can only be true for file_gpv2 or file_share_tx accounts."
  }
}

variable "network_rules" {
  description = "Global network rules applied to every storage account."
  type = object({
    bypass                     = optional(set(string), [])
    default_action             = optional(string, "Allow")
    ip_rules                   = optional(list(string), [])
    virtual_network_subnet_ids = optional(set(string), [])
    private_link_access = optional(set(object({
      endpoint_resource_id = string
      endpoint_tenant_id   = optional(string)
    })), [])
    resource_access_rules = optional(set(object({
      endpoint_resource_id = string
      endpoint_tenant_id   = optional(string)
    })), [])
  })
  default = null
}

variable "azure_files_authentication" {
  description = "Azure Files authentication settings applied when a storage account is domain joined."
  type = object({
    directory_type                 = optional(string, "AADKERB")
    default_share_level_permission = optional(string)
    active_directory = optional(object({
      domain_guid         = string
      domain_name         = string
      domain_sid          = optional(string)
      forest_name         = optional(string)
      netbios_domain_name = optional(string)
      storage_sid         = optional(string)
    }))
  })
  default = null

  validation {
    condition = (
      var.azure_files_authentication != null ||
      alltrue([
        for acct_key, acct in var.storage_accounts : (
          !coalesce(acct.domain_join_enabled, false) ||
          length([
            for share in values(var.file_shares) : share
            if contains(share.storage_account_map_keys, acct_key)
          ]) == 0
        )
      ])
    )
    error_message = "Provide azure_files_authentication when a domain_join_enabled storage account hosts file shares."
  }
}

variable "blob_containers" {
  description = "Blob containers to fan-out into one or more storage accounts."
  type = map(object({
    storage_account_map_keys          = list(string)
    metadata                          = optional(map(string), {})
    change_feed_enabled               = optional(bool)
    default_encryption_scope          = optional(string)
    prevent_encryption_scope_override = optional(bool)
    versioning_enabled                = optional(bool, false)
    role_assignments = optional(map(object({
      role_definition_id_or_name       = string
      principal_id                     = string
      principal_type                   = optional(string, null)
      description                      = optional(string, null)
      skip_service_principal_aad_check = optional(bool, false)
      condition                        = optional(string, null)
      condition_version                = optional(string, null)
    })), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for container in values(var.blob_containers) : length(container.storage_account_map_keys) > 0
    ])
    error_message = "Every blob container entry must reference at least one storage account via storage_account_map_keys."
  }

  validation {
    condition = alltrue([
      for container in values(var.blob_containers) : length(setsubtract(toset(container.storage_account_map_keys), toset(keys(var.storage_accounts)))) == 0
    ])
    error_message = "blob_containers.*.storage_account_map_keys must reference keys defined in storage_accounts."
  }

  validation {
    condition = alltrue([
      for container in values(var.blob_containers) : alltrue([
        for account_key in container.storage_account_map_keys : lower(var.storage_accounts[account_key].account_type) != "file_share_tx"
      ])
    ])
    error_message = "blob_containers cannot target file_share_tx accounts because FileStorage does not expose the blob service."
  }
}

variable "file_shares" {
  description = "File shares to fan-out into one or more storage accounts."
  type = map(object({
    storage_account_map_keys = list(string)
    size                     = optional(string)
    quota_gb                 = optional(number)
    protocol                 = optional(string, "SMB")
    access_tier              = optional(string, "Hot")
    metadata                 = optional(map(string), {})
    role_assignments = optional(map(object({
      role_definition_id_or_name       = string
      principal_id                     = string
      principal_type                   = optional(string, null)
      description                      = optional(string, null)
      skip_service_principal_aad_check = optional(bool, false)
      condition                        = optional(string, null)
      condition_version                = optional(string, null)
    })), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for share in values(var.file_shares) : length(share.storage_account_map_keys) > 0
    ])
    error_message = "Every file share entry must reference at least one storage account via storage_account_map_keys."
  }

  validation {
    condition = alltrue([
      for share in values(var.file_shares) : length(setsubtract(toset(share.storage_account_map_keys), toset(keys(var.storage_accounts)))) == 0
    ])
    error_message = "file_shares.*.storage_account_map_keys must reference keys defined in storage_accounts."
  }

  validation {
    condition = alltrue([
      for share in values(var.file_shares) : (
        share.size == null || contains(["small", "medium", "large", "xlarge"], lower(share.size))
      )
    ])
    error_message = "file_shares.*.size must be one of small, medium, large, or xlarge when provided."
  }

  validation {
    condition = alltrue([
      for share in values(var.file_shares) : contains(["SMB", "NFS"], upper(share.protocol))
    ])
    error_message = "file_shares.*.protocol must be SMB or NFS."
  }

  validation {
    condition = alltrue([
      for share in values(var.file_shares) : (
        share.access_tier == null ||
        contains(["HOT", "COOL", "PREMIUM", "TRANSACTION"], upper(share.access_tier))
      )
    ])
    error_message = "file_shares.*.access_tier must be Hot, Cool, Transaction, or Premium when specified."
  }

  validation {
    condition = alltrue([
      for share in values(var.file_shares) : alltrue([
        for account_key in share.storage_account_map_keys : contains(["file_gpv2", "file_share_tx"], lower(var.storage_accounts[account_key].account_type))
      ])
    ])
    error_message = "file_shares can only target file_gpv2 or file_share_tx storage accounts."
  }

  validation {
    condition = alltrue([
      for share in values(var.file_shares) : (
        upper(share.protocol) != "NFS" || alltrue([
          for account_key in share.storage_account_map_keys : lower(var.storage_accounts[account_key].account_type) == "file_share_tx"
        ])
      )
    ])
    error_message = "NFS shares are only supported on file_share_tx storage accounts."
  }
}

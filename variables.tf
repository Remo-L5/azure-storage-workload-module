variable "location" {
  description = "Azure region where the storage account will be created."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that will contain the storage account."
  type        = string
}

variable "name" {
  description = "Name of the storage account. Must already satisfy Azure naming rules (3-24 lowercase alphanumerics)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.name))
    error_message = "Storage account names must be 3-24 characters long and contain only lowercase letters or numbers."
  }
}

variable "account_type" {
  description = "Wrapper flavor that determines defaults for account kind, tier, replication, and whether file shares are supported."
  type        = string

  validation {
    condition     = contains(["blob_gpv2", "file_gpv2", "file_share_tx"], var.account_type)
    error_message = "account_type must be one of blob_gpv2, file_gpv2, or file_share_tx."
  }
}

variable "account_replication_type" {
  description = "Optional override for the account replication type (e.g. LRS, ZRS). Defaults are derived from account_type."
  type        = string
  default     = null

  validation {
    condition = (
      var.account_replication_type == null ||
      contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], upper(var.account_replication_type))
    )
    error_message = "account_replication_type must be one of LRS, GRS, RAGRS, ZRS, GZRS, or RAGZRS."
  }

  validation {
    condition = (
      var.account_type != "file_share_tx" ||
      var.account_replication_type == null ||
      contains(["LRS", "ZRS"], upper(var.account_replication_type))
    )
    error_message = "FileStorage accounts only support LRS or ZRS replication."
  }
}

variable "access_tier" {
  description = "Optional override for the storage account access tier. Not applied to FileStorage accounts."
  type        = string
  default     = null

  validation {
    condition = (
      var.access_tier == null ||
      contains(["HOT", "COOL", "COLD", "PREMIUM"], upper(var.access_tier))
    )
    error_message = "access_tier must be one of Hot, Cool, Cold, or Premium."
  }

  validation {
    condition     = var.account_type != "file_share_tx" || var.access_tier == null
    error_message = "access_tier cannot be set for FileStorage (file_share_tx) accounts."
  }
}

variable "large_file_share_enabled" {
  description = "Optional override for the Large File Share feature. Defaults are driven by account_type."
  type        = bool
  default     = null
}

variable "https_traffic_only_enabled" {
  description = "Whether HTTPS-only traffic should be enforced."
  type        = bool
  default     = true
}

variable "min_tls_version" {
  description = "Minimum TLS version supported by the account."
  type        = string
  default     = "TLS1_2"

  validation {
    condition     = contains(["TLS1_0", "TLS1_1", "TLS1_2", "TLS1_3"], upper(var.min_tls_version))
    error_message = "min_tls_version must be TLS1_0, TLS1_1, TLS1_2, or TLS1_3."
  }
}

variable "public_network_access_enabled" {
  description = "Controls the Public Network Access setting on the storage account."
  type        = bool
  default     = true
}

variable "enable_telemetry" {
  description = "Pass-through toggle for AVM telemetry."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the storage account and all managed child resources."
  type        = map(string)
  default     = {}
}

variable "managed_identities" {
  description = "Optional managed identity configuration applied to the storage account."
  type = object({
    system_assigned            = optional(bool, true)
    user_assigned_resource_ids = optional(set(string), [])
  })
  default = null
}

variable "network_rules" {
  description = "Optional network rules block passed to the AVM module."
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
    timeouts = optional(object({
      create = optional(string)
      read   = optional(string)
      update = optional(string)
      delete = optional(string)
    }))
  })
  default = null
}

variable "role_assignments" {
  description = "Role assignments applied at the storage account scope."
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    principal_type                         = optional(string, null)
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
  }))
  default = {}
}

variable "azure_files_authentication" {
  description = "Optional Azure Files authentication configuration (AADDS, AD, or AADKERB)."
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
}

variable "customer_managed_key" {
  description = "Optional customer-managed key configuration for encryption."
  type = object({
    key_vault_key_id          = string
    user_assigned_identity_id = optional(string)
  })
  default = null
}

variable "routing" {
  description = "Optional routing configuration passed to the storage account."
  type = object({
    choice                      = optional(string, "MicrosoftRouting")
    publish_internet_endpoints  = optional(bool, false)
    publish_microsoft_endpoints = optional(bool, false)
  })
  default = null
}

variable "blob_containers" {
  description = "Optional blob containers to create. Keys are friendly names used to derive actual container names."
  type = map(object({
    name_override                     = optional(string)
    public_access                     = optional(string, "None")
    metadata                          = optional(map(string), {})
    change_feed_enabled               = optional(bool)
    default_encryption_scope          = optional(string)
    prevent_encryption_scope_override = optional(bool)
    versioning_enabled                = optional(bool)
    legal_hold = optional(object({
      tags = set(string)
    }))
    immutability_policy = optional(object({
      type  = string
      state = optional(string, "Unlocked")
      days  = number
    }))
    role_assignments = optional(map(object({
      role_definition_id_or_name             = string
      principal_id                           = string
      principal_type                         = optional(string, null)
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
    })), {})
  }))
  default = {}

  validation {
    condition     = var.account_type != "file_share_tx" || length(var.blob_containers) == 0
    error_message = "blob_containers cannot be specified when account_type is file_share_tx because FileStorage accounts do not expose the blob service."
  }

  validation {
    condition = alltrue([
      for container in values(var.blob_containers) : contains(["BLOB", "CONTAINER", "NONE"], upper(coalesce(container.public_access, "None")))
    ])
    error_message = "blob_containers.*.public_access must be Container, Blob, or None."
  }
}

variable "file_share_billing_model" {
  description = "Optional override for the billing model applied to SMB file shares. Defaults are derived from account_type."
  type        = string
  default     = null

  validation {
    condition = (
      var.file_share_billing_model == null ||
      contains(["paygo", "provisioned_v2"], lower(var.file_share_billing_model))
    )
    error_message = "file_share_billing_model must be paygo or provisioned_v2."
  }

  validation {
    condition = (
      var.file_share_billing_model == null ||
      var.account_type != "blob_gpv2"
    )
    error_message = "file_share_billing_model cannot be set when the selected account_type does not expose file shares."
  }

  validation {
    condition = (
      var.file_share_billing_model == null ||
      (lower(var.file_share_billing_model) == "paygo" && var.account_type == "file_gpv2") ||
      (lower(var.file_share_billing_model) == "provisioned_v2" && var.account_type == "file_share_tx")
    )
    error_message = "Use paygo only with file_gpv2 accounts and provisioned_v2 only with file_share_tx accounts."
  }
}

variable "default_share_size" {
  description = "Default t-shirt size applied to file shares when a share-specific size is not provided."
  type        = string
  default     = "medium"

  validation {
    condition     = contains(["small", "medium", "large", "xlarge"], lower(var.default_share_size))
    error_message = "default_share_size must be one of small, medium, large, or xlarge."
  }
}

variable "file_shares" {
  description = "File shares to create when the selected account_type supports them. Each entry represents one share."
  type = map(object({
    name_override = optional(string)
    size          = optional(string)
    quota_gb      = optional(number)
    protocol      = optional(string, "SMB")
    access_tier   = optional(string)
    metadata      = optional(map(string), {})
    root_squash   = optional(string)
    signed_identifiers = optional(list(object({
      id = string
      access_policy = optional(object({
        expiry_time = string
        permission  = string
        start_time  = string
      }))
    })), [])
    role_assignments = optional(map(object({
      role_definition_id_or_name             = string
      principal_id                           = string
      principal_type                         = optional(string, null)
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
    })), {})
  }))
  default = {}

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
        share.access_tier == null || contains(["HOT", "COOL", "PREMIUM", "TRANSACTIONOPTIMIZED"], upper(share.access_tier))
      )
    ])
    error_message = "file_shares.*.access_tier must be Hot, Cool, TransactionOptimized, or Premium when specified."
  }

  validation {
    condition = alltrue([
      for share in values(var.file_shares) : (
        upper(share.protocol) != "NFS" || var.account_type == "file_share_tx"
      )
    ])
    error_message = "NFS shares are only supported when account_type is file_share_tx."
  }

  validation {
    condition     = var.account_type != "blob_gpv2" || length(var.file_shares) == 0
    error_message = "file_shares cannot be specified when account_type is blob_gpv2."
  }
}

locals {
  account_type_matrix = {
    blob_gpv2 = {
      account_kind             = "StorageV2"
      account_tier             = "Standard"
      account_replication_type = "ZRS"
      access_tier              = "Hot"
      allow_file_shares        = false
      default_large_share      = false
      share_billing_model      = null
    }
    file_gpv2 = {
      account_kind             = "StorageV2"
      account_tier             = "Standard"
      account_replication_type = "ZRS"
      access_tier              = "Hot"
      allow_file_shares        = true
      default_large_share      = true
      share_billing_model      = "paygo"
    }
    file_share_tx = {
      account_kind             = "FileStorage"
      account_tier             = "Premium"
      account_replication_type = "ZRS"
      access_tier              = null
      allow_file_shares        = true
      default_large_share      = true
      share_billing_model      = "provisioned_v2"
    }
  }

  default_share_size_key = "medium"

  share_size_matrix = {
    paygo = {
      small  = { quota = 100, access_tier = "TransactionOptimized" }
      medium = { quota = 1024, access_tier = "Hot" }
      large  = { quota = 5120, access_tier = "Hot" }
      xlarge = { quota = 10240, access_tier = "Hot" }
    }
    provisioned_v2 = {
      small  = { quota = 1024, access_tier = "Premium" }
      medium = { quota = 5120, access_tier = "Premium" }
      large  = { quota = 10240, access_tier = "Premium" }
      xlarge = { quota = 51200, access_tier = "Premium" }
    }
  }

  access_tier_lookup = {
    HOT                  = "Hot"
    COOL                 = "Cool"
    COLD                 = "Cold"
    PREMIUM              = "Premium"
    TRANSACTION = "TransactionOptimized"
  }

  storage_account_keys = keys(var.storage_accounts)

  account_name_roots = {
    for key in local.storage_account_keys :
    key => lower("st${var.application_short_name}${key}")
  }

  account_name_sanitized = {
    for key, root in local.account_name_roots :
    key => regexreplace(root, "[^0-9a-z]", "")
  }

  account_name_with_fallback = {
    for key, sanitized in local.account_name_sanitized :
    key => (sanitized != "" ? sanitized : substr(
      "st${regexreplace(lower(var.application_short_name), "[^0-9a-z]", "")}${md5(key)}",
      0,
      24
    ))
  }

  account_name_trimmed = {
    for key, value in local.account_name_with_fallback :
    key => substr(value, 0, 24)
  }

  resolved_account_names = {
    for key, value in local.account_name_trimmed :
    key => length(value) >= 3 ? value : substr("${value}000", 0, 3)
  }

  blob_container_roots = {
    for key, container in var.blob_containers :
    key => lower(coalesce(container.name_override, "${var.application_short_name}-${key}"))
  }

  blob_container_sanitized = {
    for key, root in local.blob_container_roots :
    key => regexreplace(
      regexreplace(
        regexreplace(root, "[^0-9a-z-]", "-"),
        "-+",
        "-"
      ),
      "^-|-$",
      ""
    )
  }

  resolved_blob_container_names = {
    for key, value in local.blob_container_sanitized :
    key => length(value) >= 3 ? substr(value, 0, 63) : substr("${value}000", 0, 3)
  }

  file_share_roots = {
    for key, share in var.file_shares :
    key => lower(coalesce(share.name_override, "${var.application_short_name}-${key}"))
  }

  file_share_sanitized = {
    for key, root in local.file_share_roots :
    key => regexreplace(
      regexreplace(
        regexreplace(root, "[^0-9a-z-]", "-"),
        "-+",
        "-"
      ),
      "^-|-$",
      ""
    )
  }

  resolved_file_share_names = {
    for key, value in local.file_share_sanitized :
    key => length(value) >= 3 ? substr(value, 0, 63) : substr("${value}000", 0, 3)
  }

  rendered_blob_containers = {
    for key, container in var.blob_containers :
    key => {
      accounts = container.storage_account_map_keys
      config = merge(
        {
          name          = local.resolved_blob_container_names[key]
          public_access = "None"
        },
        length(coalesce(container.metadata, {})) > 0 ? { metadata = container.metadata } : {},
        container.change_feed_enabled == null ? {} : { change_feed_enabled = container.change_feed_enabled },
        container.default_encryption_scope == null ? {} : { default_encryption_scope = container.default_encryption_scope },
        container.prevent_encryption_scope_override == null ? {} : { prevent_encryption_scope_override = container.prevent_encryption_scope_override },
        container.versioning_enabled == null ? {} : { versioning_enabled = container.versioning_enabled },
        container.immutability_policy == null ? {} : { immutability_policy = container.immutability_policy },
        length(coalesce(container.role_assignments, {})) > 0 ? { role_assignments = container.role_assignments } : {}
      )
    }
  }

  rendered_file_shares = {
    for key, share in var.file_shares :
    key => {
      accounts             = share.storage_account_map_keys
      size_key             = lower(coalesce(share.size, local.default_share_size_key))
      quota_override       = share.quota_gb
      access_tier_override = share.access_tier == null ? null : local.access_tier_lookup[upper(share.access_tier)]
      config = merge(
        {
          name             = local.resolved_file_share_names[key]
          enabled_protocol = upper(coalesce(share.protocol, "SMB"))
        },
        length(coalesce(share.metadata, {})) > 0 ? { metadata = share.metadata } : {},
        length(coalesce(share.role_assignments, {})) > 0 ? { role_assignments = share.role_assignments } : {}
      )
    }
  }

  storage_accounts_base = {
    for key, cfg in var.storage_accounts :
    key => {
      account_name = local.resolved_account_names[key]
      account_kind = local.account_type_matrix[lower(cfg.account_type)].account_kind
      account_tier = local.account_type_matrix[lower(cfg.account_type)].account_tier
      account_replication_type = coalesce(
        cfg.account_replication_type == null ? null : upper(cfg.account_replication_type),
        local.account_type_matrix[lower(cfg.account_type)].account_replication_type
      )
      access_tier = local.account_type_matrix[lower(cfg.account_type)].account_kind == "FileStorage" ? null : coalesce(
        cfg.access_tier == null ? null : local.access_tier_lookup[upper(cfg.access_tier)],
        local.account_type_matrix[lower(cfg.account_type)].access_tier
      )
      is_hns_enabled           = false
      large_file_share_enabled = coalesce(cfg.large_file_share_enabled, local.account_type_matrix[lower(cfg.account_type)].default_large_share)
      active_share_billing_model = local.account_type_matrix[lower(cfg.account_type)].allow_file_shares ? coalesce(
        cfg.file_share_billing_model == null ? null : lower(cfg.file_share_billing_model),
        local.account_type_matrix[lower(cfg.account_type)].share_billing_model
      ) : null
      containers_supported          = local.account_type_matrix[lower(cfg.account_type)].account_kind == "StorageV2"
      allow_file_shares             = local.account_type_matrix[lower(cfg.account_type)].allow_file_shares
      enable_telemetry              = cfg.enable_telemetry
      https_traffic_only_enabled    = true
      min_tls_version               = "TLS1_2"
      public_network_access_enabled = cfg.public_network_access_enabled
      managed_identities            = cfg.managed_identities
      network_rules                 = var.network_rules
      role_assignments              = cfg.role_assignments
      azure_files_authentication = (
        local.account_type_matrix[lower(cfg.account_type)].allow_file_shares && coalesce(cfg.domain_join_enabled, false)
        ? var.azure_files_authentication
        : null
      )
      tags = merge(var.tags, coalesce(cfg.tags, {}))
    }
  }

  blob_containers_by_account = {
    for key, account in local.storage_accounts_base :
    key => (
      account.containers_supported ? {
        for container_key, container in local.rendered_blob_containers :
        container_key => container.config
        if contains(container.accounts, key)
      } : {}
    )
  }

  file_shares_by_account = {
    for key, account in local.storage_accounts_base :
    key => (
      account.active_share_billing_model == null ? {} : {
        for share_key, share in local.rendered_file_shares :
        share_key => merge(
          share.config,
          {
            quota = coalesce(
              share.quota_override,
              lookup(local.share_size_matrix, account.active_share_billing_model, {})[share.size_key].quota
            )
            access_tier = coalesce(
              share.access_tier_override,
              lookup(local.share_size_matrix, account.active_share_billing_model, {})[share.size_key].access_tier
            )
          }
        )
        if contains(share.accounts, key)
      }
    )
  }

  nfsv3_enabled_by_account = {
    for key, shares in local.file_shares_by_account :
    key => length([
      for share in values(shares) : share
      if share.enabled_protocol == "NFS"
    ]) > 0
  }

  storage_accounts = {
    for key, account in local.storage_accounts_base :
    key => {
      name                              = account.account_name
      account_kind                      = account.account_kind
      account_tier                      = account.account_tier
      account_replication_type          = account.account_replication_type
      access_tier                       = account.access_tier
      is_hns_enabled                    = account.is_hns_enabled
      large_file_share_enabled          = account.large_file_share_enabled
      nfsv3_enabled                     = lookup(local.nfsv3_enabled_by_account, key, false)
      provisioned_billing_model_version = account.active_share_billing_model == "provisioned_v2" ? "V2" : null
      containers                        = lookup(local.blob_containers_by_account, key, {})
      shares                            = lookup(local.file_shares_by_account, key, {})
      azure_files_authentication        = account.azure_files_authentication
      https_traffic_only_enabled        = account.https_traffic_only_enabled
      min_tls_version                   = account.min_tls_version
      network_rules                     = account.network_rules
      public_network_access_enabled     = account.public_network_access_enabled
      role_assignments                  = account.role_assignments
      tags                              = account.tags
    }
  }
}

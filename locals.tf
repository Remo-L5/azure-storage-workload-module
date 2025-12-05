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
      is_hns_enabled           = true
    }
    file_gpv2 = {
      account_kind             = "StorageV2"
      account_tier             = "Standard"
      account_replication_type = "ZRS"
      access_tier              = "Hot"
      allow_file_shares        = true
      default_large_share      = true
      share_billing_model      = "paygo"
      is_hns_enabled           = false
    }
    file_share_tx = {
      account_kind             = "FileStorage"
      account_tier             = "Premium"
      account_replication_type = "ZRS"
      access_tier              = null
      allow_file_shares        = true
      default_large_share      = true
      share_billing_model      = "provisioned_v2"
      is_hns_enabled           = false
    }
  }

  selected_account_type = local.account_type_matrix[var.account_type]

  normalized_replication_type = var.account_replication_type == null ? null : upper(var.account_replication_type)

  resolved_account_replication_type = coalesce(local.normalized_replication_type, local.selected_account_type.account_replication_type)

  normalized_access_tier = var.access_tier == null ? null : title(lower(var.access_tier))

  resolved_access_tier = local.selected_account_type.account_kind == "FileStorage" ? null : coalesce(local.normalized_access_tier, local.selected_account_type.access_tier)

  resolved_large_file_share_enabled = coalesce(var.large_file_share_enabled, local.selected_account_type.default_large_share)

  normalized_share_billing_model = var.file_share_billing_model == null ? null : lower(var.file_share_billing_model)

  active_share_billing_model = local.selected_account_type.allow_file_shares ? coalesce(local.normalized_share_billing_model, local.selected_account_type.share_billing_model) : null

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

  share_size_defaults = try(local.share_size_matrix[local.active_share_billing_model], {})

  raw_share_name_seeds = {
    for key, share in var.file_shares :
    key => lower(coalesce(share.name_override, "${var.name}-${key}"))
  }

  sanitized_share_name_seeds = {
    for key, seed in local.raw_share_name_seeds :
    key => regexreplace(
      regexreplace(
        regexreplace(seed, "[^0-9a-z-]", "-"),
        "-+",
        "-"
      ),
      "^-|-$",
      ""
    )
  }

  resolved_share_names = {
    for key, sanitized in local.sanitized_share_name_seeds :
    key => substr(
      length(sanitized) > 0 ? sanitized : lower(var.name),
      0,
      63
    )
  }

  raw_container_name_seeds = {
    for key, container in var.blob_containers :
    key => lower(coalesce(container.name_override, "${var.name}-${key}"))
  }

  sanitized_container_name_seeds = {
    for key, seed in local.raw_container_name_seeds :
    key => regexreplace(
      regexreplace(
        regexreplace(seed, "[^0-9a-z-]", "-"),
        "-+",
        "-"
      ),
      "^-|-$",
      ""
    )
  }

  resolved_container_names = {
    for key, sanitized in local.sanitized_container_name_seeds :
    key => substr(
      length(sanitized) > 0 ? sanitized : lower(var.name),
      0,
      63
    )
  }

  rendered_file_shares = {
    for key, share in var.file_shares :
    key => merge(
      {
        name             = local.resolved_share_names[key]
        enabled_protocol = upper(coalesce(share.protocol, "SMB"))
        quota = coalesce(
          share.quota_gb,
          lookup(
            lookup(local.share_size_defaults, lower(coalesce(share.size, var.default_share_size)), {}),
            "quota",
            null
          )
        )
        access_tier = coalesce(
          share.access_tier,
          lookup(
            lookup(local.share_size_defaults, lower(coalesce(share.size, var.default_share_size)), {}),
            "access_tier",
            null
          )
        )
      },
      length(coalesce(share.metadata, {})) > 0 ? { metadata = share.metadata } : {},
      share.root_squash == null ? {} : { root_squash = share.root_squash },
      length(coalesce(share.signed_identifiers, [])) > 0 ? { signed_identifiers = share.signed_identifiers } : {},
      length(coalesce(share.role_assignments, {})) > 0 ? { role_assignments = share.role_assignments } : {}
    )
  }

  rendered_blob_containers = {
    for key, container in var.blob_containers :
    key => merge(
      {
        name          = local.resolved_container_names[key]
        public_access = coalesce(container.public_access, "None")
      },
      length(coalesce(container.metadata, {})) > 0 ? { metadata = container.metadata } : {},
      container.change_feed_enabled == null ? {} : { change_feed_enabled = container.change_feed_enabled },
      container.default_encryption_scope == null ? {} : { default_encryption_scope = container.default_encryption_scope },
      container.prevent_encryption_scope_override == null ? {} : { prevent_encryption_scope_override = container.prevent_encryption_scope_override },
      container.versioning_enabled == null ? {} : { versioning_enabled = container.versioning_enabled },
      container.legal_hold == null ? {} : { legal_hold = container.legal_hold },
      container.immutability_policy == null ? {} : { immutability_policy = container.immutability_policy },
      length(coalesce(container.role_assignments, {})) > 0 ? { role_assignments = container.role_assignments } : {}
    )
  }

  nfs_requested = length([
    for _, share in local.rendered_file_shares : share
    if share.enabled_protocol == "NFS"
  ]) > 0

  containers_supported = local.selected_account_type.account_kind == "StorageV2"

  final_containers = local.containers_supported ? local.rendered_blob_containers : {}

  final_shares = local.selected_account_type.allow_file_shares ? local.rendered_file_shares : {}
}

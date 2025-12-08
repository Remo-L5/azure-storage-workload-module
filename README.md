# azure-storage-workload-module

Wrapper around `Azure/avm-res-storage-storageaccount/azurerm` that exposes a workload-friendly interface for three curated storage account flavors:

- `blob_gpv2` – StorageV2 account configured for data lake workloads with HNS enabled and blob containers only.
- `file_gpv2` – StorageV2 account that enables Azure Files (SMB) with t-shirt sized shares running on pay-as-you-go billing.
- `file_share_tx` – Premium FileStorage account for high-throughput SMB/NFS workloads using Provisioned V2 billing.

## Highlights

- Opinionated defaults per `account_type` plus enforced HTTPS-only and TLS 1.2 to keep every deployment compliant.
- Define any number of storage accounts via a map, each keyed entry receiving its own AVM deployment with per-account tags and identity/role settings.
- Central blob container and file share definitions can fan-out into one or many accounts with automatic naming, metadata, and t-shirt sizing.
- Global network rules and Azure Files authentication settings flow into every eligible account, while a per-account `domain_join_enabled` flag controls if AD integration is applied.
- Guardrails prevent unsupported combos (e.g., blob containers on FileStorage or NFS shares against `file_gpv2`).

## Usage

```hcl
module "storage_workload" {
  source = "./"

  location               = var.location
  resource_group_name    = azurerm_resource_group.workload.name
  application_short_name = "pay"

  network_rules = {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [azurerm_subnet.private.id]
  }

  azure_files_authentication = {
    active_directory = {
      domain_guid = "00000000-0000-0000-0000-000000000000"
      domain_name = "contoso.corp"
    }
  }

  storage_accounts = {
    blob = {
      account_type = "blob_gpv2"
      tags         = { data_classification = "hot" }
    }
    files = {
      account_type             = "file_share_tx"
      domain_join_enabled      = true
      file_share_billing_model = "provisioned_v2"
    }
  }

  blob_containers = {
    raw = {
      storage_account_map_keys = ["blob"]
    }
    curated = {
      storage_account_map_keys = ["blob"]
      default_encryption_scope = true
    }
  }

  file_shares = {
    erp_smb = {
      storage_account_map_keys = ["files"]
      size                     = "xlarge"
      protocol                 = "SMB"
    }
    erp_nfs = {
      storage_account_map_keys = ["files"]
      size                     = "large"
      protocol                 = "NFS"
    }
  }

  tags = {
    environment = "dev"
    workload    = "storage"
  }
}
```

## Inputs

Run `terraform-docs` to produce the full input/output reference once the module stabilizes.

```bash
terraform-docs markdown table .
```
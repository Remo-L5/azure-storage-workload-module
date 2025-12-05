# azure-storage-workload-module

Wrapper around `Azure/avm-res-storage-storageaccount/azurerm` that exposes a workload-friendly interface for three curated storage account flavors:

- `blob_gpv2` – StorageV2 account configured for data lake workloads with HNS enabled and blob containers only.
- `file_gpv2` – StorageV2 account that enables Azure Files (SMB) with t-shirt sized shares running on pay-as-you-go billing.
- `file_share_tx` – Premium FileStorage account for high-throughput SMB/NFS workloads using Provisioned V2 billing.

## Highlights

- Opinionated defaults per `account_type` (account kind, tier, replication type, hierarchical namespace, HTTPS/TLS, telemetry) aligned with AVM best practices.
- T-shirt sizing for file shares with enforcement of SMB vs NFS protocol rules.
- Azure Files authentication, customer-managed keys, managed identities, network rules, routing, and role assignments flow straight through to the underlying AVM module.
- Guardrails prevent unsupported combos (e.g., blob containers on FileStorage or SMB/NFS shares in `blob_gpv2`).

## Usage

```hcl
module "storage_workload" {
	source = "./"

	name                = "${var.prefix}${random_string.suffix.result}"
	location            = var.location
	resource_group_name = azurerm_resource_group.workload.name
	account_type        = "file_gpv2"

	network_rules = {
		default_action             = "Deny"
		bypass                     = ["AzureServices"]
		virtual_network_subnet_ids = [azurerm_subnet.private.id]
	}

	file_shares = {
		profiles = {
			size     = "medium"
			protocol = "SMB"
		}
		nfs_data = {
			size     = "xlarge"
			protocol = "NFS"
		}
	}

	blob_containers = {
		ingest = {}
		archive = {
			public_access = "None"
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
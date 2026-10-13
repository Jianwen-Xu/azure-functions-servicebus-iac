# Azure Functions + Service Bus + Storage — Terraform

Infrastructure-as-code for an event-driven ingestion pipeline on Azure. One
`terraform apply` creates the messaging namespace, the storage account, the
Function App, the observability stack and every RBAC binding between them — with
no connection strings or account keys handed to application code.

The workload is deliberately small and realistic: messages land on a Service Bus
queue, a Function App consumes them with a managed identity, and each message is
archived to Blob Storage partitioned by date.

```
Service Bus queue  ──►  Function App (Python, managed identity)  ──►  Blob container
   "ingest"                 archive_message()                          "archive/YYYY/MM/DD"
       │                              │
       │                              └──►  Application Insights  ◄── Log Analytics
       └── dead-letter after N deliveries
```

## What this demonstrates

| Concern | How it is handled |
| --- | --- |
| Remote state | Partial backend config; no storage keys in the repo, `use_azuread_auth = true` |
| Secrets | None. Managed identity + RBAC for Service Bus and Blob; SAS auth disabled on the namespace |
| Least privilege | `Data Receiver` / `Data Sender` / `Blob Data Contributor`, scoped to the resource, not the subscription |
| Environment parity | Same modules for `dev` and `prod`; differences live in `envs/*.tfvars` |
| Naming | Derived once in `locals.tf`; globally unique suffixes are stable across re-applies |
| Observability | Workspace-based Application Insights, Service Bus diagnostic settings, ingestion caps |
| Cost control | Consumption/Premium switch, storage lifecycle tiering, a consumption budget with an alert |
| CI/CD | `fmt` + `validate` + `tflint` on every PR, plan commented back, apply behind a manual gate and OIDC |

## Layout

```
.
├── bootstrap/              One-time remote state backend (local state, run once)
├── envs/                   Per-environment .tfvars and backend config examples
├── modules/
│   ├── storage/            StorageV2 account, containers, lifecycle policy, firewall
│   ├── servicebus/         Namespace, queues, topics, subscriptions, optional SAS rule
│   ├── function_app/       Linux plan + Function App with a system-assigned identity
│   └── monitoring/         Log Analytics workspace + workspace-based App Insights
├── src/function/           The Python Function App (v2 programming model)
├── docs/architecture.md    Deeper notes and the decisions behind them
├── main.tf                 Composition: resource group, modules, RBAC, diagnostics
├── locals.tf               Naming and tag derivation
├── versions.tf             Provider and Terraform version constraints
└── .github/workflows/      CI (validate + plan) and CD (manual apply via OIDC)
```

## Usage

### Prerequisites

- Terraform >= 1.6 (the code uses `optional()` object attributes)
- Azure CLI, authenticated: `az login`
- A subscription where you can create resource groups and role assignments

### 1. Bootstrap remote state (once per subscription)

```bash
cd bootstrap
terraform init
terraform apply -var="state_storage_account_name=sttfstate<your-suffix>"
terraform output -raw backend_config
```

Paste that output into `envs/dev.backend.hcl` (copy it from
`envs/dev.backend.hcl.example`). The bootstrap module keeps **local** state on
purpose — it creates the very storage account everything else stores its state
in, so it cannot depend on remote state itself. It also applies a
`CanNotDelete` lock, because losing this account loses every environment's state.

### 2. Deploy

```bash
terraform init -backend-config=envs/dev.backend.hcl
terraform plan  -var-file=envs/dev.tfvars
terraform apply -var-file=envs/dev.tfvars
```

Or via the Makefile:

```bash
make init ENV=dev
make plan ENV=dev
make apply ENV=dev
```

### 3. Deploy the function code

`terraform apply` provisions the host but does not push the application package:

```bash
cd src/function
func azure functionapp publish "$(terraform -chdir=../.. output -raw function_app_name)"
```

Or merge to `main` and let `.github/workflows/deploy.yml` do it behind the
`prod` environment's required-reviewer gate.

### 4. Send a test message

With `servicebus_local_auth_enabled = false` (the default) there is no
connection string, so send with your own `az login` identity:

```bash
az servicebus queue message send \
  --namespace-name "$(terraform output -raw servicebus_namespace | cut -d. -f1)" \
  --resource-group "$(terraform output -raw resource_group_name)" \
  --queue-name ingest \
  --body '{"hello":"world"}'
```

Check `archive/YYYY/MM/DD/*.json` in the storage account. Your account needs
`Azure Service Bus Data Sender` on the namespace to do this.

## CI/CD

`.github/workflows/terraform.yml` runs on every pull request: `terraform fmt
-check`, `terraform validate` (root and `bootstrap/`), and `tflint` with the
azurerm ruleset. If the repository is wired to Azure it then produces a real plan
and posts it as a comment on the PR. The plan job skips itself when
`vars.AZURE_CLIENT_ID` is unset, so forks and fresh clones are not shown a red
build they cannot fix.

`.github/workflows/deploy.yml` is `workflow_dispatch` only, with an `apply`
checkbox that defaults to *off* and a `concurrency` group of one per environment.
Authentication is GitHub OIDC throughout — no client secret and no publish
profile is stored.

To enable the Azure-facing jobs, configure these on the repository (variables,
not secrets — none of them is sensitive, and the credentials come from OIDC):

| Variable | Purpose |
| --- | --- |
| `AZURE_CLIENT_ID` | App registration (or user-assigned identity) with a federated credential for this repo |
| `AZURE_TENANT_ID` | Entra ID tenant |
| `AZURE_SUBSCRIPTION_ID` | Target subscription |
| `TF_STATE_RESOURCE_GROUP` | Resource group from `bootstrap/` |
| `TF_STATE_STORAGE_ACCOUNT` | State storage account from `bootstrap/` |
| `TF_STATE_CONTAINER` | State container, normally `tfstate` |

The backend config is rendered from those values at run time rather than
committed, because `envs/*.backend.hcl` is gitignored — it names a real storage
account and is environment-specific.

## Design decisions worth calling out

**Managed identity instead of connection strings.** The Service Bus extension
authenticates with AAD when it finds `ServiceBusConnection__fullyQualifiedNamespace`
rather than a `...Connection` string, and `local_auth_enabled = false` removes SAS
keys from the namespace entirely. The cost is that RBAC propagation is eventually
consistent — a Function App created seconds before its role assignment can fail
its first connection. Re-running the trigger, or waiting a couple of minutes,
resolves it.

**The host storage key is still used.** `storage_account_access_key` feeds the
Functions *runtime* (its own queues and deployment package), which is the one
place a key remains. Moving the host to a private endpoint plus
`storage_uses_managed_identity = true` is the next hardening step; it is not
the default here because it adds a VNet to what is otherwise a single-command
deploy.

**Modules take full resource names, not name fragments.** `servicebus` does not
know how to build a namespace name — the root passes one in. It keeps Azure's
per-resource-type naming rules in exactly one file (`locals.tf`) instead of
spread across four modules, which is what usually rots first in a Terraform repo.

**`prod` uses ES Premium and ZRS.** Y1 Consumption is cheap but cold-starts;
`EP1` keeps a warm worker. This is a cost decision surfaced as a variable
(`function_plan_sku`) rather than a fork of the module.

## Cost

Roughly, per month, on a quiet dev environment: Storage ~€0.10, Service Bus
Standard ~€9 (base charge, no per-message cost), Consumption plan ~€0 when idle,
Log Analytics a few cents under the 1 GB/day cap. The
`azurerm_consumption_budget_resource_group` alert fires at 80% of
`budget_amount`. Run `terraform destroy -var-file=envs/dev.tfvars` when you are
done.

## Deliberately out of scope

Key Vault, private endpoints and VNet integration, CI/CD for the *function code*
itself on push (only the deploy workflow skeleton exists), and multi-region
failover. Each is a real next step, and adding them here would make the
repository harder to read rather than more complete. `docs/architecture.md`
records the reasoning and the migration path.

## License

MIT — see [LICENSE](LICENSE).

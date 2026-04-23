---
name: Terraform Primitive Module Creator
description: Agent that creates a Terraform Primitive Module from a skeleton repository to meet our standards.
---

<!-- version: 1.8 -->

# AI Agent Guide for Terraform Primitive Modules

This document provides context and instructions for AI coding assistants working with the launchbynttdata Terraform module library.

## Changelog

- **1.8** – Added guidance from iterative module creation: Terraform reserved variable names (avoid `source`, `target`), resource naming module API (instance_env/instance_resource are numbers; cloud_resource_type must be alphanumeric), validation block null handling (use ternary), provider schema verification for outputs, example outputs must match test expectations, Regula/Conftest pre-check, go mod tidy for new SDK deps, common Regula rules (e.g., SQS+KMS). Added requirement to run full example validation flow (tflint, init, validate, plan, apply, destroy) before implementing tests. Added Terratest / Go code quality review (golangci-lint, go get -u ./..., go mod tidy, go build) before running tests. Added account-scoped unique resource guidance (KMS aliases must use random suffix to avoid parallel/sequential collision).
- **1.7** – Strengthened frequently-violated requirements based on multi-model trial feedback: added Critical Requirements Checklist, added WRONG/RIGHT examples for test assertions and functional vs readonly tests, added explicit example README accuracy requirements with examples, strengthened security verification requirements, added Pre-Submission Validation Checklist, expanded Makefile skeleton cleanup, clarified output `id` description for resources where id equals another attribute.
- **1.6** – Strengthened guidance based on trial feedback: added explicit skeleton TODO/placeholder cleanup, readonly test differentiation, terraform-docs generation step, output description requirement, input validation requirements for bounded numerics, mutually exclusive parameter handling, security-first example defaults (KMS/Regula), output naming convention, and example completeness expectations.
- **1.5** – Added notes about security-first defaults and checking files for references to skeleton and templates during cleanup.
- **1.4** – Fixed version header (block must come first to be recognized as an agent)
- **1.3** – Added agent header, migrated to agents folder, added skeleton cleanup checklist.
- **1.2** – Fixed resource naming module usage: `for_each = var.resource_names_map` (not a module input), correct variable name `class_env` (not `environment`), added required `cloud_resource_type`/`maximum_length` params, corrected output reference syntax to `module.resource_names["key"].format`, noted hyphens-stripping for AWS regions
- **1.1** – Added cloud provider API verification patterns (Azure, AWS, GCP) to Terratest guidance; tests must now verify real resource state via provider SDKs, not just Terraform outputs
- **1.0** – Initial release

> **For agents working in the skeleton repo (`poc-skeleton`):** If you modify this file, update the `<!-- version -->` comment at the top and add a changelog entry here. Bump the minor version (e.g. 1.1 → 1.2) for new guidance or clarifications; bump the major version (e.g. 1.x → 2.0) for changes that would require significant rework of existing modules.

> **Maintenance rule — keep guidance generic.** This guide applies to ALL primitive modules across all cloud providers, not just the resource type used in any particular experiment. When updating this file, do not embed service-specific attribute names (e.g., `VisibilityTimeout`, `KmsMasterKeyId`, `BucketName`) into patterns meant to be universal. If a concrete example helps clarify a pattern, show one per cloud provider and label each clearly (e.g., "Azure example," "AWS example," "GCP example"). Prefer generic placeholders like `<resource-specific attribute>` in WRONG/RIGHT comparisons and checklists.

## Overview

This organization maintains 250+ Terraform modules following a strict **composition model**:
- **Primitive modules** (~90%): Wrap a single cloud resource type
  - Repository naming: `tf-<provider>-module_primitive-<resource>`
  - Example: `tf-azurerm-module_primitive-postgresql_server`, `tf-aws-module_primitive-s3_bucket`
- **Reference architecture modules** (~10%): Compose multiple primitives
  - Repository naming: `tf-<provider>-module_reference-<architecture>`
  - Example: `tf-azurerm-module_reference-postgresql_server`, `tf-aws-module_reference-lambda_function`

You are most likely helping create or modify a **primitive module**.

## Critical Requirements Checklist

> **These are the most frequently violated requirements.** Every item below has been missed by AI agents in testing. Treat each as a hard requirement — failure on any of these is considered a High-severity defect.

1. **Tests MUST assert specific expected values, not just non-emptiness.** Do NOT write `assert.NotEmpty(t, someAttribute)`. Instead write `assert.Equal(t, expectedValue, result.Attributes["<attribute>"])` with the actual expected value for your resource. See [Testing Standards: Specific Value Assertions](#specific-value-assertions) for WRONG/RIGHT examples.

2. **Functional and readonly tests MUST be meaningfully different.** The functional test must include write operations that exercise the resource (e.g., writing data, invoking a function). The readonly test must only read/verify. They must call different test implementation functions. NEVER copy `post_deploy_functional/main_test.go` into `post_deploy_functional_readonly/` unchanged. See [Functional vs Readonly Tests](#functional-vs-readonly-tests).

3. **Security settings MUST be verified via the cloud API in tests.** If the module configures encryption, the test must assert that encryption is enabled via the provider SDK — not just check that a Terraform output is non-empty. Use `require` (not a conditional `if ok`) to ensure the security attribute is present. See [Security Verification in Tests](#security-verification-in-tests).

4. **README.md TODO placeholders MUST be removed.** Search for `TODO:` in ALL files. The skeleton's `TODO: INSERT DOC LINK ABOUT HOOKS` is the most common missed placeholder. Either replace with real content or remove the TODO text entirely.

5. **The terraform-docs section in README.md MUST NOT be empty.** Run `terraform-docs markdown table --output-file README.md --output-mode inject .` or manually populate the section. An empty `<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->` / `<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->` block is a defect.

6. **The example README.md usage snippet MUST exactly match `examples/complete/main.tf`.** Do not write a simplified snippet. Do not omit variables. Do not add variables that aren't in the actual code. The Inputs table must list ALL variables from `examples/complete/variables.tf`. The Outputs table must list ALL outputs from `examples/complete/outputs.tf`. See [Example README Accuracy](#example-readme-accuracy).

7. **The example MUST pass through ALL root module variables.** Every variable in the root `variables.tf` must appear in `examples/complete/variables.tf` and be passed to the module call in `examples/complete/main.tf`. Mutually exclusive variables (e.g., `name` vs `name_prefix`) should both be defined with appropriate defaults (`null` for the one not used).

8. **The example MUST use the most secure configuration.** If the organization's Regula/OPA policies would flag a security concern (e.g., encryption should use customer-managed keys rather than provider-managed defaults), the example must demonstrate the secure pattern (e.g., create a KMS/CMEK key module and pass it). The example is the reference implementation. Run `make check` (or Regula/Conftest) before considering the module complete — common rules include: AWS SQS queues require KMS encryption (FG_R00070); S3 buckets require encryption; etc.

9. **Skeleton remnants MUST be completely removed.** This includes: Makefile `init-clean` target with `TEMPLATED_README.md` references, skeleton comments in `tests/testimpl/types.go`, TODO placeholders in README.md, and all references to `poc-template` outside of `.github/agents/`. See [Skeleton Cleanup Checklist](#skeleton-cleanup-checklist).

10. **Output `id` description must be accurate.** For resources where `id` equals another attribute (e.g., a queue's `id` is the same as its `url`, or a storage account's `id` is the full ARM resource path), use a clarifying description like `"The ID of the resource (same as the <other attribute>)."` — do not use the exact same description for both outputs.

## Cloud Providers Supported

- **Azure** (`azurerm` provider) - Primary platform
- **AWS** (`aws` provider) - Large number of modules
- **Google Cloud** (`google` provider) - Growing library

**This guide applies to all cloud providers.** Provider-specific differences are noted where relevant.

## Module Architecture Principles

### Primitive Module Pattern
```
Single Resource → Single Module → Maximum Reusability
```

**Rules:**
- ONE resource type per primitive module
- Resource block named based on resource type (e.g., `postgres`, `redis`, `lambda`, not `this`)
- Export ALL useful resource attributes as outputs
- Comprehensive input validation where appropriate
- Working example with automated Terratest
- No business logic - pure resource wrapper

**Example:**
A primitive module for `azurerm_storage_account` contains ONLY that resource. A primitive for `aws_s3_bucket` contains ONLY that resource. A reference architecture module for "secure data lake" would compose multiple primitives (storage + networking + encryption + monitoring, etc.).

### Why This Matters for AI Assistance
- Look for similar primitive modules as templates
- Don't add multiple resources to a primitive module
- Don't assume business logic belongs in primitives
- Keep it simple, complete, and composable

## Required File Structure

Every primitive module must have this structure:
```
tf-<provider>-module_primitive-<resource>/
├── .github/workflows/      # CI/CD (optional but recommended)
├── examples/
│   └── complete/           # REQUIRED: Full working example
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── provider.tf    # Provider configuration, delivered by the Makefile. Don't touch this file.
│       └── README.md
│       └── versions.tf
├── tests/                  # Note: "tests" not "test"
│   ├── complete_test.go    # REQUIRED: Terratest
│   └── fixtures/           # Test data if needed
├── main.tf                 # REQUIRED: Resource definition
├── variables.tf            # REQUIRED: Input variables
├── outputs.tf              # REQUIRED: Output values
├── versions.tf             # REQUIRED: Version constraints
├── README.md               # REQUIRED: Documentation
├── Makefile                # REQUIRED: Standard targets
├── go.mod                  # Go dependencies for Terratest
├── go.sum                  # Go dependency checksums
├── LICENSE                 # Apache 2.0
├── NOTICE                  # Copyright notice
├── CODEOWNERS              # GitHub code owners
├── .gitignore              # Standard ignores
├── .tool-versions          # asdf tool versions
├── .lcafenv                # Launch CAF environment config
└── .secrets.baseline       # Detect-secrets baseline
```

## Naming Conventions

### Repository Naming
```
tf-<provider>-module_primitive-<resource>
```
Examples:
- `tf-azurerm-module_primitive-postgresql_server`
- `tf-azurerm-module_primitive-redis_cache`
- `tf-aws-module_primitive-s3_bucket`
- `tf-aws-module_primitive-lambda_function`
- `tf-google-module_primitive-storage_bucket`

**Note:** Use underscores in "module_primitive", use hyphens between words

### Resource Naming
```hcl
# Azure example
resource "azurerm_postgresql_flexible_server" "postgres" {
  # Resource name matches the resource type
}

# AWS example
resource "aws_s3_bucket" "bucket" {
  # Resource name matches the resource type
}

# GCP example
resource "google_storage_bucket" "bucket" {
  # Resource name matches the resource type
}
```

**Pattern:** Use short, descriptive name that matches the resource type
- `azurerm_postgresql_flexible_server` → `postgres`
- `azurerm_redis_cache` → `redis`
- `aws_s3_bucket` → `bucket`
- `aws_lambda_function` → `lambda` or `function`
- `google_storage_bucket` → `bucket`

**Do NOT use "this"** - use descriptive names instead

### Variable Naming
- Use `snake_case`
- Be descriptive but concise
- Match provider argument names where possible
- Group related variables with comment headers
- **Avoid Terraform reserved names:** Do NOT use `source`, `target`, `version`, `count`, `for`, or `provider` as variable names — they have special meaning in Terraform. Use alternatives (e.g., `source_arn`, `target_arn`, `source_uri`).

## Code Standards

### variables.tf

**Required elements:**
- Explicit type declarations
- Comprehensive descriptions
- Validation blocks for constrained inputs (where beneficial)
- Sensible defaults for optional inputs OR no default if required

**Template pattern:**
```hcl
variable "name" {
  description = "Name of the [resource]. Must be unique within [scope]."
  type        = string
  # No default - this is required
}

variable "resource_group_name" {  # Azure
# OR
variable "tags" {                  # AWS/GCP
  description = "[Description of what this configures]"
  type        = string # or appropriate type
  # Provider-specific required fields typically have no default
}

variable "location" {  # Azure
# OR
variable "region" {    # AWS/GCP - often computed from data source
  description = "Azure region / AWS region / GCP location where resource will be created"
  type        = string
  # May or may not have default depending on pattern
}

variable "sku_name" {              # Example optional with default
  description = "The SKU/tier for this resource"
  type        = string
  default     = "Standard"         # Sensible default for optional

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku_name)
    error_message = "SKU must be Basic, Standard, or Premium."
  }
}

variable "enable_feature" {
  description = "Whether to enable [specific feature]"
  type        = bool
  default     = false              # Security-first default
}

variable "complex_config" {
  description = <<-EOT
    field1 = Description of field1
    field2 = Description of field2
  EOT
  type = object({
    field1 = string
    field2 = optional(string)
  })
  default = null                   # Optional complex objects default to null
}

variable "tags" {
  description = "Map of tags to assign to the resource"
  type        = map(string)
  default     = {}                 # Always include tags, default to empty
}
```

**Key patterns:**
- Required infrastructure inputs: no defaults (name, resource_group_name/region, location)
- Optional feature flags: default to `false` or most secure option
- Tags: always include, default to empty map `{}`
- Complex objects: use `object()` with `optional()` fields
- Multi-line descriptions: use heredoc `<<-EOT ... EOT`
- **Validation blocks are REQUIRED** for all bounded numerical inputs (e.g., timeouts, sizes, retention periods). Always add `validation {}` blocks when the cloud provider API enforces value ranges. Example:
  ```hcl
  # Azure example
  variable "backup_retention_days" {
    description = "Number of days to retain backups."
    type        = number
    default     = 7

    validation {
      condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 35
      error_message = "Must be between 7 and 35 days."
    }
  }

  # AWS example
  variable "retention_in_days" {
    description = "Number of days to retain log events."
    type        = number
    default     = 30

    validation {
      condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.retention_in_days)
      error_message = "Must be a valid CloudWatch Logs retention value."
    }
  }
  ```
- **Mutually exclusive parameters:** When two variables cannot be used simultaneously (e.g., provider-managed encryption vs customer-managed key, or `name` vs `name_prefix`), add a `validation` block or use conditional logic in `main.tf` to prevent conflicts. Example:
  ```hcl
  # In main.tf - use conditional to resolve mutual exclusion:
  provider_managed_encryption = var.customer_managed_key_id == null ? var.provider_managed_encryption : false
  ```
- **Validation blocks with optional (null) variables:** When validating optional variables that may be `null`, use a ternary to avoid evaluating expressions on null. Terraform may evaluate the full condition, so `var.x == null || length(var.x) ...` can fail with "argument must not be null". Use `var.x == null ? true : (length(var.x) ...)` instead.
- **Optional object attribute access:** When validating nested attributes of optional objects (e.g., `var.obj.field`), use `try()` to safely access: `var.obj == null ? true : (try(var.obj.field, null) == null ? true : (...))`.

**Provider-specific common variables:**

**Azure:**
```hcl
variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}
```

**AWS:**
```hcl
# Region is typically obtained from data source, not variable
# Tags are the primary grouping mechanism

variable "tags" {
  description = "Map of tags"
  type        = map(string)
  default     = {}
}
```

**GCP:**
```hcl
variable "project" {
  description = "GCP project ID"
  type        = string
}

variable "location" {  # or region, depending on resource
  description = "GCP location"
  type        = string
}
```

### main.tf

**Template pattern:**
```hcl
# Azure example
resource "azurerm_postgresql_flexible_server" "postgres" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  version     = var.postgres_version
  sku_name    = var.sku_name
  storage_mb  = var.storage_mb

  # Use dynamic blocks for optional nested configuration
  dynamic "authentication" {
    for_each = var.authentication != null ? [var.authentication] : []
    content {
      active_directory_auth_enabled = authentication.value.active_directory_auth_enabled
      password_auth_enabled         = authentication.value.password_auth_enabled
      tenant_id                     = authentication.value.tenant_id
    }
  }

  tags = var.tags
}

# AWS example
resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name

  tags = var.tags
}

# Separate resources for AWS (vs nested blocks in Azure)
resource "aws_s3_bucket_versioning" "bucket" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

**Key patterns:**
- Single resource block with descriptive name
- Direct variable mapping (no transformations)
- Dynamic blocks for optional nested blocks: `for_each = var.x != null ? [var.x] : []`
- No lifecycle blocks unless absolutely necessary
- Tags at the end
- No data sources unless essential
- **AWS-specific:** Often uses separate resources instead of nested blocks

**Feature completeness:** A primitive module must expose ALL commonly-used attributes of the resource as variables. "Commonly-used" means any attribute that a typical production deployment would configure. Consult the Terraform provider documentation for the resource and expose every non-deprecated, non-computed argument. Optional attributes should default to `null` so they are omitted from the API call unless explicitly set. Do NOT create a minimal wrapper — the primitive must be a comprehensive, production-ready resource wrapper.

### outputs.tf

**Your actual pattern:**
```hcl
output "id" {
  description = "The ID of the resource."
  value       = azurerm_postgresql_flexible_server.postgres.id
  # OR
  value       = aws_s3_bucket.bucket.id
}

output "name" {
  description = "The name of the resource."
  value       = azurerm_postgresql_flexible_server.postgres.name
  # OR
  value       = aws_s3_bucket.bucket.bucket
}

output "arn" {  # AWS-specific
  description = "The ARN of the resource."
  value       = aws_s3_bucket.bucket.arn
}

output "fqdn" {  # Common for databases
  description = "The FQDN of the resource."
  value       = azurerm_postgresql_flexible_server.postgres.fqdn
}

# Export important attributes individually
output "primary_endpoint" {
  description = "The primary blob endpoint of the storage account."
  value       = azurerm_storage_account.storage.primary_blob_endpoint
}
```

**Key patterns:**
- Export critical attributes individually
- Simple value references with short `description` fields (required for `terraform-docs` to generate useful documentation)
- No `sensitive = true` flags (handle in calling code)
- Export enough for composition, but not necessarily everything
- No complete resource object output
- **Provider-specific outputs:** ARNs (AWS), FQDNs (Azure), etc.
- **Output naming:** Use short, generic names without resource-type prefixes. Use `id`, `arn`, `name`, `url` — NOT `queue_id`, `queue_arn`, etc. The module context already implies the resource type.
- **Output `id` description:** Some cloud resources return the same value for `id` and another attribute. When this happens, do NOT give the `id` output the same description as the other output. Instead, clarify the overlap: `"The ID of the resource (same as the <other attribute>)."` This prevents confusion when consumers see two outputs with identical descriptions.
- **Verify outputs exist in provider schema:** Before adding an output, confirm the attribute exists on the resource in the Terraform provider. Not all API attributes are exposed (e.g., some resources omit `current_state`). Check the provider documentation or run `terraform state show` on a test resource. Do NOT output attributes that the provider does not expose.

**Example with descriptions:**
```hcl
# AWS example
output "id" {
  description = "The ID of the resource."
  value       = aws_s3_bucket.bucket.id
}

output "arn" {
  description = "The ARN of the resource."
  value       = aws_s3_bucket.bucket.arn
}

# Azure example
output "id" {
  description = "The ID of the resource."
  value       = azurerm_postgresql_flexible_server.postgres.id
}

output "fqdn" {
  description = "The fully qualified domain name of the server."
  value       = azurerm_postgresql_flexible_server.postgres.fqdn
}
```

### versions.tf

**Your actual patterns:**

**Azure:**
```hcl
terraform {
  required_version = "~> 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.113"
    }
  }
}
```

**AWS:**
```hcl
terraform {
  required_version = "~> 1.5"  # Note: Newer than Azure modules

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.14"
    }
  }
}
```

**Pattern:**
- Terraform version: `~> 1.0` (Azure) or `~> 1.5` (AWS) - use latest stable
- Provider version: Pin to specific minor version with `~>`
- No provider configuration block (handled in examples)

**Note:** AWS modules using `~> 1.5` is newer - Azure modules should be updated to match.

## Provider-Specific Patterns

### Azure Patterns

**Resource Groups:**
```hcl
variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}
```

**Networking:**
- VNets, subnets, NSGs are common dependencies
- Private endpoints for secure access
- Delegated subnets for managed services

### AWS Patterns

**Region Data Source:**
```hcl
data "aws_region" "current" {}

# Use data.aws_region.current.name when needed
```

**Separate Resources:**
AWS often uses separate resources for configuration vs Azure's nested blocks:
```hcl
resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name
}

# Separate resource for versioning
resource "aws_s3_bucket_versioning" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Separate resource for encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

**Tags as Primary Grouping:**
AWS doesn't have resource groups like Azure, so tags are critical for organization.

### GCP Patterns

**Project Context:**
```hcl
variable "project" {
  description = "GCP project ID"
  type        = string
}
```

**Labels vs Tags:**
GCP uses `labels` instead of `tags` in most resources.

## Testing Standards

### examples/complete/

**Standard structure (all providers):**
```
examples/complete/
├── main.tf          # Module usage
├── variables.tf     # Example variables
├── outputs.tf       # Pass-through outputs
├── provider.tf     # Provider configuration, delivered by the Makefile. Don't touch this file.
└── README.md        # Example documentation
└── versions.tf
```

**Example main.tf pattern:**
```hcl
# All providers use resource naming module
# resource_names_map is used as for_each - the module is called once per resource type.
# The map key becomes the instance key (e.g. "resource_group", "postgresql_server").
module "resource_names" {
  source   = "terraform.registry.launch.nttdata.com/module_library/resource_name/launch"
  version  = "~> 2.0"

  for_each = var.resource_names_map

  logical_product_family  = var.logical_product_family
  logical_product_service = var.logical_product_service
  class_env               = var.class_env
  instance_env            = var.instance_env
  instance_resource       = var.instance_resource
  cloud_resource_type     = each.value.name
  maximum_length          = each.value.max_length

  # Azure: pass location directly (no hyphens in Azure region names)
  region                = var.location
  use_azure_region_abbr = var.use_azure_region_abbr

  # AWS/GCP: strip hyphens from region (e.g. "us-east-1" -> "useast1")
  # region = join("", split("-", data.aws_region.current.name))
}
```

**Resource naming module API (critical):** The `resource_name` module has specific type requirements. Verify against the module's `variables.tf` before using:

- **`instance_env`** — Type `number` (0–999), NOT string. Use `1` or `0` in test.tfvars, not `"dev"`.
- **`instance_resource`** — Type `number` (0–100), NOT string. Use `1` or `0` in test.tfvars, not `"pipe"`.
- **`cloud_resource_type`** — Must be **alphanumeric only** (letters and numbers). No underscores, hyphens, or special characters. Use `"iamrole1"`, `"sqsqueue1"`, `"pipe1"` — NOT `"iam_role"`, `"sqs_queue"`, or `"pipe"`.

```hcl
# Reference names by map key and desired output format:
#   module.resource_names["resource_group"].standard
#   module.resource_names["postgresql_server"].standard
#   module.resource_names["s3_bucket"].minimal_random_suffix  (AWS - globally unique)

# Azure example - create resource group
module "resource_group" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/resource_group/azurerm"
  version = "~> 1.0"

  name     = module.resource_names["resource_group"].standard
  location = var.location
  tags     = var.tags
}

# Use the primitive module
module "postgres" {  # or "bucket", "lambda", etc.
  source = "../.."

  name                = module.resource_names["postgresql_server"].standard
  resource_group_name = module.resource_group.name  # Azure
  location            = var.location                  # Azure
  # OR for AWS:
  # No resource group, tags for grouping

  # Pass through configuration variables
  sku_name         = var.sku_name
  postgres_version = var.postgres_version

  tags = var.tags
}
```

**Key points:**
- Use resource naming module for consistent naming
- Create required dependencies (resource group for Azure)
- Use `source = "../.."` to reference parent module
- Pass through variables, minimal hardcoding
- **The example must demonstrate ALL module variables** — every variable defined in the root module's `variables.tf` should be passed through in the example. This ensures the example serves as complete documentation and that all features are tested.
- **Security-first example defaults:** The example's `test.tfvars` and `variables.tf` defaults must use the MOST SECURE configuration option. If the organization's Regula/OPA policies flag a security concern (e.g., encryption should use customer-managed keys, not provider-managed defaults), the example must demonstrate the secure pattern (e.g., create a KMS/CMEK key module and pass it). The example is the reference implementation — it must pass all organizational policy checks without warnings.
- **Regula/Conftest:** Run `make check` before finalizing. Common Regula rules: AWS SQS queues require KMS encryption (FG_R00070) — add `aws_kms_key` and `kms_master_key_id` to queues; S3 buckets require encryption; RDS/DynamoDB encryption. If the example creates these resources, configure them with customer-managed KMS keys.
- **Account-scoped unique resources (e.g., AWS KMS aliases):** Resources like `aws_kms_alias` have names that are unique per AWS account. Do NOT hardcode the alias name (e.g., `alias/example-sqs-enc`) — parallel tests or sequential runs will collide ("already exists" on create, "does not exist" on delete). Use a random suffix (e.g., `random_string` + `alias/example-sqs-enc-${random_string.suffix.result}`) or the resource naming module with uniqueness.
- **The example's README.md** must accurately reflect the actual `main.tf` code. The usage snippet and Inputs table must match the real example code exactly. Do not write a simplified snippet that omits variables. See [Example README Accuracy](#example-readme-accuracy) for details.

### Full Example Validation Flow (Before Implementing Tests)

> **Run this flow for every example you create, before writing or running Terratest.** It catches configuration errors, provider schema mismatches, and policy violations early, reducing toil and churn.

After creating `examples/complete/` (including `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `test.tfvars`), run the full validation flow **from the repository root**:

1. **tflint** — Lint the example:
   ```bash
   make lint
   ```

2. **init** — Initialize Terraform in the example directory:
   ```bash
   cd examples/complete && terraform init
   ```

3. **validate** — Validate configuration:
   ```bash
   cd examples/complete && terraform validate
   ```

4. **plan** — Run plan with test.tfvars:
   ```bash
   cd examples/complete && terraform plan -var-file=test.tfvars
   ```

5. **apply** — Deploy the example (requires cloud provider credentials):
   ```bash
   cd examples/complete && terraform apply -var-file=test.tfvars -auto-approve
   ```
   The user must ensure cloud provider credentials are available (e.g., AWS profile, Azure service principal, GCP service account). If the agent cannot interact with the API due to credential issues, prompt the user to fix credentials and retry.

6. **destroy** — Tear down:
   ```bash
   cd examples/complete && terraform destroy -var-file=test.tfvars -auto-approve
   ```

**Fix any failures before implementing tests.** Do not proceed to Terratest until all six steps succeed. This ensures the example is deployable and correct before tests depend on it.

### Example README Accuracy

> **This is frequently violated.** Models often write a simplified usage snippet that omits variables, or list outputs that don't exist in the actual `outputs.tf`. The example README must be a faithful mirror of the actual example code.

**Requirements:**
1. The **usage snippet** in the README must contain the EXACT same module calls and variables as `examples/complete/main.tf`. If `main.tf` passes 12 variables to the module, the README snippet must show all 12.
2. The **Inputs table** must list EVERY variable from `examples/complete/variables.tf` with matching names, types, defaults, and descriptions.
3. The **Outputs table** must list EVERY output from `examples/complete/outputs.tf`. Do NOT list outputs that don't exist in the code. Do NOT omit outputs that do exist.
4. **Example outputs must match test expectations:** Every output consumed by `terraform.Output(t, ..., "name")` in `tests/testimpl/test_impl.go` MUST exist in `examples/complete/outputs.tf`. If a test expects `desired_state`, the example must expose it. Add any missing outputs before tests run.
5. Do NOT manually edit content within `<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->` markers. Let terraform-docs generate it, or write content that exactly matches what terraform-docs would produce.
6. Do NOT write "See variables.tf for inputs" instead of providing an actual Inputs table.

### Terratest (tests/)

Tests must verify **both** Terraform outputs **and** actual resource state via the cloud provider API. Terraform outputs are generated by Terraform itself and do not prove the cloud resource was actually created or configured correctly. Always use provider SDK helpers to confirm real resource state.

**Azure pattern:**
```go
package tests

import (
    "os"
    "testing"

    "github.com/gruntwork-io/terratest/modules/azure"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestResourceComplete(t *testing.T) {
    t.Parallel()

    subscriptionID := os.Getenv("ARM_SUBSCRIPTION_ID")
    require.NotEmpty(t, subscriptionID, "ARM_SUBSCRIPTION_ID must be set")

    terraformOptions := &terraform.Options{
        TerraformDir: "../examples/complete",
    }

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    // Verify Terraform outputs
    id := terraform.Output(t, terraformOptions, "id")
    assert.NotEmpty(t, id)

    name := terraform.Output(t, terraformOptions, "name")
    assert.NotEmpty(t, name)

    resourceGroupName := terraform.Output(t, terraformOptions, "resource_group_name")
    assert.NotEmpty(t, resourceGroupName)

    // Verify via Azure API - confirm the resource actually exists and is configured correctly
    // Use terratest azure helpers where available:
    //   github.com/gruntwork-io/terratest/modules/azure
    // Fall back to the Azure SDK for resources not covered by terratest helpers:
    //   github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/...

    // Example for a storage account:
    storageAccount := azure.GetStorageAccount(t, resourceGroupName, name, subscriptionID)
    require.NotNil(t, storageAccount)
    assert.Equal(t, "Standard_LRS", string(storageAccount.SKU.Name))
    assert.Equal(t, "eastus", *storageAccount.Location)

    // Example using the Azure SDK directly for a resource not in terratest helpers:
    // cred, _ := azidentity.NewDefaultAzureCredential(nil)
    // client, _ := armpostgresqlflexibleservers.NewServersClient(subscriptionID, cred, nil)
    // server, _ := client.Get(context.Background(), resourceGroupName, name, nil)
    // assert.Equal(t, "16", *server.Properties.Version)
    // assert.Equal(t, "B_Standard_B1ms", *server.Properties.SKU.Name)
}
```

**AWS pattern:**
```go
package tests

import (
    "os"
    "testing"

    "github.com/gruntwork-io/terratest/modules/aws"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestResourceComplete(t *testing.T) {
    t.Parallel()

    awsRegion := os.Getenv("AWS_DEFAULT_REGION")
    if awsRegion == "" {
        awsRegion = "us-east-1"
    }

    terraformOptions := &terraform.Options{
        TerraformDir: "../examples/complete",
    }

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    // Verify Terraform outputs
    bucketName := terraform.Output(t, terraformOptions, "name")
    assert.NotEmpty(t, bucketName)

    arn := terraform.Output(t, terraformOptions, "arn")
    assert.NotEmpty(t, arn)

    // Verify via AWS API - confirm the resource actually exists and is configured correctly
    // Use terratest aws helpers where available:
    //   github.com/gruntwork-io/terratest/modules/aws
    // Fall back to the AWS SDK for resources not covered by terratest helpers:
    //   github.com/aws/aws-sdk-go-v2/service/...

    // Example for an S3 bucket:
    aws.AssertS3BucketExists(t, awsRegion, bucketName)

    versioningStatus := aws.GetS3BucketVersioning(t, awsRegion, bucketName)
    assert.Equal(t, "Enabled", versioningStatus)

    // Example using AWS SDK directly:
    // cfg, _ := config.LoadDefaultConfig(context.Background(), config.WithRegion(awsRegion))
    // client := s3.NewFromConfig(cfg)
    // result, _ := client.GetBucketEncryption(context.Background(), &s3.GetBucketEncryptionInput{Bucket: &bucketName})
    // rule := result.ServerSideEncryptionConfiguration.Rules[0]
    // assert.Equal(t, types.ServerSideEncryptionAes256, rule.ApplyServerSideEncryptionByDefault.SSEAlgorithm)
}
```

**GCP pattern:**
```go
package tests

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/gcp"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestResourceComplete(t *testing.T) {
    t.Parallel()

    projectID := gcp.GetGoogleProjectIDFromEnvVar(t)

    terraformOptions := &terraform.Options{
        TerraformDir: "../examples/complete",
    }

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    // Verify Terraform outputs
    bucketName := terraform.Output(t, terraformOptions, "name")
    assert.NotEmpty(t, bucketName)

    // Verify via GCP API - confirm the resource actually exists and is configured correctly
    // Use terratest gcp helpers where available:
    //   github.com/gruntwork-io/terratest/modules/gcp
    // Fall back to GCP client libraries for resources not covered by terratest helpers:
    //   google.golang.org/api/...

    // Example for a storage bucket:
    bucket := gcp.GetStorageBucketE(t, projectID, bucketName)
    require.NotNil(t, bucket)
    assert.Equal(t, "US-EAST1", bucket.Location)
    assert.Equal(t, "STANDARD", bucket.StorageClass)
}
```

**Key patterns:**
- File in `tests/` directory (plural)
- Test function named `Test<Resource>Complete`
- Use `t.Parallel()` for concurrent testing
- Defer cleanup with `terraform.Destroy`
- **Always verify both Terraform outputs and cloud provider API state**
- Use terratest provider helpers (`modules/azure`, `modules/aws`, `modules/gcp`) as the first choice
- Use the provider SDK directly for resources not covered by terratest helpers
- Assert on specific configuration values (SKU, version, location, encryption settings), not just non-emptiness
- Read credentials/region from environment variables; fail clearly if required env vars are missing
- **Security settings must be verified via the cloud API.** If the module has security-related defaults (encryption, access policies, TLS settings, etc.), the test MUST assert those settings are correctly applied via the provider SDK. For example, if the module enables encryption by default, the test must verify the encryption attribute via the cloud API — not just check that a Terraform output is non-empty.

### Specific Value Assertions

> **This is the #1 most common test defect.** Models consistently write `assert.NotEmpty` when they should write `assert.Equal` with a specific expected value. This defeats the purpose of the test.

**WRONG — asserting non-emptiness (will pass even if the value is wrong):**
```go
// BAD: These assertions prove nothing about correctness
// (shown with generic attribute names — replace with your resource's actual attributes)
attr1 := result.Attributes["<resource-specific attribute>"]
assert.NotEmpty(t, attr1, "Attribute should be set")

attr2 := result.Attributes["<another attribute>"]
assert.NotEmpty(t, attr2, "Attribute should be set")
```

**RIGHT — asserting specific expected values:**
```go
// GOOD: These assertions verify the module correctly applied configuration
// AWS example (S3 bucket):
assert.Equal(t, "Enabled", result.Versioning[0].Status, "Versioning should be enabled")
assert.Equal(t, "aws:kms", result.ServerSideEncryptionConfiguration[0].Rules[0].ApplySSEByDefault[0].SSEAlgorithm)

// Azure example (PostgreSQL):
assert.Equal(t, "16", *server.Properties.Version, "PostgreSQL version should match configured value")
assert.Equal(t, "B_Standard_B1ms", *server.Properties.SKU.Name, "SKU should match configured value")

// For values from Terraform outputs, compare against the output:
expectedKeyID := terraform.Output(t, ctx.TerratestTerraformOptions(), "encryption_key_id")
assert.Equal(t, expectedKeyID, actualKeyID, "Encryption key should match Terraform output")
```

### Security Verification in Tests

> **Do NOT use conditional `if ok` patterns for security attributes.** This causes the test to silently pass when the security attribute is missing entirely — which is the exact failure case you need to catch.

**WRONG — conditional check that silently passes on missing attribute:**
```go
// BAD: If the security attribute is absent (encryption not configured), the test silently passes
if encryptionKey, ok := result.Attributes["<encryption attribute>"]; ok {
    assert.NotEmpty(t, encryptionKey, "Encryption key should be set")
}
```

**RIGHT — mandatory check that fails if attribute is missing:**
```go
// GOOD: Test fails if encryption is not configured (attribute missing)
encryptionKey, ok := result.Attributes["<encryption attribute>"]
require.True(t, ok, "Encryption attribute must be present — encryption may not be configured")
assert.NotEmpty(t, encryptionKey, "Encryption key should be set")

// EVEN BETTER: Compare against the expected key from Terraform output
expectedKeyId := terraform.Output(t, ctx.TerratestTerraformOptions(), "encryption_key_id")
assert.Equal(t, expectedKeyId, encryptionKey, "Encryption key should match the key provisioned by Terraform")
```

This pattern applies to any security attribute — encryption keys, TLS settings, access policies, etc. Replace `<encryption attribute>` with your resource's actual attribute name.

### Functional vs Readonly Tests

The skeleton provides two test directories:
- `tests/post_deploy_functional/` — Full lifecycle test: creates infrastructure, runs assertions (including write operations that exercise the resource), then destroys.
- `tests/post_deploy_functional_readonly/` — Read-only verification: assumes infrastructure already exists, performs ONLY read operations (API queries, attribute checks). **Must NOT write data, create resources, or modify state.**

> **This is one of the most commonly violated requirements.** Models frequently produce byte-for-byte identical test files, or tests that call the same implementation function. Both test directories must call DIFFERENT test implementation functions in `tests/testimpl/`.

**WRONG — both test files are identical:**
```go
// tests/post_deploy_functional/main_test.go
func TestComplete(t *testing.T) {
    testimpl.TestComposableComplete(t, ctx)  // calls same function as readonly
}

// tests/post_deploy_functional_readonly/main_test.go
func TestComplete(t *testing.T) {
    testimpl.TestComposableComplete(t, ctx)  // WRONG: identical to functional
}
```

**RIGHT — each test file calls a different implementation function:**
```go
// tests/post_deploy_functional/main_test.go
func TestComplete(t *testing.T) {
    testimpl.TestComposableComplete(t, ctx)  // includes write operations
}

// tests/post_deploy_functional_readonly/main_test.go
func TestComplete(t *testing.T) {
    testimpl.TestComposableCompleteReadonly(t, ctx)  // read-only checks only
}
```

**What makes them different in `tests/testimpl/test_impl.go`:**
- `TestComposableComplete` — Verifies Terraform outputs, calls cloud API to check configuration, AND performs write operations that exercise the resource (e.g., writing an object to a bucket, inserting a record into a database, invoking a function, etc.)
- `TestComposableCompleteReadonly` — Verifies Terraform outputs and calls cloud API to check configuration ONLY. No write operations. Focused on verifying resource existence, attributes, and security settings via read-only API calls.

### Terratest / Go Code Quality Review (Before Running Tests)

> **Run this flow for every Terratest implementation, before running `make test` or `make check`.** It catches lint errors, missing dependencies, and build failures early.

After writing or updating test code in `tests/`, run the following **from the repository root**:

1. **golangci-lint** — Lint Go code:
   ```bash
   golangci-lint run ./...
   ```
   Or use pre-commit: `pre-commit run golangci-lint --all-files`

2. **go get -u ./...** — Update dependencies to latest compatible versions:
   ```bash
   go get -u ./...
   ```

3. **go mod tidy** — Prune unused dependencies and update `go.sum`:
   ```bash
   go mod tidy
   ```

4. **go build** — Verify the test code compiles:
   ```bash
   go build ./...
   ```

**Fix any failures before running tests.** Do not proceed to `make test` until all four steps succeed. Missing `go.sum` entries or lint errors cause CI failures.

## Makefile Standards

Every module must have a Makefile with these targets:
```makefile
.PHONY: configure
configure: ## Download and configure shared makefiles and tools
    # Downloads common makefile includes and tooling

.PHONY: env
env: ## Set environment variables (cloud-provider specific)
    # Sources provider_env.sh for authentication

.PHONY: check
check: ## Run all validation checks
    # Combines lint, validate, plan, conftests, terratest, opa

.PHONY: lint
lint: ## Run tflint
    tflint --init
    tflint

.PHONY: validate
validate: ## Validate Terraform code
    terraform validate

.PHONY: test
test: ## Run Terratest
    cd tests && go test -v -timeout 30m

.PHONY: docs
docs: ## Generate documentation
    terraform-docs markdown table --output-file README.md --output-mode inject .
```

**Provider-specific notes:**
- Azure modules reference `azure_env.sh`
- AWS modules would use AWS credentials/profile
- GCP modules would use service account

## Common Anti-Patterns to Avoid

**Don't:**
- Use "this" as resource name (use descriptive names)
- Add multiple resource types to a primitive
- Include business logic or conventions
- Hardcode values (use variables)
- Create abstractions over provider resources
- Make assumptions about use cases
- Mix provider resource patterns (e.g., AWS nested blocks like Azure)
- Create a minimal wrapper with only a few variables — expose ALL commonly-used resource attributes
- Leave TODO placeholders or skeleton comments in any file (search ALL `.md` and `.go` files for `TODO:` and `skeleton`)
- Copy the functional test into the readonly test directory unchanged (they MUST call different functions)
- Leave the terraform-docs section empty in README.md (populate it before finalizing)
- Prefix output names with the resource type (use `id` not `<resource>_id`)
- Pass mutually exclusive parameters unconditionally (use conditionals or validation)
- Skip input validation blocks for bounded numerical parameters
- Use `assert.NotEmpty` for configuration values that have known expected values (use `assert.Equal` instead)
- Use `if ok { assert... }` for security attribute checks (use `require.True(t, ok, ...)` instead)
- Write a simplified usage snippet in the example README that omits variables from the actual `main.tf`
- Give two outputs identical descriptions when they share the same underlying value

**Do:**
- Wrap one resource type per primitive
- Use a security-first approach to defaults
- Expose all useful functionality via variables
- Use dynamic blocks for optional config (where provider supports it)
- Follow existing module patterns for your provider
- Keep it simple and composable
- Let reference architectures handle opinions
- Follow provider best practices for resource structure
- Add `validation {}` blocks for all numerical inputs with provider-enforced ranges
- Add short `description` fields on all outputs (for terraform-docs generation)
- Make the example demonstrate the MOST SECURE configuration pattern
- Ensure the example passes all organizational Regula/OPA policy checks without warnings
- Generate terraform-docs (or manually populate the section) before finalizing
- Use `assert.Equal` with specific expected values in ALL test assertions for configuration attributes
- Use `require.True` (not `if ok`) for security-critical API attribute checks in tests
- Include write operations in the functional test (and exclude them from the readonly test)
- Verify the example README snippet matches the actual `main.tf` line-for-line before finalizing
- Walk through the Pre-Submission Validation Checklist before considering the module complete

## Creating a New Primitive Module

When asked to create a new primitive module, follow this process:

1. **Identify provider and resource**
   - Which cloud provider? (Azure, AWS, GCP)
   - Which specific resource type?
   - Review provider documentation

2. **Find similar primitives**
   - Look at existing primitives for the same provider
   - Identify common patterns
   - Note provider-specific conventions

3. **Implement core files**
   - `versions.tf` - Set Terraform and provider versions
   - `variables.tf` - All resource arguments as variables
   - `main.tf` - Single resource with dynamic blocks
   - `outputs.tf` - Key resource attributes

4. **Create working example**
   - `examples/complete/` with all required files
   - Use resource naming module
   - Create dependencies (resource group for Azure, etc.)
   - Make it deployable

4a. **Run full example validation flow before implementing tests**
   - Run tflint, init, validate, plan, apply, destroy for `examples/complete/` (see [Full Example Validation Flow](#full-example-validation-flow-before-implementing-tests))
   - Fix any failures before proceeding to Terratest

5. **Write Terratest**
   - `tests/<resource>_test.go`
   - Deploy example, verify outputs, cleanup

5a. **Run Terratest / Go code quality review before running tests**
   - Run golangci-lint, go get -u ./..., go mod tidy, go build (see [Terratest / Go Code Quality Review](#terratest--go-code-quality-review-before-running-tests))
   - Fix any failures before running `make test`

6. **Add supporting files**
   - Standard files (LICENSE, NOTICE, etc.)
   - Provider-specific test setup

7. **Validate**
```bash
   make configure
   make check  # Run all validation
```
   Ensure cloud provider credentials are available before running `make check`. If credential issues prevent API interaction, prompt the user to fix credentials and retry.

8. **Generate documentation**
```bash
   terraform-docs markdown table --output-file README.md --output-mode inject .
```
   This populates the `<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->` section with auto-generated inputs/outputs tables. **Do NOT leave this section empty.** If `terraform-docs` is not available, manually populate the section with an inputs table and outputs table matching the module's `variables.tf` and `outputs.tf`.

9. **Clean up skeleton references.** Carefully check through ALL files and remove references to the skeleton and templates. See the Skeleton Cleanup Checklist below for a complete list of items to check.


## Skeleton Cleanup Checklist

When transforming the skeleton into a new primitive module, complete ALL of these steps:

### Files to Remove or Transform
- [ ] **TEMPLATED_README.md** → Delete after incorporating relevant content into README.md
- [ ] **Only one Terraform Check CI workflow can be present** (`.github/workflows/pull-request-terraform-check-*.yml`) → Remove Azure for AWS module, remove AWS for Azure module, etc. Keep the one that matches your provider.
- [ ] **`examples/with_cake/`** → Delete skeleton example directory

### Files to Update
- [ ] **`go.mod`** → Update the `poc-template` portion of the `github.com/nttdtest/poc-template` header to your module name
- [ ] **Test imports** → Update all Go import paths to match new `go.mod` module path
- [ ] **CI workflow skeleton guard** → Remove the `if: github.repository != 'nttdtest/poc-template'` condition from all workflow files
- [ ] **README.md** → Replace Azure-specific references (ARM_CLIENT_ID, azure_env.sh, azurerm provider) with provider-appropriate content

### Placeholders and TODOs to Remove
- [ ] **README.md TODO placeholders** → Search for `TODO:` in ALL `.md` files (root README.md AND `examples/complete/README.md`) and either replace with actual content or remove the TODO text. The most commonly missed placeholder is `TODO: INSERT DOC LINK ABOUT HOOKS` in the detect-secrets-hook section of the root README.md. **This is missed in ~40% of trials — search explicitly.**
- [ ] **Skeleton comments in test code** → Check `tests/testimpl/types.go` and other test files for comments referencing "skeleton" (e.g., `"Empty: there are no settings for the skeleton module."`). Update these to reference the actual module name.
- [ ] **Run `go mod tidy`** → After updating `go.mod` and adding new test dependencies (e.g., `github.com/aws/aws-sdk-go-v2/service/<service>` for AWS API verification), run `go mod tidy` to update `go.sum`. Missing `go.sum` entries cause `typecheck` lint failures. Run from repo root: `go mod tidy`.

### Makefile Cleanup
- [ ] **Makefile `init-clean` target** → The skeleton Makefile contains an `init-clean` target with logic to rename `TEMPLATED_README.md` to `README.MD`. This is a skeleton-specific target. While it is guarded by a file existence check and harmless, it should be removed or cleaned up for a production module. At minimum, remove the `TEMPLATED_README.md` handling block.

### Tests to Differentiate
- [ ] **`tests/post_deploy_functional_readonly/main_test.go`** → This file MUST be different from `tests/post_deploy_functional/main_test.go`. The readonly test must call a readonly-specific test function that performs only read operations (no message sends, no resource creation). See the "Functional vs Readonly Tests" section above.

## Pre-Submission Validation Checklist

Before considering the module complete, walk through EVERY item below. Each item corresponds to a defect found in prior AI-generated modules.

### Tests
- [ ] Has the Terratest / Go code quality review (golangci-lint, go get -u ./..., go mod tidy, go build) been run successfully before running tests?
- [ ] Do ALL test assertions use `assert.Equal` with specific expected values (not `assert.NotEmpty`)?
- [ ] Does the functional test (`post_deploy_functional`) include at least one write operation (send message, put object, etc.)?
- [ ] Does the readonly test (`post_deploy_functional_readonly`) call a DIFFERENT function than the functional test?
- [ ] Are the two `main_test.go` files in `post_deploy_functional/` and `post_deploy_functional_readonly/` actually different (not byte-for-byte identical)?
- [ ] Do tests use `require.True(t, ok, ...)` (not `if ok { ... }`) for security-critical attribute checks?
- [ ] Are security settings (encryption, access policies) verified via the cloud provider API, not just Terraform outputs?
- [ ] Does the test compare API-returned values against Terraform outputs or known expected values?

### README and Documentation
- [ ] Is the `<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->` section populated (not empty)?
- [ ] Have ALL `TODO:` placeholders been removed or replaced in ALL `.md` files?
- [ ] Does the `examples/complete/README.md` usage snippet exactly match `examples/complete/main.tf`?
- [ ] Does the Inputs table in the example README list ALL variables from `examples/complete/variables.tf`?
- [ ] Does the Outputs table in the example README list ALL (and ONLY) outputs from `examples/complete/outputs.tf`?

### Variables and Outputs
- [ ] Does every bounded numerical variable have a `validation {}` block?
- [ ] Are mutually exclusive parameters handled with conditionals in `main.tf` or validation blocks?
- [ ] Do validation blocks for optional (null-able) variables use ternary to avoid null evaluation? (e.g., `var.x == null ? true : (length(var.x) ...)`)
- [ ] Do all outputs reference attributes that exist in the provider schema? (Verify in provider docs — e.g., `current_state` may not exist on all resources.)
- [ ] Do all outputs have short `description` fields?
- [ ] Are output names generic (e.g., `id`, `arn`, `name`) without resource-type prefixes?
- [ ] If `id` equals another attribute (like `url`), does the `id` description clarify the overlap?

### Example
- [ ] Has the full example validation flow (tflint, init, validate, plan, apply, destroy) been run successfully for `examples/complete/` before implementing tests?
- [ ] Does `examples/complete/variables.tf` define EVERY variable from the root `variables.tf`?
- [ ] Does `examples/complete/main.tf` pass through ALL those variables to the module?
- [ ] Does `examples/complete/outputs.tf` expose EVERY output that the tests consume (e.g., `terraform.Output(t, ..., "desired_state")` requires that output)?
- [ ] Does the example use the most secure configuration (e.g., customer-managed encryption keys, not provider-managed defaults)?
- [ ] Would the example pass all Regula/OPA policy checks without warnings? (Run `make check` to verify.)

### Skeleton Cleanup
- [ ] Is `TEMPLATED_README.md` deleted?
- [ ] Is `examples/with_cake/` deleted?
- [ ] Are there zero references to `poc-template` outside `.github/agents/`?
- [ ] Is the `go.mod` module path updated?
- [ ] Are all Go import paths updated to match?
- [ ] Is the CI workflow skeleton guard (`if: github.repository != ...`) removed?
- [ ] Are all `TODO:` placeholders in README files removed?
- [ ] Are skeleton comments in `tests/testimpl/types.go` updated?
- [ ] Has `go mod tidy` been run?
- [ ] Is the Makefile `init-clean` target cleaned up?
- [ ] Is only the correct provider's CI workflow retained?

## Cross-Reference

For reference architecture patterns, see [reference-architecture-creator.agent.md](./reference-architecture-creator.agent.md)

These shared standards apply to both primitives and references:
- Commit message formats
- Pre-commit hooks
- Testing approaches
- Makefile targets
- Documentation standards

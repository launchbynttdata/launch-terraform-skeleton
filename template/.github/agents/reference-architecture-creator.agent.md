---
name: Terraform Reference Architecture Creator
description: Agent that creates a Terraform Reference Architecture from a template repository to meet our standards.
---

<!-- version: 2.1 -->

# AI Agent Guide for Reference Architecture Modules

> **This guide is for reference architecture modules** that compose multiple primitive modules.
> For primitive modules (single resource wrappers), see [primitive-module-creator.agent.md](./primitive-module-creator.agent.md)

## Changelog

- **2.1** – Migrated to `launch-terraform-skeleton` as `lcaf-skeleton-terraform` is being deprecated: re-pointed source-repo references (`go.mod` base path to `github.com/launchbynttdata/launch-terraform-template`; self-reference and the cleanup verification gate to `launch-terraform-skeleton`/`launch-terraform-template`); removed deprecated tooling references (`.lcafenv`, Regula); replaced the obsolete per-provider CI-workflow deletion and skeleton-guard-removal steps with the current unified `pull-request-check-terraform.yml` (auto-detects provider, no guard); aligned `TEMPLATED_README.md` handling with the current build-then-delete convention (retain Module Development boilerplate); renamed "Skeleton Cleanup" to "Template Cleanup". No changes to module-authoring guidance.
- **2.0** – Second reference-lambda trial round (16 trials, 4 models × 4 commits): fixed bug in readonly test example (was `RunSetupTestTeardown`, now correctly `RunNonDestructiveTest`); added skeleton transformation verification gate requiring self-check that no skeleton resources remain; added Lambda source code directory requirement for examples; added CloudWatch log group duplication warning when using `terraform-aws-modules/lambda/aws`; added module source format guidance (registry paths not `git::` URLs); added output naming convention (consistent prefixes); standardized feature flag variable naming on `create_*` not `enable_*`; added explicit readonly test anti-pattern examples showing the three most common mistakes; reinforced `assert.NotEmpty` ban with stronger language
- **1.9** – Reference-lambda trial feedback: strengthened example `resource_names` anti-pattern warning with explicit "the example MUST NOT" language and code diff; added `providers.tf` ban for examples (conflicts with auto-generated `provider.tf`); added `RunNonDestructiveTest` requirement to skeleton cleanup checklist; added community module version compatibility pre-check step with concrete version examples; strengthened IAM inline resource ban with `aws_kms_alias` as an additional example; added KMS key ID vs ARN clarification; strengthened skeleton cleanup checklist with explicit go.mod, test import, and test function rename items elevated to mandatory; added per-resource SDK verification checklist for Lambda architectures; added duplicate IAM permissions warning for `attach_cloudwatch_logs_policy`
- **1.8** – Strengthened test assertion specificity: banned `assert.NotEmpty` for attributes with known expected values, added explicit `assert.Equal` examples deriving values from `test.tfvars`; strengthened functional vs readonly test differentiation with concrete write-operation requirements; mandated KMS encryption in examples and tests; added README verification checklist requiring cross-referencing against actual code; added `name`/`name_prefix` mutual exclusion as a variable validation example; added explicit `terraform-docs` or manual copy-paste requirement for README tables
- **1.7** – Restored cloud-provider balance: scoped IAM block as AWS-specific and added Azure Networking & Security Best Practices; added complete Azure PostgreSQL test example with SDK verification (matching the AWS Lambda example in depth); added Azure naming format guidance alongside AWS examples
- **1.6** – Added concrete AWS SDK verification examples for Lambda, CloudWatch, IAM, SQS, and KMS using lcaf-component-terratest framework; added complete read-only vs destructive test implementations; replaced commented-out AWS test pattern with working code
- **1.5** – Strengthened testing requirements (SDK verification is mandatory, not optional); added IAM least-privilege and anti-duplication rules; added community module version compatibility warning; clarified example must not redundantly compose resource_names; strengthened skeleton cleanup checklist; added read-only vs destructive test differentiation; added README documentation requirements
- **1.4** – Fixed version header (block must come first to be recognized as an agent)
- **1.3** – Added agent header, migrated to agents folder, added skeleton cleanup checklist.
- **1.2** – Fixed resource naming module usage: `for_each = var.resource_names_map` (not a module input), correct variable name `class_env` (not `environment`), added required `cloud_resource_type`/`maximum_length` params, corrected output reference syntax to `module.resource_names["key"].format`, noted hyphens-stripping for AWS regions, replaced incorrect `resource_names_strategy` variable pattern with correct per-resource output format selection
- **1.1** – Added cloud provider API verification patterns (Azure, AWS, GCP) to Terratest guidance; tests must now verify real resource state via provider SDKs, not just Terraform outputs; reference architecture tests must also cover optional features enabled in the example
- **1.0** – Initial release

> **For agents working in the skeleton repo (`launch-terraform-skeleton`):** If you modify this file, update the `<!-- version -->` comment at the top and add a changelog entry here. Bump the minor version (e.g. 1.1 → 1.2) for new guidance or clarifications; bump the major version (e.g. 1.x → 2.0) for changes that would require significant rework of existing modules. Never make changes to older entries in the changelog, add new entries at the top.

> **Maintenance rule — keep guidance generic.** This guide applies to ALL reference architecture modules across all cloud providers, not just the resource type used in any particular experiment. When updating this file, do not embed service-specific attribute names into patterns meant to be universal. If a concrete example helps clarify a pattern, show one per cloud provider and label each clearly (e.g., "Azure example," "AWS example," "GCP example"). Prefer generic placeholders like `<resource-specific attribute>` in comparisons and checklists.

## Overview

Reference architecture modules compose multiple primitive modules to implement complete infrastructure patterns with opinionated configurations, best practices, and additional capabilities like monitoring and private networking.

**Repository naming:** `tf-<provider>-module_reference-<architecture>`

**Examples:**
- `tf-azurerm-module_reference-postgresql_server`
- `tf-aws-module_reference-lambda_function`
- `tf-google-module_reference-gke_cluster`

## Cloud Providers Supported

- **Azure** (`azurerm` provider) - Primary platform
- **AWS** (`aws` provider) - Large number of modules
- **Google Cloud** (`google` provider) - Growing library

**This guide applies to all cloud providers.** Provider-specific differences are noted where relevant.

## What Makes a Reference Architecture?

Unlike primitives which wrap a single resource with no opinions, reference architectures:
- **Compose multiple primitives** - orchestrate several primitive modules
- **Implement patterns** - encode best practices and organizational standards
- **Add capabilities** - monitoring, alerting, private endpoints, identity integration
- **Provide opinions** - sensible defaults for security and compliance
- **Abstract complexity** - hide implementation details from consumers

## Key Differences from Primitives

| Aspect | Primitives | Reference Architectures |
|--------|-----------|------------------------|
| Purpose | Wrap single resource | Implement complete pattern |
| Resources | ONE resource type | Multiple primitives composed |
| Dependencies | Minimal (just provider) | Many primitives from registry |
| Opinions | None - maximum flexibility | Opinionated - enforce standards |
| Business Logic | No | Yes - implement conventions |
| Variables | Mirror resource arguments | Higher-level abstractions |
| Consumers | Other modules | End users / applications |

## Required File Structure
```
tf-<provider>-module_reference-<architecture>/
├── .github/workflows/      # CI/CD with pre-commit, tests
├── examples/
│   └── complete/           # REQUIRED: Full working example
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       ├── test.tfvars     # Non-default values for testing
│       └── README.md
├── tests/                  # Note: "tests" not "test"
│   └── <architecture>_test.go
├── main.tf                 # REQUIRED: Compose primitives
├── variables.tf            # REQUIRED: High-level inputs
├── outputs.tf              # REQUIRED: Aggregated outputs
├── versions.tf             # REQUIRED: Version constraints
├── locals.tf               # OPTIONAL: Computed values
├── README.md               # REQUIRED: Auto-generated docs
├── Makefile                # REQUIRED: Standard targets
├── go.mod                  # Go dependencies for Terratest
├── go.sum                  # Go dependency checksums
├── LICENSE                 # Apache 2.0
├── NOTICE                  # Copyright notice
├── CODEOWNERS              # GitHub code owners
├── .gitignore              # Standard ignores
├── .tool-versions          # asdf tool versions
└── .secrets.baseline       # Detect-secrets baseline
```

> **WARNING — Do NOT create a `providers.tf` file in `examples/complete/`.** The build system (`make configure`) auto-generates a `provider.tf` file (singular, gitignored) in the example directory. If you also commit a `providers.tf` file with a `provider "aws" {}` block, Terraform will fail with `Error: Duplicate provider configuration`. Only create `versions.tf` (with `required_providers`) in the example directory — never a `provider` block.

## Composition Patterns

### Always Use the Resource Naming Module

Every reference architecture should start with the resource naming module.

`resource_names_map` is used as `for_each` — the module is invoked once per resource type. The map key (e.g. `"resource_group"`, `"postgresql_server"`) becomes the instance key used to retrieve the generated name. Each instance produces multiple output formats (`standard`, `minimal_random_suffix`, `dns_compliant_standard`, etc.) — choose the appropriate format per resource in your locals or inline.

**Azure pattern:**
```hcl
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

  # Azure region names have no hyphens (e.g. "eastus"), so pass directly
  region                = var.location
  use_azure_region_abbr = var.use_azure_region_abbr
}
```

**AWS pattern:**
```hcl
data "aws_region" "current" {}

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

  # AWS regions have hyphens (e.g. "us-east-1") — strip them so they don't
  # appear as extra separators in generated names
  region = join("", split("-", data.aws_region.current.name))
}
```

**Referencing generated names:**
```hcl
# Syntax: module.resource_names["<map_key>"].<output_format>
module.resource_names["resource_group"].standard          # e.g. "launch-database-eus-dev-rg-000"
module.resource_names["postgresql_server"].standard       # e.g. "launch-database-eus-dev-psql-000"
module.resource_names["s3_bucket"].minimal_random_suffix  # e.g. "launch-bkt-5823947201" (for globally unique names)
module.resource_names["lambda_function"].dns_compliant_standard  # for DNS-constrained names
```

**Why:** Ensures consistent naming across all resources in the architecture.

### Create Resource Group (Azure Only)

**Azure pattern:**
```hcl
module "resource_group" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/resource_group/azurerm"
  version = "~> 1.0"

  name     = module.resource_names["resource_group"].standard
  location = var.location
  tags     = var.tags
}
```

**AWS pattern:**
```hcl
# No resource group in AWS
# Use tags for grouping and organization
```

**Pattern:** All subsequent Azure resources reference `module.resource_group.name` and `var.location`. AWS uses tags instead.

### Compose Primitives from Registry

**Pattern 1: Using Internal Primitives**

**Azure example:**
```hcl
module "postgresql_server" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/postgresql_server/azurerm"
  version = "~> 1.1"

  name                = module.resource_names["postgresql_server"].standard
  resource_group_name = module.resource_group.name
  location            = var.location

  # Pass through core configuration
  sku_name                      = var.sku_name
  postgres_version              = var.postgres_version
  storage_mb                    = var.storage_mb

  # Networking
  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id
  public_network_access_enabled = var.public_network_access_enabled

  # Authentication
  authentication         = var.authentication
  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password

  tags = var.tags
}
```

**AWS example:**
```hcl
module "s3_bucket" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/s3_bucket/aws"
  version = "~> 1.0"

  bucket = module.resource_names["s3_bucket"].minimal_random_suffix  # S3 bucket names are globally unique

  # Pass through configuration
  versioning_enabled = var.versioning_enabled
  encryption_enabled = var.encryption_enabled

  tags = var.tags
}
```

**Pattern 2: Using Community Modules**

AWS reference architectures may use well-established community modules:
```hcl
module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.4"

  function_name = module.resource_names["lambda_function"].minimal_random_suffix
  description   = var.description
  handler       = var.handler
  runtime       = var.runtime

  # ... extensive configuration

  tags = var.tags
}
```

**When to use community modules:**
- Well-maintained, popular modules with good track records
- Complex resources that would duplicate significant effort
- AWS Lambda, VPC, ECS - where terraform-aws-modules are standard

> **CRITICAL — Version compatibility (causes Critical failures in trials):** Before selecting a community module version, you MUST verify that the module version is compatible with the provider version constraint in your `versions.tf`. **This is a blocking step — do NOT proceed until you have confirmed compatibility.**
>
> **How to verify:** Check the community module's `versions.tf` or GitHub releases page for its `required_providers` constraint. If your module requires `aws ~> 5.14`, the community module MUST NOT require `aws >= 6.x`.
>
> **Known-safe versions for AWS provider ~> 5.14:**
> - `terraform-aws-modules/lambda/aws` → use `~> 7.4` (NOT `~> 8.0` which requires AWS 6.x)
> - `terraform-aws-modules/sqs/aws` → use `~> 4.0` (NOT `~> 5.0` which requires AWS 6.x)
> - `terraform-aws-modules/kms/aws` → use `~> 2.1` or `~> 3.0` (NOT `~> 4.0` which requires AWS 6.x)
>
> Run `terraform init` after adding module sources to confirm compatibility. Using incompatible versions will cause `make lint` and `make check` to fail with: `no available releases match the given constraints`.

**When to use internal primitives:**
- Simpler resources
- When you need strict control over implementation
- When organizational standards differ from community patterns

### Add Configuration Primitives (for_each pattern)
```hcl
module "postgresql_server_configuration" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/postgresql_server_configuration/azurerm"
  version  = "~> 1.0"
  for_each = var.server_configuration

  name      = each.key
  server_id = module.postgresql_server.id
  value     = each.value
}
```

**Pattern:** Use `for_each` to create multiple configuration resources from a map variable.

### Add Optional Features (count pattern)

**Azure example - Active Directory Administrator:**
```hcl
module "postgresql_server_ad_administrator" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/postgresql_server_ad_administrator/azurerm"
  version = "~> 1.0"
  count   = var.ad_administrator != null ? 1 : 0

  server_id      = module.postgresql_server.id
  tenant_id      = var.ad_administrator.tenant_id
  object_id      = var.ad_administrator.object_id
  principal_name = var.ad_administrator.principal_name
  principal_type = var.ad_administrator.principal_type
}
```

**AWS example - IAM policies:**
```hcl
module "lambda_iam_role" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/iam_role/aws"
  version = "~> 1.0"
  count   = var.create_iam_role ? 1 : 0

  name               = module.resource_names["iam_role"].standard
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = var.tags
}
```

**Pattern:** Use `count` for optional single-instance features based on variable presence or boolean flags.

### Add Private Endpoint (Azure pattern)
```hcl
module "private_endpoint" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/private_endpoint/azurerm"
  version = "~> 1.0"
  count   = var.create_private_endpoint ? 1 : 0

  name                = module.resource_names["private_endpoint"].standard
  resource_group_name = module.resource_group.name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection_name = module.resource_names["private_service_connection"].standard
  private_connection_resource_id  = module.postgresql_server.id
  is_manual_connection            = var.private_endpoint_is_manual_connection
  subresource_names               = var.private_endpoint_subresource_names
  request_message                 = var.private_endpoint_request_message

  private_dns_zone_group_name = var.private_endpoint_dns_zone_group_name
  private_dns_zone_ids        = var.private_endpoint_dns_zone_ids

  tags = var.tags
}
```

**AWS equivalent - VPC endpoints:**
```hcl
module "vpc_endpoint" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/vpc_endpoint/aws"
  version = "~> 1.0"
  count   = var.create_vpc_endpoint ? 1 : 0

  vpc_id             = var.vpc_id
  service_name       = var.service_name
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  tags = var.tags
}
```

### Add Monitoring (conditional)

**Azure example:**
```hcl
module "monitor_action_group" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/monitor_action_group/azurerm"
  version = "~> 1.0.0"
  count   = var.action_group != null ? 1 : 0

  name                = var.action_group.name
  resource_group_name = var.resource_group_name != "" ? var.resource_group_name : module.resource_group.name
  short_name          = var.action_group.short_name

  email_receivers    = var.action_group.email_receivers
  arm_role_receivers = var.action_group.arm_role_receivers

  tags = var.tags
}

module "monitor_metric_alert" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/monitor_metric_alert/azurerm"
  version  = "~> 2.0"
  for_each = var.metric_alerts

  name                = "${module.resource_names["postgresql_server"].standard}-${each.key}"
  resource_group_name = var.resource_group_name != "" ? var.resource_group_name : module.resource_group.name
  scopes              = [module.postgresql_server.id]

  description = each.value.description
  severity    = each.value.severity
  frequency   = each.value.frequency
  enabled     = each.value.enabled

  action_group_ids = concat(
    var.action_group != null ? [module.monitor_action_group[0].id] : [],
    var.action_group_ids
  )

  criteria         = each.value.criteria
  dynamic_criteria = each.value.dynamic_criteria

  tags = var.tags
}
```

**AWS example - CloudWatch:**
```hcl
module "cloudwatch_log_group" {
  source  = "terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_log_group/aws"
  version = "~> 1.0"
  count   = var.create_cloudwatch_logs ? 1 : 0

  name              = "/aws/lambda/${module.lambda_function.function_name}"
  retention_in_days = var.cloudwatch_logs_retention_in_days
  kms_key_id        = var.cloudwatch_logs_kms_key_id

  tags = var.tags
}

module "cloudwatch_metric_alarm" {
  source   = "terraform.registry.launch.nttdata.com/module_primitive/cloudwatch_metric_alarm/aws"
  version  = "~> 1.0"
  for_each = var.metric_alarms

  alarm_name          = "${module.lambda_function.function_name}-${each.key}"
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = each.value.period
  statistic           = each.value.statistic
  threshold           = each.value.threshold
  alarm_description   = each.value.description
  alarm_actions       = each.value.alarm_actions

  dimensions = {
    FunctionName = module.lambda_function.function_name
  }

  tags = var.tags
}
```

## Variables Pattern

### Resource Naming Map

**Standard for all reference architectures:**
```hcl
variable "resource_names_map" {
  description = "A map of key to resource_name that will be used by tf-launch-module_library-resource_name to generate resource names"
  type = map(object({
    name       = string
    max_length = optional(number, 60)
  }))

  # Azure example
  default = {
    resource_group = {
      name       = "rg"
      max_length = 60
    }
    postgresql_server = {
      name       = "psql"
      max_length = 60
    }
    private_endpoint = {
      name       = "pe"
      max_length = 80
    }
  }

  # AWS example
  # default = {
  #   lambda_function = {
  #     name       = "fn"
  #     max_length = 80
  #   }
  #   iam_role = {
  #     name       = "role"
  #     max_length = 64
  #   }
  #   cloudwatch_log_group = {
  #     name       = "lg"
  #     max_length = 512
  #   }
  # }
}
```

**Choosing the right output format per resource:**

Each `module.resource_names` instance exposes multiple output formats. Choose the right one per resource in locals:
```hcl
locals {
  # Most resources: use standard
  iam_role_name    = module.resource_names["iam_role"].standard

  # Globally unique resources (S3 buckets, etc.): use minimal_random_suffix
  s3_bucket_name   = module.resource_names["s3_bucket"].minimal_random_suffix

  # Resources with DNS naming constraints: use dns_compliant_* variants
  lambda_name      = module.resource_names["lambda_function"].dns_compliant_minimal_random_suffix
}
```

Available output formats: `standard`, `lower_case`, `upper_case`, `minimal`, `minimal_random_suffix`, `dns_compliant_standard`, `dns_compliant_minimal`, `dns_compliant_minimal_random_suffix`, `camel_case`, `recommended_per_length_restriction`.

> **Choose the right format explicitly.** Do NOT default to `recommended_per_length_restriction` — it auto-selects based on max_length which may produce unexpected name formats. Instead, explicitly select the format in locals:
> - `.standard` — most resources (IAM roles, policies, CloudWatch log groups, security groups, Azure resource groups, PostgreSQL servers, VNets, subnets)
> - `.minimal_random_suffix` — globally unique resources (S3 buckets, ECR repositories, Azure Storage accounts)
> - `.dns_compliant_minimal_random_suffix` — resources with DNS naming constraints (Lambda functions, API Gateway, ECS services)
>
> **AWS example (Lambda):** Use `module.resource_names["lambda_function"].dns_compliant_minimal_random_suffix`, NOT `.minimal_random_suffix` or `.recommended_per_length_restriction`.
>
> **Azure example (PostgreSQL):** Use `.standard` for the server and resource group (`module.resource_names["postgresql_server"].standard`); use `.minimal_random_suffix` for globally unique resources like Storage accounts (`module.resource_names["storage_account"].minimal_random_suffix`).

### Naming Context Variables

**Standard for all reference architectures:**
```hcl
variable "logical_product_family" {
  description = "(Required) Name of the product family for which the resource is created. Example: org_name, department_name."
  type        = string
  default     = "launch"
}

variable "logical_product_service" {
  description = "(Required) Name of the product service for which the resource is created. For example, backend, frontend, middleware etc."
  type        = string
  default     = "database"  # or "lambda", "storage", etc.
}

variable "class_env" {
  description = "(Required) Environment where resource is going to be deployed. For example. dev, qa, uat"
  type        = string
  default     = "dev"
}

variable "instance_env" {
  description = "Number that represents the instance of the environment."
  type        = number
  default     = 0
}

variable "instance_resource" {
  description = "Number that represents the instance of the resource."
  type        = number
  default     = 0
}

# Azure-specific
variable "use_azure_region_abbr" {
  description = "Abbreviate the region in the resource names"
  type        = bool
  default     = true
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "eastus"
}

# AWS doesn't need location variable - uses data source
# data "aws_region" "current" {}

variable "tags" {
  description = "A mapping of tags to assign to the resource."
  type        = map(string)
  default     = {}
}
```

### Core Service Variables

**Pass through from primitive, but provide better defaults:**

**Azure example:**
```hcl
variable "sku_name" {
  description = "The name of the SKU used by this Postgres Flexible Server"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_version" {
  description = "Version of the Postgres Flexible Server"
  type        = string
  default     = "16"
}

variable "storage_mb" {
  description = "The storage capacity in megabytes"
  type        = number
  default     = 32768  # Reference architecture provides default
}
```

**AWS example:**
```hcl
variable "runtime" {
  description = "Lambda Function runtime"
  type        = string
  default     = "python3.9"
}

variable "handler" {
  description = "Lambda Function entrypoint in your code"
  type        = string
  default     = "index.lambda_handler"
}

variable "memory_size" {
  description = "Amount of memory in MB your Lambda Function can use at runtime"
  type        = number
  default     = 128
}

variable "timeout" {
  description = "The amount of time your Lambda Function has to run in seconds"
  type        = number
  default     = 3
}
```

### Variable Validation

Add `validation` blocks for variables with known constraints, especially mutual exclusion:

```hcl
# Example: name vs name_prefix mutual exclusion (common in AWS resources)
variable "name" {
  description = "Name of the resource. Conflicts with name_prefix."
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Name prefix for the resource. Conflicts with name."
  type        = string
  default     = null

  validation {
    condition     = var.name == null || var.name_prefix == null
    error_message = "Only one of 'name' or 'name_prefix' can be set, not both."
  }
}
```

When a resource supports both `name` and `name_prefix`, expose both variables and add a validation block to enforce mutual exclusion. This prevents confusing Terraform errors at plan time.

### Feature Flag Variables

**Enable/disable optional capabilities:**
```hcl
# Azure example
variable "create_private_endpoint" {
  description = "Whether or not to create a Private Endpoint"
  type        = bool
  default     = false
}

# AWS example
variable "create_lambda_function_url" {
  description = "Whether the Lambda Function URL resource should be created"
  type        = bool
  default     = true
}

variable "create" {
  description = "Controls whether resources should be created"
  type        = bool
  default     = false  # Common in AWS modules for safety
}
```

### Complex Object Variables

**For optional features with multiple fields:**
```hcl
# Azure example
variable "ad_administrator" {
  description = <<-EOT
    tenant_id      = The tenant ID of the AD administrator
    object_id      = The object ID of the AD administrator
    principal_name = The name of the principal to assign as AD administrator
    principal_type = The type of principal to assign as AD administrator
  EOT
  type = object({
    tenant_id      = string
    object_id      = string
    principal_name = string
    principal_type = string
  })
  default = null
}

# AWS example
variable "cors" {
  description = "CORS settings to be used by the Lambda Function URL"
  type = object({
    allow_credentials = optional(bool, false)
    allow_headers     = optional(list(string), null)
    allow_methods     = optional(list(string), null)
    allow_origins     = optional(list(string), null)
    expose_headers    = optional(list(string), null)
    max_age           = optional(number, 0)
  })
  default = {}
}
```

## Outputs Pattern

### Aggregate Key Information
```hcl
# Azure example
output "id" {
  description = "The ID of the PostgreSQL server"
  value       = module.postgresql_server.id
}

output "name" {
  description = "The name of the PostgreSQL server"
  value       = module.postgresql_server.name
}

output "fqdn" {
  description = "The FQDN of the PostgreSQL server"
  value       = module.postgresql_server.fqdn
}

output "resource_group_name" {
  description = "The name of the resource group"
  value       = module.resource_group.name
}

# AWS example
output "lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = module.lambda_function.lambda_function_arn
}

output "lambda_function_name" {
  description = "The name of the Lambda function"
  value       = module.lambda_function.lambda_function_name
}

output "lambda_function_url" {
  description = "The URL of the Lambda function"
  value       = module.lambda_function.lambda_function_url
}

output "lambda_role_arn" {
  description = "The ARN of the IAM role for the Lambda function"
  value       = module.lambda_function.lambda_role_arn
}
```

### Expose Optional Feature Outputs
```hcl
# Azure example
output "admin_tenant_id" {
  description = "The tenant ID of the AD administrator"
  value       = var.ad_administrator != null ? module.postgresql_server_ad_administrator[0].tenant_id : null
}

# AWS example
output "cloudwatch_log_group_arn" {
  description = "The ARN of the CloudWatch log group"
  value       = var.create_cloudwatch_logs ? module.cloudwatch_log_group[0].arn : null
}
```

### Expose Configuration State
```hcl
# Azure example
output "server_configuration" {
  description = "Map of server configurations applied"
  value       = { for k, v in module.postgresql_server_configuration : k => v.value }
}

# AWS example
output "lambda_iam_policies" {
  description = "List of IAM policies attached to Lambda role"
  value       = var.attach_policies ? var.policies : []
}
```

## versions.tf Pattern

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
  required_version = "~> 1.5"  # Newer - Azure modules should update

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.14"
    }
  }
}
```

**NOTE:** AWS modules using `~> 1.5` represents a newer standard. Azure modules still using `~> 1.0` should be updated to match.

> **WARNING:** Always use pessimistic version constraints (`~>`) for the AWS provider, NOT open-ended constraints like `>= 5.0`. Using `>= 5.0` allows future major versions (e.g., 6.x) which may introduce breaking changes and incompatibilities with community modules. Use `~> 5.14` to pin to the 5.x line.

## locals.tf Pattern

Use locals for computed values, complex logic, or to avoid repetition:

**Azure example:**
```hcl
locals {
  # Determine resource group for monitoring resources
  monitor_resource_group = var.resource_group_name != "" ? var.resource_group_name : module.resource_group.name

  # Combine action group IDs
  all_action_group_ids = concat(
    var.action_group != null ? [module.monitor_action_group[0].id] : [],
    var.action_group_ids
  )

  # Compute complex conditionals
  private_endpoint_enabled = var.create_private_endpoint && var.private_endpoint_subnet_id != null
}
```

**AWS example:**
```hcl
locals {
  # Pick the appropriate output format per resource type
  function_name   = module.resource_names["lambda_function"].dns_compliant_minimal_random_suffix
  iam_role_name   = module.resource_names["iam_role"].standard

  # Determine IAM role ARN
  lambda_role_arn = var.create_iam_role ? module.lambda_iam_role[0].arn : var.existing_iam_role_arn
}
```

**When to use locals:**
- Complex conditionals used multiple times
- Data transformations
- Combining lists or maps
- Default value computation
- Selecting the right resource name output format per resource

## Provider-Specific Patterns

### Azure Patterns

**Resource Group Management:**
```hcl
variable "resource_group_name" {
  description = "Optional resource group name. If empty, a new one is created."
  type        = string
  default     = ""
}

module "resource_group" {
  source  = "..."
  version = "~> 1.0"
  count   = var.resource_group_name == "" ? 1 : 0

  name     = module.resource_names["resource_group"].standard
  location = var.location
  tags     = var.tags
}

locals {
  resource_group_name = var.resource_group_name != "" ? var.resource_group_name : module.resource_group[0].name
}
```

**Private Networking:**
- Private endpoints for PaaS services
- VNet integration for secure access
- Private DNS zones for name resolution

**Monitoring:**
- Azure Monitor action groups
- Metric alerts
- Log Analytics workspaces

### AWS Patterns

**Region from Data Source:**
```hcl
data "aws_region" "current" {}

# Use data.aws_region.current.name in modules
```

**Selecting naming output format in locals:**
```hcl
locals {
  # Use the output format appropriate to each resource's constraints:
  # - .standard for most resources
  # - .minimal_random_suffix for globally unique resources (S3, ECR, etc.)
  # - .dns_compliant_* for DNS-constrained resources
  function_name = module.resource_names["lambda_function"].dns_compliant_minimal_random_suffix
  bucket_name   = module.resource_names["s3_bucket"].minimal_random_suffix
}
```

**Using Community Modules:**
```hcl
module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.4"

  # Extensive configuration options
  # Well-maintained, widely used
}
```

**IAM Best Practices (AWS):**

> **WARNING — Common mistakes with IAM and inline resources in AWS reference architectures:**
>
> 1. **Never use inline `resource` blocks.** IAM roles, policies, attachments, AND auxiliary resources like KMS aliases MUST be created via a primitive module or a community module — never as inline `resource` blocks. Creating `aws_iam_role`, `aws_iam_role_policy`, `aws_iam_role_policy_attachment`, `aws_kms_alias`, or any other `resource` block directly is a Critical anti-pattern. If a community module supports creating the resource (e.g., KMS module supports `aliases` parameter), use that instead of an inline resource. If no primitive or community module parameter exists, document the exception in a code comment.
>
> 2. **Scope IAM policies to the minimum required resources.** Never use `arn:aws:logs:*:*:*` or similar wildcard ARNs. Always scope to the specific region and account using `data "aws_region" "current"` and `data "aws_caller_identity" "current"`:
>    ```hcl
>    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.function_name}:*"]
>    ```
>
> 3. **Avoid duplicate permissions (common trial failure).** If a community module (e.g., `terraform-aws-modules/lambda/aws`) has `attach_cloudwatch_logs_policy = true`, do NOT also create a separate IAM policy granting `logs:CreateLogGroup`, `logs:CreateLogStream`, or `logs:PutLogEvents` permissions. Similarly, do NOT attach `AWSLambdaBasicExecutionRole` managed policy AND create an inline logging policy — they grant the same permissions. Choose ONE source of truth for each permission set. When using the Lambda community module, prefer its built-in `attach_cloudwatch_logs_policy = true` over manual policy creation.

**Networking & Security Best Practices (Azure):**

> **WARNING — Common mistakes with networking and security in Azure reference architectures:**
>
> 1. **Disable public network access by default.** Set `public_network_access_enabled = false` (or the equivalent attribute) on the primary resource. Expose a variable to let consumers override this when needed, but the default must be private.
>
> 2. **Always support private networking.** Include a private endpoint primitive with a `count` toggle (e.g., `var.create_private_endpoint`). Wire up the `private_service_connection` sub-resource to the primary resource's ID.
>
> 3. **Manage resource groups via primitives.** Do NOT create `azurerm_resource_group` as an inline resource. Use the resource-group primitive module (`terraform.registry.launch.nttdata.com/module_primitive/resource_group/azurerm` or equivalent) and accept the resource group name as an output from that primitive.
>
> 4. **Configure VNet integration where applicable.** For services that support it (e.g., PostgreSQL Flexible Server, App Service), accept `delegated_subnet_id` and `private_dns_zone_id` variables and wire them into the primary resource's network configuration.

**IAM Policy Flexibility:**
```hcl
variable "attach_policy_statements" {
  type    = bool
  default = false
}

variable "policy_statements" {
  type    = map(string)
  default = {}
}

variable "attach_policy" {
  type    = bool
  default = false
}

variable "policy" {
  type    = string
  default = null
}

# Multiple ways to attach policies
```

**VPC Integration:**
```hcl
variable "vpc_subnet_ids" {
  description = "List of subnet ids when Lambda should run in VPC"
  type        = list(string)
  default     = null
}

variable "vpc_security_group_ids" {
  description = "List of security group ids when Lambda should run in VPC"
  type        = list(string)
  default     = null
}
```

> **CRITICAL — KMS Key ID vs ARN (common trial mistake):** Many AWS APIs and Terraform parameters named `kms_key_id` actually expect a KMS key **ARN**, not a UUID key ID. For example, `cloudwatch_logs_kms_key_id` in the Lambda community module expects an ARN (`arn:aws:kms:us-east-1:123456789012:key/...`), not a UUID (`12345678-1234-...`). When referencing a KMS key created by a KMS module, use `.key_arn` (not `.key_id`) for CloudWatch Logs encryption. Always check the upstream module or provider documentation for the expected format. Naming your variables and locals consistently (`kms_key_arn` when storing ARNs) helps avoid this confusion.

**CloudWatch Logs:**
```hcl
variable "attach_cloudwatch_logs_policy" {
  type    = bool
  default = true
}

variable "cloudwatch_logs_retention_in_days" {
  type    = number
  default = 30
}

variable "cloudwatch_logs_kms_key_id" {
  type    = string
  default = null
}
```

## Testing Pattern

### Terratest for Reference Architectures

Tests must verify **both** Terraform outputs **and** actual resource state via the cloud provider API. Terraform outputs are generated by Terraform itself and do not prove the cloud resources were actually created or configured correctly. Always use provider SDK helpers to confirm real resource state for each significant resource in the architecture.

> **WARNING — Most common trial failure:** Checking only that a Terraform output is non-empty (e.g., `assert.NotEmpty(t, terraform.Output(..., "role_arn"))`) does **NOT** satisfy the API verification requirement. You MUST make an actual SDK call (e.g., `iam.GetRole`, `sqs.GetQueueAttributes`, `kms.DescribeKey`, `cloudwatchlogs.DescribeLogGroups`, `lambda.GetFunction`) and assert on properties of the returned object. Every significant resource in the architecture needs its own SDK verification — do not skip any.

Reference architecture tests MUST cover ALL of the following:
- The primary resource (existence + key configuration attributes via SDK)
- **Every optional feature that is enabled in the example** (DLQ, KMS, CloudWatch Log Group, IAM role, etc.) — each verified via its respective cloud provider SDK
- IAM role existence and attached policies (via `iam.GetRole` + `iam.ListAttachedRolePolicies` — do NOT use `ListRolePolicies` which only lists inline policies)
- Outputs from composed primitives (resource group name, FQDNs, ARNs, etc.)

> **Anti-pattern:** A test that only calls `terraform.Output()` and `assert.NotEmpty()` without any SDK call is incomplete and will be flagged as a High severity issue.

> **AWS Lambda reference architecture — mandatory SDK verification checklist:**
> Every resource below that is enabled in the example MUST have its own SDK verification test. Checking only the Terraform output is NOT sufficient.
>
> | Resource | SDK Call | What to Assert |
> |----------|---------|----------------|
> | Lambda function | `lambda.GetFunction` | FunctionArn, FunctionName, Runtime, State=Active, MemorySize, Timeout |
> | IAM role | `iam.GetRole` + `iam.ListAttachedRolePolicies` | Role ARN, at least one attached policy |
> | CloudWatch Log Group | `cloudwatchlogs.DescribeLogGroups` | Log group name, RetentionInDays, KmsKeyId (if KMS enabled) |
> | SQS DLQ | `sqs.GetQueueAttributes` | QueueArn, KmsMasterKeyId, MessageRetentionPeriod |
> | KMS key | `kms.DescribeKey` | KeyMetadata.Enabled=true, KeyId |
>
> Do NOT skip any of these if the resource is created in the example. A test file with only Lambda verification but no DLQ/KMS/CloudWatch/IAM SDK calls will be flagged as High severity.

> **CRITICAL — Test Assertion Specificity (most common failure across ALL models in ALL trial rounds):**
>
> **`assert.NotEmpty` is BANNED for configuration attributes that have known expected values.** Despite explicit instructions, 3/16 trials in the latest round still used `assert.NotEmpty` for values like Runtime, MemorySize, and Timeout that are known from `test.tfvars`. This is a zero-tolerance rule. When the expected value can be derived from `test.tfvars` or the module defaults, you MUST use `assert.Equal` with the specific expected value. Before writing ANY assertion, check: "Do I know what value this should be?" If yes, use `assert.Equal`.
>
> **BAD — will be flagged as High severity:**
> ```go
> // WRONG: Checks non-emptiness instead of the actual expected value
> assert.NotEmpty(t, result.Attributes["VisibilityTimeout"])
> assert.NotEmpty(t, *result.Configuration.Runtime)
> assert.NotEmpty(t, *server.Properties.Version)
> ```
>
> **GOOD — assert on specific expected values:**
> ```go
> // RIGHT: Assert the exact value from test.tfvars or module defaults
> assert.Equal(t, "30", result.Attributes["VisibilityTimeout"])
> assert.Equal(t, lambdaTypes.RuntimePython39, result.Configuration.Runtime)
> assert.Equal(t, armpostgresqlflexibleservers.ServerVersion("16"), *server.Properties.Version)
> ```
>
> **How to determine expected values:** Read the `test.tfvars` file (or the module's `variables.tf` defaults) and use those values in your assertions. For AWS API responses, note that most attribute values are returned as strings (e.g., `"30"` not `30` for visibility timeout, `"true"` not `true` for boolean attributes).
>
> **Conditional checks that silently pass are also banned:**
> ```go
> // WRONG: If the attribute is missing, the test silently passes
> if val, ok := result.Attributes["KmsMasterKeyId"]; ok {
>     assert.NotEmpty(t, val)
> }
>
> // RIGHT: Assert the attribute exists and has the expected value
> require.Contains(t, result.Attributes, "KmsMasterKeyId", "KMS key must be configured")
> assert.Equal(t, expectedKmsKeyId, result.Attributes["KmsMasterKeyId"])
> ```

### Read-Only vs Destructive Tests

The `post_deploy_functional` and `post_deploy_functional_readonly` test directories serve different purposes and **must not be identical**:

- **`post_deploy_functional`**: **MUST** include at least one write/mutating operation that exercises the deployed resource. This is what distinguishes it from the readonly test. Examples of required write operations by resource type:
  - **Lambda:** `lambda.Invoke` with a test payload, assert on `StatusCode == 200` and `FunctionError == nil`
  - **SQS:** `sqs.SendMessage` followed by `sqs.ReceiveMessage`, assert the message body matches
  - **S3:** `s3.PutObject` followed by `s3.GetObject`, assert content matches
  - **SNS:** `sns.Publish` a test message
  - **DynamoDB:** `dynamodb.PutItem` followed by `dynamodb.GetItem`
  - If no obvious write operation exists for the resource type, document why in a code comment
- **`post_deploy_functional_readonly`**: Must contain ONLY read operations — no invocations, no writes, no mutations. This test runs in environments where destructive operations are not permitted. It MUST still verify security-relevant configuration (encryption, access policies) via SDK `Get`/`Describe` calls.

**The two test files must NOT be identical or near-identical (most common test failure across ALL 16 reference-lambda trials).** If the only difference is the function name, that is a High severity issue.

> **WARNING — The three most common readonly test mistakes (found in 6/16 trials):**
>
> **Mistake 1:** Using `lib.RunSetupTestTeardown` in the readonly test:
> ```go
> // WRONG — this deploys and destroys infrastructure, defeating the purpose
> lib.RunSetupTestTeardown(t, *ctx, testimpl.TestComposableCompleteReadOnly)
> ```
>
> **Mistake 2:** Calling `TestComposableComplete` (the mutating function) from the readonly entry point:
> ```go
> // WRONG — TestComposableComplete includes write operations like lambda.Invoke
> lib.RunNonDestructiveTest(t, *ctx, testimpl.TestComposableComplete)
> ```
>
> **Mistake 3:** Copy-pasting the functional test file and only changing the function name:
> ```go
> // WRONG — identical to post_deploy_functional except the function name
> func TestLambdaReferenceArchitectureReadOnly(t *testing.T) {
>     // ... same setup ...
>     lib.RunSetupTestTeardown(t, *ctx, testimpl.TestComposableComplete) // ← still wrong runner AND function
> }
> ```
>
> **CORRECT readonly test — both runner AND function must differ:**
> ```go
> func TestLambdaReferenceArchitectureReadOnly(t *testing.T) {
>     // ... same setup ...
>     lib.RunNonDestructiveTest(t, *ctx, testimpl.TestComposableCompleteReadOnly)
> }
> ```

> **Mandatory differences between the two entry points:**
>
> | Aspect | `post_deploy_functional` | `post_deploy_functional_readonly` |
> |--------|--------------------------|-----------------------------------|
> | Function called | `TestComposableComplete` | `TestComposableCompleteReadOnly` |
> | Runner | `lib.RunSetupTestTeardown` | `lib.RunNonDestructiveTest` |
> | Write operations | YES (invoke, send message, etc.) | NO — read-only SDK calls only |
>
> **Using `lib.RunSetupTestTeardown` in the readonly test is a High severity issue** — it would deploy and destroy infrastructure, defeating the purpose of a read-only test.

Create a separate read-only test function (e.g., `TestComposableCompleteReadOnly`) that verifies resource existence and configuration via SDK `Get`/`Describe` calls but does NOT invoke or mutate any resources. The destructive test should call the read-only function first, then additionally perform write/mutating operations.

### AWS Lambda Reference Architecture — Complete Test Example

This is a complete, working example of how to test an AWS Lambda reference architecture using the `lcaf-component-terratest` framework with full SDK verification. **Use this as your template for AWS reference architectures.**

**`tests/testimpl/test_impl.go`** — SDK verification for all composed resources:
```go
package testimpl

import (
	"context"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatchlogs"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/kms"
	"github.com/aws/aws-sdk-go-v2/service/lambda"
	lambdaTypes "github.com/aws/aws-sdk-go-v2/service/lambda/types"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	sqsTypes "github.com/aws/aws-sdk-go-v2/service/sqs/types"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/launchbynttdata/lcaf-component-terratest/types"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestComposableComplete runs all read-only SDK checks PLUS mutating operations.
// Used by post_deploy_functional.
func TestComposableComplete(t *testing.T, ctx types.TestContext) {
	// Run all read-only verification first
	TestComposableCompleteReadOnly(t, ctx)

	// --- Mutating / destructive tests below ---

	t.Run("TestLambdaInvocation", func(t *testing.T) {
		lambdaClient := GetAWSLambdaClient(t)
		functionName := terraform.Output(t, ctx.TerratestTerraformOptions(), "lambda_function_name")

		result, err := lambdaClient.Invoke(context.TODO(), &lambda.InvokeInput{
			FunctionName: aws.String(functionName),
			Payload:      []byte(`{"test": true}`),
		})
		require.NoError(t, err, "Lambda invocation should succeed")
		assert.Equal(t, int32(200), result.StatusCode, "Lambda should return 200")
		assert.Nil(t, result.FunctionError, "Lambda should not return an error")
	})
}

// TestComposableCompleteReadOnly verifies all resources via SDK Get/Describe calls ONLY.
// No invocations, no writes, no mutations. Used by post_deploy_functional_readonly.
func TestComposableCompleteReadOnly(t *testing.T, ctx types.TestContext) {
	functionName := terraform.Output(t, ctx.TerratestTerraformOptions(), "lambda_function_name")
	functionArn := terraform.Output(t, ctx.TerratestTerraformOptions(), "lambda_function_arn")
	roleName := terraform.Output(t, ctx.TerratestTerraformOptions(), "lambda_role_name")
	roleArn := terraform.Output(t, ctx.TerratestTerraformOptions(), "lambda_role_arn")

	t.Run("TestLambdaFunctionExists", func(t *testing.T) {
		lambdaClient := GetAWSLambdaClient(t)
		result, err := lambdaClient.GetFunction(context.TODO(), &lambda.GetFunctionInput{
			FunctionName: aws.String(functionName),
		})
		require.NoError(t, err, "GetFunction should succeed")
		assert.Equal(t, functionArn, *result.Configuration.FunctionArn)
		assert.Equal(t, functionName, *result.Configuration.FunctionName)
		assert.Equal(t, lambdaTypes.StateActive, result.Configuration.State)
	})

	t.Run("TestCloudWatchLogGroupExists", func(t *testing.T) {
		cwClient := GetAWSCloudWatchLogsClient(t)
		logGroupName := "/aws/lambda/" + functionName

		result, err := cwClient.DescribeLogGroups(context.TODO(), &cloudwatchlogs.DescribeLogGroupsInput{
			LogGroupNamePrefix: aws.String(logGroupName),
		})
		require.NoError(t, err, "DescribeLogGroups should succeed")
		require.NotEmpty(t, result.LogGroups, "CloudWatch Log Group should exist for Lambda function")
		assert.Equal(t, logGroupName, *result.LogGroups[0].LogGroupName)
	})

	t.Run("TestIAMRoleExists", func(t *testing.T) {
		iamClient := GetAWSIAMClient(t)

		roleResult, err := iamClient.GetRole(context.TODO(), &iam.GetRoleInput{
			RoleName: aws.String(roleName),
		})
		require.NoError(t, err, "GetRole should succeed")
		assert.Equal(t, roleArn, *roleResult.Role.Arn)

		// Verify at least one policy is attached
		policies, err := iamClient.ListAttachedRolePolicies(context.TODO(), &iam.ListAttachedRolePoliciesInput{
			RoleName: aws.String(roleName),
		})
		require.NoError(t, err, "ListAttachedRolePolicies should succeed")
		assert.NotEmpty(t, policies.AttachedPolicies, "IAM role should have at least one attached policy")
	})

	// Optional resource: DLQ — skip if not enabled in example
	t.Run("TestDLQExists", func(t *testing.T) {
		dlqUrl := terraform.Output(t, ctx.TerratestTerraformOptions(), "dlq_url")
		if dlqUrl == "" {
			t.Skip("DLQ not enabled in this example")
		}
		sqsClient := GetAWSSQSClient(t)

		result, err := sqsClient.GetQueueAttributes(context.TODO(), &sqs.GetQueueAttributesInput{
			QueueUrl:       aws.String(dlqUrl),
			AttributeNames: []sqsTypes.QueueAttributeName{sqsTypes.QueueAttributeNameAll},
		})
		require.NoError(t, err, "GetQueueAttributes should succeed for DLQ")
		assert.NotEmpty(t, result.Attributes, "DLQ should have attributes")
	})

	// Optional resource: KMS key — skip if not enabled in example
	t.Run("TestKMSKeyExists", func(t *testing.T) {
		kmsKeyId := terraform.Output(t, ctx.TerratestTerraformOptions(), "kms_key_id")
		if kmsKeyId == "" {
			t.Skip("KMS key not enabled in this example")
		}
		kmsClient := GetAWSKMSClient(t)

		result, err := kmsClient.DescribeKey(context.TODO(), &kms.DescribeKeyInput{
			KeyId: aws.String(kmsKeyId),
		})
		require.NoError(t, err, "DescribeKey should succeed")
		assert.True(t, result.KeyMetadata.Enabled, "KMS key should be enabled")
	})
}

// --- AWS SDK Helper Functions ---

func GetAWSConfig(t *testing.T) aws.Config {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	require.NoError(t, err, "unable to load AWS SDK config")
	return cfg
}

func GetAWSLambdaClient(t *testing.T) *lambda.Client {
	return lambda.NewFromConfig(GetAWSConfig(t))
}

func GetAWSCloudWatchLogsClient(t *testing.T) *cloudwatchlogs.Client {
	return cloudwatchlogs.NewFromConfig(GetAWSConfig(t))
}

func GetAWSIAMClient(t *testing.T) *iam.Client {
	return iam.NewFromConfig(GetAWSConfig(t))
}

func GetAWSSQSClient(t *testing.T) *sqs.Client {
	return sqs.NewFromConfig(GetAWSConfig(t))
}

func GetAWSKMSClient(t *testing.T) *kms.Client {
	return kms.NewFromConfig(GetAWSConfig(t))
}
```

**`post_deploy_functional/main_test.go`** — calls `TestComposableComplete` (includes mutating tests):
```go
package test

import (
	"testing"

	"github.com/launchbynttdata/lcaf-component-terratest/lib"
	"github.com/launchbynttdata/lcaf-component-terratest/types"
	"github.com/launchbynttdata/YOUR_MODULE_NAME/tests/testimpl"
)

const (
	testConfigsExamplesFolderDefault = "../../examples"
	infraTFVarFileNameDefault        = "test.tfvars"
)

func TestLambdaReferenceArchitecture(t *testing.T) {
	ctx := types.CreateTestContextBuilder().
		SetTestConfig(&testimpl.ThisTFModuleConfig{}).
		SetTestConfigFolderName(testConfigsExamplesFolderDefault).
		SetTestConfigFileName(infraTFVarFileNameDefault).
		Build()

	lib.RunSetupTestTeardown(t, *ctx, testimpl.TestComposableComplete)
}
```

**`post_deploy_functional_readonly/main_test.go`** — calls `TestComposableCompleteReadOnly` (read-only only):
```go
package test

import (
	"testing"

	"github.com/launchbynttdata/lcaf-component-terratest/lib"
	"github.com/launchbynttdata/lcaf-component-terratest/types"
	"github.com/launchbynttdata/YOUR_MODULE_NAME/tests/testimpl"
)

const (
	testConfigsExamplesFolderDefault = "../../examples"
	infraTFVarFileNameDefault        = "test.tfvars"
)

func TestLambdaReferenceArchitectureReadOnly(t *testing.T) {
	ctx := types.CreateTestContextBuilder().
		SetTestConfig(&testimpl.ThisTFModuleConfig{}).
		SetTestConfigFolderName(testConfigsExamplesFolderDefault).
		SetTestConfigFileName(infraTFVarFileNameDefault).
		Build()

	lib.RunNonDestructiveTest(t, *ctx, testimpl.TestComposableCompleteReadOnly)
}
```

> **CRITICAL:** Note how `post_deploy_functional` and `post_deploy_functional_readonly` call **different** functions AND **different runners**. The readonly entry point uses `lib.RunNonDestructiveTest` (NOT `lib.RunSetupTestTeardown`) and calls `TestComposableCompleteReadOnly` (NOT `TestComposableComplete`). Never make these two files identical.

### Azure PostgreSQL Reference Architecture — Complete Test Example

This is a complete, working example of how to test an Azure PostgreSQL reference architecture using the `lcaf-component-terratest` framework with full Azure SDK verification. **Use this as your template for Azure reference architectures.**

**`tests/testimpl/test_impl.go`** — SDK verification for all composed resources:
```go
package testimpl

import (
	"context"
	"os"
	"testing"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore"
	"github.com/Azure/azure-sdk-for-go/sdk/azcore/arm"
	"github.com/Azure/azure-sdk-for-go/sdk/azcore/cloud"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/network/armnetwork"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/postgresql/armpostgresqlflexibleservers"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/privatedns/armprivatedns"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/resources/armresources"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/launchbynttdata/lcaf-component-terratest/types"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestComposableComplete runs all read-only SDK checks PLUS mutating operations.
// Used by post_deploy_functional.
func TestComposableComplete(t *testing.T, ctx types.TestContext) {
	// Run all read-only verification first
	TestComposableCompleteReadOnly(t, ctx)

	// --- Mutating / destructive tests below ---
	// Add mutating tests here if applicable (e.g., writing a row to PostgreSQL,
	// testing failover, triggering a diagnostic alert). For many Azure reference
	// architectures the read-only checks are sufficient.
}

// TestComposableCompleteReadOnly verifies all resources via Azure SDK Get calls ONLY.
// No writes, no mutations. Used by post_deploy_functional_readonly.
func TestComposableCompleteReadOnly(t *testing.T, ctx types.TestContext) {
	subscriptionID := os.Getenv("ARM_SUBSCRIPTION_ID")
	require.NotEmpty(t, subscriptionID, "ARM_SUBSCRIPTION_ID must be set")

	resourceGroupName := terraform.Output(t, ctx.TerratestTerraformOptions(), "resource_group_name")
	serverName := terraform.Output(t, ctx.TerratestTerraformOptions(), "name")

	t.Run("TestResourceGroupExists", func(t *testing.T) {
		rgClient := GetAzureResourceGroupsClient(t, subscriptionID)
		rg, err := rgClient.Get(context.TODO(), resourceGroupName, nil)
		require.NoError(t, err, "Get ResourceGroup should succeed")
		assert.Equal(t, resourceGroupName, *rg.Name)
	})

	t.Run("TestPostgreSQLServerExists", func(t *testing.T) {
		pgClient := GetAzurePostgreSQLServersClient(t, subscriptionID)
		server, err := pgClient.Get(context.TODO(), resourceGroupName, serverName, nil)
		require.NoError(t, err, "Get PostgreSQL server should succeed")
		assert.Equal(t, serverName, *server.Name)
		assert.Equal(t, armpostgresqlflexibleservers.ServerVersion("16"), *server.Properties.Version)
		assert.Equal(t, "B_Standard_B1ms", server.SKU.Name)
	})

	// Optional resource: VNet/Subnet — skip if not enabled
	t.Run("TestSubnetDelegation", func(t *testing.T) {
		subnetID := terraform.Output(t, ctx.TerratestTerraformOptions(), "delegated_subnet_id")
		if subnetID == "" {
			t.Skip("VNet integration not enabled in this example")
		}
		// Parse resource group, vnet, and subnet names from the subnet ID
		vnetName := terraform.Output(t, ctx.TerratestTerraformOptions(), "vnet_name")
		subnetName := terraform.Output(t, ctx.TerratestTerraformOptions(), "subnet_name")

		subnetClient := GetAzureSubnetsClient(t, subscriptionID)
		subnet, err := subnetClient.Get(context.TODO(), resourceGroupName, vnetName, subnetName, nil)
		require.NoError(t, err, "Get Subnet should succeed")
		require.NotEmpty(t, subnet.Properties.Delegations, "Subnet should have delegations")
		assert.Contains(t, *subnet.Properties.Delegations[0].Properties.ServiceName, "Microsoft.DBforPostgreSQL/flexibleServers")
	})

	// Optional resource: Private DNS Zone — skip if not enabled
	t.Run("TestPrivateDNSZoneExists", func(t *testing.T) {
		dnsZoneName := terraform.Output(t, ctx.TerratestTerraformOptions(), "private_dns_zone_name")
		if dnsZoneName == "" {
			t.Skip("Private DNS zone not enabled in this example")
		}
		dnsClient := GetAzurePrivateDNSZonesClient(t, subscriptionID)
		zone, err := dnsClient.Get(context.TODO(), resourceGroupName, dnsZoneName, nil)
		require.NoError(t, err, "Get Private DNS Zone should succeed")
		assert.Equal(t, dnsZoneName, *zone.Name)
	})

	// Optional resource: Diagnostic Settings — check via output
	t.Run("TestDiagnosticSettingsConfigured", func(t *testing.T) {
		diagID := terraform.Output(t, ctx.TerratestTerraformOptions(), "diagnostic_setting_id")
		if diagID == "" {
			t.Skip("Diagnostic settings not enabled in this example")
		}
		assert.NotEmpty(t, diagID, "Diagnostic setting ID should not be empty")
	})

	// Optional resource: Firewall Rules — skip if not enabled
	t.Run("TestFirewallRulesExist", func(t *testing.T) {
		firewallRuleCount := terraform.Output(t, ctx.TerratestTerraformOptions(), "firewall_rule_count")
		if firewallRuleCount == "" || firewallRuleCount == "0" {
			t.Skip("Firewall rules not enabled in this example")
		}
		fwClient := GetAzureFirewallRulesClient(t, subscriptionID)
		pager := fwClient.NewListByServerPager(resourceGroupName, serverName, nil)
		var ruleCount int
		for pager.More() {
			page, err := pager.NextPage(context.TODO())
			require.NoError(t, err, "ListByServer should succeed")
			ruleCount += len(page.Value)
		}
		assert.Greater(t, ruleCount, 0, "At least one firewall rule should exist")
	})
}

// --- Azure SDK Helper Functions ---

func GetAzureCredential(t *testing.T) *azidentity.DefaultAzureCredential {
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	require.NoError(t, err, "unable to create Azure credential")
	return cred
}

func GetAzureClientOptions() *arm.ClientOptions {
	return &arm.ClientOptions{
		ClientOptions: azcore.ClientOptions{
			Cloud: cloud.AzurePublic,
		},
	}
}

func GetAzureResourceGroupsClient(t *testing.T, subscriptionID string) *armresources.ResourceGroupsClient {
	client, err := armresources.NewResourceGroupsClient(subscriptionID, GetAzureCredential(t), GetAzureClientOptions())
	require.NoError(t, err, "unable to create ResourceGroups client")
	return client
}

func GetAzurePostgreSQLServersClient(t *testing.T, subscriptionID string) *armpostgresqlflexibleservers.ServersClient {
	client, err := armpostgresqlflexibleservers.NewServersClient(subscriptionID, GetAzureCredential(t), GetAzureClientOptions())
	require.NoError(t, err, "unable to create PostgreSQL Servers client")
	return client
}

func GetAzureSubnetsClient(t *testing.T, subscriptionID string) *armnetwork.SubnetsClient {
	client, err := armnetwork.NewSubnetsClient(subscriptionID, GetAzureCredential(t), GetAzureClientOptions())
	require.NoError(t, err, "unable to create Subnets client")
	return client
}

func GetAzurePrivateDNSZonesClient(t *testing.T, subscriptionID string) *armprivatedns.PrivateZonesClient {
	client, err := armprivatedns.NewPrivateZonesClient(subscriptionID, GetAzureCredential(t), GetAzureClientOptions())
	require.NoError(t, err, "unable to create Private DNS Zones client")
	return client
}

func GetAzureFirewallRulesClient(t *testing.T, subscriptionID string) *armpostgresqlflexibleservers.FirewallRulesClient {
	client, err := armpostgresqlflexibleservers.NewFirewallRulesClient(subscriptionID, GetAzureCredential(t), GetAzureClientOptions())
	require.NoError(t, err, "unable to create Firewall Rules client")
	return client
}
```

**`tests/testimpl/types.go`** — standard test config struct:
```go
package testimpl

import "github.com/launchbynttdata/lcaf-component-terratest/types"

type ThisTFModuleConfig struct {
	types.GenericTFModuleConfig
}
```

**`post_deploy_functional/main_test.go`** — calls `TestComposableComplete` (includes mutating tests):
```go
package test

import (
	"testing"

	"github.com/launchbynttdata/lcaf-component-terratest/lib"
	"github.com/launchbynttdata/lcaf-component-terratest/types"
	"github.com/launchbynttdata/YOUR_MODULE_NAME/tests/testimpl"
)

const (
	testConfigsExamplesFolderDefault = "../../examples"
	infraTFVarFileNameDefault        = "test.tfvars"
)

func TestPostgreSQLReferenceArchitecture(t *testing.T) {
	ctx := types.CreateTestContextBuilder().
		SetTestConfig(&testimpl.ThisTFModuleConfig{}).
		SetTestConfigFolderName(testConfigsExamplesFolderDefault).
		SetTestConfigFileName(infraTFVarFileNameDefault).
		Build()

	lib.RunSetupTestTeardown(t, *ctx, testimpl.TestComposableComplete)
}
```

**`post_deploy_functional_readonly/main_test.go`** — calls `TestComposableCompleteReadOnly` (read-only only):
```go
package test

import (
	"testing"

	"github.com/launchbynttdata/lcaf-component-terratest/lib"
	"github.com/launchbynttdata/lcaf-component-terratest/types"
	"github.com/launchbynttdata/YOUR_MODULE_NAME/tests/testimpl"
)

const (
	testConfigsExamplesFolderDefault = "../../examples"
	infraTFVarFileNameDefault        = "test.tfvars"
)

func TestPostgreSQLReferenceArchitectureReadOnly(t *testing.T) {
	ctx := types.CreateTestContextBuilder().
		SetTestConfig(&testimpl.ThisTFModuleConfig{}).
		SetTestConfigFolderName(testConfigsExamplesFolderDefault).
		SetTestConfigFileName(infraTFVarFileNameDefault).
		Build()

	lib.RunNonDestructiveTest(t, *ctx, testimpl.TestComposableCompleteReadOnly)
}
```

> **CRITICAL:** The `post_deploy_functional` entry point uses `lib.RunSetupTestTeardown` (deploys → tests → destroys) while `post_deploy_functional_readonly` uses `lib.RunNonDestructiveTest` (tests against already-deployed infrastructure, no deploy/destroy). Never use `RunSetupTestTeardown` in the readonly entry point — it would destroy production-like infrastructure.

**Azure pattern (cross-reference):** See the complete [Azure PostgreSQL Reference Architecture test example](#azure-postgresql-reference-architecture--complete-test-example) above for a fully working implementation using the `lcaf-component-terratest` framework with SDK verification for Resource Groups, PostgreSQL Flexible Server, VNet/Subnet, Private DNS, Diagnostics, and Firewall Rules.

**AWS pattern:** See the complete [AWS Lambda Reference Architecture test example](#aws-lambda-reference-architecture--complete-test-example) above for a fully working implementation using the `lcaf-component-terratest` framework with SDK verification for Lambda, CloudWatch, IAM, SQS, and KMS.

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

func TestArchitectureComplete(t *testing.T) {
    t.Parallel()

    projectID := gcp.GetGoogleProjectIDFromEnvVar(t)

    terraformOptions := &terraform.Options{
        TerraformDir: "../examples/complete",
    }

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    // Verify Terraform outputs
    name := terraform.Output(t, terraformOptions, "name")
    assert.NotEmpty(t, name)

    // Verify primary resource via GCP API
    // Use terratest gcp helpers where available (github.com/gruntwork-io/terratest/modules/gcp)
    // Fall back to GCP client libraries for resources not covered by terratest helpers
    // (google.golang.org/api/...)

    // Example: verify a GKE cluster exists and is correctly configured
    // cluster := gcp.GetGkeCluster(t, projectID, "us-east1", name)
    // require.NotNil(t, cluster)
    // assert.Equal(t, "RUNNING", cluster.Status)
    // assert.True(t, cluster.AddonsConfig.HttpLoadBalancing.Disabled == false)

    // Example: verify a storage bucket
    // bucket := gcp.GetStorageBucketE(t, projectID, name)
    // require.NotNil(t, bucket)
    // assert.Equal(t, "US-EAST1", bucket.Location)
    // assert.Equal(t, "STANDARD", bucket.StorageClass)
}
```

**Key patterns:**
- Use `t.Parallel()` for concurrent testing
- Defer cleanup with `terraform.Destroy`
- **Always verify both Terraform outputs and cloud provider API state**
- Use terratest provider helpers (`modules/azure`, `modules/aws`, `modules/gcp`) as the first choice
- Use the provider SDK directly for resources not covered by terratest helpers
- Test the primary resource's existence **and** specific configuration values (SKU, version, runtime, encryption, access settings)
- Test each optional feature that is enabled in the `examples/complete` example
- Read credentials/region from environment variables; fail clearly if required env vars are missing
- Assert on specific values, not just non-emptiness — this catches misconfiguration that Terraform would still report as a successful output

## Example Usage in examples/complete/

> **CRITICAL — Do not redundantly compose sub-modules in examples (most common High-severity issue in trials).** The `examples/complete/` directory demonstrates how an end user calls the reference architecture module. Since the reference architecture already composes `resource_names` (and other primitives) internally, the example **MUST NOT** instantiate a separate `module "resource_names"` block, `data "aws_region" "current" {}`, or any other data source/module that the root module already handles internally. Doing so creates dead code that confuses users.
>
> **BAD — will be flagged as High severity:**
> ```hcl
> # examples/complete/main.tf — WRONG
> data "aws_region" "current" {}          # ← dead code
> module "resource_names" { ... }          # ← dead code, root module already does this
> module "lambda_reference" { source = "../.." }
> ```
>
> **GOOD — example only calls the reference module:**
> ```hcl
> # examples/complete/main.tf — CORRECT
> module "lambda_reference" {
>   source = "../.."
>   # Pass variables directly — no sub-module composition
>   logical_product_family  = var.logical_product_family
>   # ...
> }
> ```
>
> Also do NOT add outputs in the example that reference sub-modules the example should not have (e.g., `module.resource_names`). If removed from `main.tf`, remove from `outputs.tf` too.

**Azure example:**
```hcl
module "postgresql_reference" {
  source = "../.."

  # Naming context
  logical_product_family  = "launch"
  logical_product_service = "database"
  class_env               = "dev"
  instance_env            = 0
  instance_resource       = 0
  location                = "eastus"

  # Core configuration
  sku_name         = "B_Standard_B1ms"
  postgres_version = "16"
  storage_mb       = 32768

  # Authentication
  administrator_login    = "postgresadmin"
  administrator_password = random_password.postgres.result

  # Networking
  delegated_subnet_id = module.subnet.id
  private_dns_zone_id = module.private_dns_zone.id

  # Private endpoint
  create_private_endpoint       = true
  private_endpoint_subnet_id    = module.pe_subnet.id
  private_endpoint_dns_zone_ids = [module.private_dns_zone.id]

  # Monitoring
  action_group = {
    name       = "postgresql-action-group"
    short_name = "pgsql-ag"
    email_receivers = [{
      name          = "ops-team"
      email_address = "ops@example.com"
    }]
  }

  tags = var.tags
}
```

**AWS example:**
```hcl
module "lambda_reference" {
  source = "../.."

  # Naming context
  logical_product_family  = "launch"
  logical_product_service = "lambda"
  class_env               = "demo"
  instance_env            = 0
  instance_resource       = 0

  # Core Lambda configuration
  runtime      = "python3.9"
  handler      = "index.lambda_handler"
  memory_size  = 256
  timeout      = 10

  # Source code
  create_package = true
  source_path    = "${path.module}/lambda_code"

  # IAM permissions
  attach_policy_statements = true
  policy_statements = {
    s3_read = {
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = ["arn:aws:s3:::my-bucket/*"]
    }
  }

  # CloudWatch Logs
  attach_cloudwatch_logs_policy     = true
  cloudwatch_logs_retention_in_days = 7

  # Function URL
  create_lambda_function_url = true
  authorization_type         = "NONE"

  # Enable creation
  create = true

  tags = var.tags
}
```

> **AWS Lambda examples — you MUST create the `lambda_code/` directory** with an actual handler file (e.g., `examples/complete/lambda_code/index.py`). Without this, `source_path = "${path.module}/lambda_code"` will fail at apply time. Include a minimal working handler:
> ```python
> # examples/complete/lambda_code/index.py
> def lambda_handler(event, context):
>     return {"statusCode": 200, "body": "OK"}
> ```

> **Output naming convention:** Use a consistent prefix for all outputs related to the same resource. For AWS Lambda, prefix all Lambda-related outputs with `lambda_` (e.g., `lambda_function_name`, `lambda_function_arn`, `lambda_role_arn`, `lambda_role_name`). Do NOT mix prefixes like `function_name` and `lambda_function_arn` in the same module. Match the output names used in the community module where applicable (e.g., `terraform-aws-modules/lambda/aws` uses `lambda_function_name`, `lambda_role_arn`).

## Best Practices

### 1. Composition Over Configuration

**Good:** Compose multiple primitives
```hcl
module "postgresql_server" { ... }
module "postgresql_server_configuration" { ... }
module "private_endpoint" { ... }
module "monitor_action_group" { ... }
```

**Bad:** Creating resources directly
```hcl
resource "azurerm_postgresql_flexible_server" "this" { ... }
```

### 2. Make Features Optional

Use boolean flags or null checks:
```hcl
count = var.create_private_endpoint ? 1 : 0
count = var.ad_administrator != null ? 1 : 0
count = var.create ? 1 : 0  # AWS pattern
```

### 3. Provide Sensible Defaults

Reference architectures should have opinions:
```hcl
variable "public_network_access_enabled" {
  type    = bool
  default = false  # Security best practice
}

variable "backup_retention_days" {
  type    = number
  default = 7  # Minimum recommended
}
```

### 3a. Security-First Encryption Defaults

> **CRITICAL — Encryption requirements:**
>
> **The `examples/complete/` MUST use KMS-based encryption (not service-managed SSE).** Service-managed SSE (e.g., `sqs_managed_sse_enabled = true`) will be flagged by security/policy scanners (the skeleton ships `conftest` for policy checks) and by manual security review. Always prefer KMS:
>
> **AWS example — SQS with KMS:**
> ```hcl
> # In examples/complete/main.tf
> module "sqs_reference" {
>   source = "../.."
>   # ...
>   kms_master_key_id                 = aws_kms_key.example.id
>   sqs_managed_sse_enabled           = false  # Use KMS, not SSE
> }
>
> resource "aws_kms_key" "example" {
>   description = "KMS key for SQS encryption"
> }
> ```
>
> **The test MUST assert the specific KMS key ID via SDK, not just check that encryption is "enabled":**
> ```go
> // In test_impl.go
> kmsKeyId := terraform.Output(t, ctx.TerratestTerraformOptions(), "kms_key_id")
> require.NotEmpty(t, kmsKeyId, "KMS key ID output must not be empty")
>
> attrs, err := sqsClient.GetQueueAttributes(context.TODO(), &sqs.GetQueueAttributesInput{
>     QueueUrl:       aws.String(queueUrl),
>     AttributeNames: []sqsTypes.QueueAttributeName{sqsTypes.QueueAttributeNameAll},
> })
> require.NoError(t, err)
> assert.Equal(t, kmsKeyId, attrs.Attributes["KmsMasterKeyId"],
>     "Queue must be encrypted with the expected KMS key")
> ```
>
> **For mutual exclusion variables** (e.g., `sqs_managed_sse_enabled` vs `kms_master_key_id`), add a validation block:
> ```hcl
> variable "sqs_managed_sse_enabled" {
>   type    = bool
>   default = false
> }
>
> variable "kms_master_key_id" {
>   type    = string
>   default = null
> }
>
> # In locals or a validation block, ensure they are mutually exclusive
> ```

### 4. Use Community Modules Wisely (AWS)
```hcl
# Good: Use for complex, well-maintained resources
module "lambda" {
  source = "terraform-aws-modules/lambda/aws"
  # ...
}

# Consider: For simpler resources, use internal primitives
module "s3_bucket" {
  source = "terraform.registry.launch.nttdata.com/module_primitive/s3_bucket/aws"
  # ...
}
```

> **WARNING — CloudWatch Log Group duplication (AWS Lambda):** The `terraform-aws-modules/lambda/aws` community module creates a CloudWatch Log Group (`/aws/lambda/<function_name>`) internally by default. Do NOT also create a separate `aws_cloudwatch_log_group` resource or module for the same Lambda function — this causes a Terraform conflict ("resource already exists"). If you need to customize the log group (retention, KMS), use the community module's built-in variables (`cloudwatch_logs_retention_in_days`, `cloudwatch_logs_kms_key_arn`) instead of creating a duplicate.

### 5. Handle Provider Differences
```hcl
# Azure - explicit location
variable "location" {
  type = string
}

# AWS - from data source
data "aws_region" "current" {}
```

### 6. Version Constraints and Module Source Format

**Module source format — use registry paths, NOT `git::` URLs:**
```hcl
# CORRECT — internal primitives use the LCAF Terraform registry
source  = "terraform.registry.launch.nttdata.com/module_primitive/postgresql_server/azurerm"
version = "~> 1.1"

# CORRECT — community modules use the public Terraform registry
source  = "terraform-aws-modules/lambda/aws"
version = "~> 7.4"

# WRONG — do NOT use git:: URLs
# source = "git::https://github.com/terraform-aws-modules/terraform-aws-lambda.git?ref=v7.4.0"
```

Pin to minor versions of primitives:
```hcl
# Internal primitives
source  = "terraform.registry.launch.nttdata.com/module_primitive/postgresql_server/azurerm"
version = "~> 1.1"  # Allows 1.1.x, not 1.2.0

# Community modules
source  = "terraform-aws-modules/lambda/aws"
version = "~> 7.4"  # Allows 7.4.x, not 7.5.0
```

## Common Patterns

### Pattern: Optional Resource Group (Azure)
```hcl
variable "resource_group_name" {
  description = "Optional resource group name. If empty, a new one is created."
  type        = string
  default     = ""
}

module "resource_group" {
  source  = "..."
  count   = var.resource_group_name == "" ? 1 : 0
  # ...
}

locals {
  resource_group_name = var.resource_group_name != "" ? var.resource_group_name : module.resource_group[0].name
}
```

### Pattern: Resource Names Output Format (AWS)

The `resource_names` module outputs multiple name formats per resource. Select the right one per resource in locals:
```hcl
locals {
  # Standard: most Azure and AWS resources
  rg_name       = module.resource_names["resource_group"].standard

  # Minimal with random suffix: globally unique resources (S3, ECR, etc.)
  bucket_name   = module.resource_names["s3_bucket"].minimal_random_suffix

  # DNS-compliant: resources with DNS naming constraints (Lambda, ECS, etc.)
  lambda_name   = module.resource_names["lambda_function"].dns_compliant_minimal_random_suffix
}
```

### Pattern: Combining Lists/IDs
```hcl
# Azure - action groups
locals {
  all_action_group_ids = concat(
    var.action_group != null ? [module.monitor_action_group[0].id] : [],
    var.action_group_ids
  )
}

# AWS - IAM policies
locals {
  all_policy_arns = concat(
    var.attach_policy ? [var.policy] : [],
    var.attach_policies ? var.policies : []
  )
}
```

### Pattern: For_each Over Maps
```hcl
variable "server_configuration" {
  type    = map(string)
  default = {}
}

module "configuration" {
  source   = "..."
  for_each = var.server_configuration

  name  = each.key
  value = each.value
}
```

## Anti-Patterns to Avoid

**Don't:**
- Create resources directly (use primitives) — this includes IAM roles, policies, and policy attachments
- Hardcode resource names (use resource naming module)
- Make everything required (provide sensible defaults)
- Ignore monitoring and observability
- Skip private networking options (Azure)
- Skip VPC integration options (AWS)
- Omit IAM/AD integration
- Create monolithic architectures (keep focused)
- Duplicate primitive logic (compose, don't copy)
- Mix cloud provider patterns
- Use wildcard ARNs in IAM policies (e.g., `arn:aws:logs:*:*:*`) — always scope to specific region/account
- Create duplicate IAM permissions (e.g., both `attach_cloudwatch_logs_policy = true` AND a separate logs policy)
- Use community module versions that require a newer provider version than your `versions.tf` allows
- Compose sub-modules (e.g., `resource_names`, `data "aws_region"`) redundantly in `examples/complete/` when the root module already handles them
- Create a `providers.tf` file in `examples/complete/` (conflicts with auto-generated `provider.tf`)
- Leave template artifacts (an un-incorporated `TEMPLATED_README.md`, `examples/with_cake/`, TODO placeholders, template-derived test function names, the template `go.mod` path)
- Write tests that only check `terraform.Output` without making SDK API calls to verify real resource state
- Skip SDK verification for optional features (DLQ, KMS, CloudWatch, IAM) — every enabled feature needs its own SDK test
- Make `post_deploy_functional_readonly` identical to `post_deploy_functional` — they must differ
- Use `lib.RunSetupTestTeardown` in the readonly test — must use `lib.RunNonDestructiveTest`
- Use `ListRolePolicies` instead of `ListAttachedRolePolicies` for IAM verification
- Pass KMS key ID (UUID) where an ARN is expected (e.g., `cloudwatch_logs_kms_key_id`)
- Attach both `AWSLambdaBasicExecutionRole` AND an inline logging policy (duplicate permissions)
- Create a separate CloudWatch Log Group module/resource when using `terraform-aws-modules/lambda/aws` — that community module already creates `/aws/lambda/<function_name>` internally. Adding your own causes a duplicate resource conflict. Only create a separate log group if you are NOT using the community Lambda module.
- Use `git::` URLs for module sources (e.g., `git::https://github.com/...`) — use registry paths instead (`terraform-aws-modules/lambda/aws` for public, `terraform.registry.launch.nttdata.com/module_primitive/.../aws` for internal)
- Name feature flag variables with `enable_*` prefix — use `create_*` instead (e.g., `create_dlq`, `create_kms_key`, `create_lambda_function_url`) to match the Terraform ecosystem convention used by community modules

**Do:**
- Compose primitives
- Use generated names
- Make features optional with good defaults
- Include monitoring capabilities
- Support secure networking (private endpoints/VPC)
- Enable identity integration where applicable
- Keep architectures focused on one pattern
- Trust and use primitives as building blocks
- Follow provider-specific best practices
- Scope IAM policies using `data.aws_region.current.name` and `data.aws_caller_identity.current.account_id`
- Verify EVERY significant resource via cloud provider SDK in tests (not just Terraform outputs)
- Run `terraform init` IMMEDIATELY after adding community module sources to catch version incompatibilities early
- Run `make lint` and `make check` to verify everything passes before finalizing
- Use `lib.RunNonDestructiveTest` (not `RunSetupTestTeardown`) in readonly test entry points
- Use `.key_arn` (not `.key_id`) when passing KMS keys to CloudWatch Logs encryption parameters

## Creating a New Reference Architecture

When asked to create a new reference architecture:

1. **Identify the pattern and provider**
   - What problem does this solve?
   - Which cloud provider? (Azure, AWS, GCP)
   - What primitives are needed?
   - What additional capabilities?

2. **Plan the composition**
   - Core primitive(s) for main resources
   - Configuration primitives
   - Networking primitives (private endpoints for Azure, VPC for AWS)
   - Monitoring primitives (Azure Monitor, CloudWatch)
   - Identity primitives (AD for Azure, IAM for AWS)

3. **Design the interface**
   - What should users provide?
   - What should have sensible defaults?
   - What should be optional?
   - Provider-specific requirements?

4. **Implement**
   - Start with resource naming
   - Add resource group (Azure only)
   - Get region from data source (AWS)
   - Compose core primitive or community module
   - **Run `terraform init` immediately** after adding community module sources to verify version compatibility — do NOT wait until the end
   - Add optional features with conditionals
   - Add monitoring last
   - Do NOT create inline `resource` blocks — use primitive or community modules for everything including KMS aliases, IAM resources, etc.

5. **Verify skeleton transformation is complete** (mandatory gate before testing)
   - Search all `.tf` files for `random_string`, `random_pet`, `random_integer` resources from the skeleton — if any remain without a clear purpose in the new module, the transformation is incomplete
   - Search for `skeleton` or `lcaf-skeleton` in all files — none should remain
   - Confirm that `main.tf` contains the actual module composition (primitives/community modules), not skeleton placeholder resources
   - If ANY skeleton artifacts remain, stop and fix them before proceeding to testing

6. **Test**
   - Create complete example
   - Write Terratest
   - Verify all optional features can be enabled/disabled

7. **Document** (this step is mandatory and must be cross-referenced against code)
   - Explain the pattern being implemented
   - Document all optional features
   - Provide usage examples
   - Note provider-specific considerations
   - **Verification:** After writing documentation, diff the README usage snippet against the actual `examples/complete/main.tf` to confirm they match. Verify every input/output listed in the README exists in `variables.tf`/`outputs.tf`. Ensure the `<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->` section is populated (not empty). Remove all `TODO:` placeholders.

## Updates Needed for Older Modules

Based on comparing Azure and AWS modules, older modules may need:

1. **Terraform version update**
   - Old: `required_version = "~> 1.0"`
   - New: `required_version = "~> 1.5"`

2. **Resource naming module version**
   - Ensure using `version = "~> 2.0"`

3. **AWS-specific additions**
   - Use `locals` to select the appropriate output format per resource (`.standard`, `.minimal_random_suffix`, `.dns_compliant_*`)

4. **Consistent patterns**
   - Use `count` for optional features
   - Use `for_each` for multiple similar resources
   - Support pre-existing resources (resource groups, IAM roles)

## Template Cleanup Checklist

When transforming the template into a new module, complete ALL of these steps. **Every item is mandatory** — skipping any item will be flagged as a High or Medium severity issue in code review.

> **MANDATORY VERIFICATION GATE:** After completing all cleanup steps, run a self-check: search all `.tf` and `.go` files for `template`, `random_string` (from the template), `TEMPLATED_README`, and `launch-terraform-template`. If ANY match is found (except in `go.sum`), the transformation is incomplete. Fix before proceeding.

### Files to Remove or Transform
- [ ] **TEMPLATED_README.md** → Delete **only after** all its sections are incorporated into `README.md` (Module Development, Pre-Requisites, Pre-Commit hooks, Local Validation, Review & Merge Process, Automatic Updates). Do NOT leave a `TEMPLATED_README.md` file in the final module — run `git rm TEMPLATED_README.md` once its content has been incorporated. Retaining the Module Development boilerplate in `README.md` was missed in prior trials — verify it is present before deleting.
- [ ] **CI Terraform Check workflow** → The template ships a single unified `.github/workflows/pull-request-check-terraform.yml` that auto-detects the provider — there is **no per-provider workflow to delete**. (Older lcaf-era modules carried separate `pull-request-terraform-check-aws.yml`/`-azure.yml` files; the current skeleton does not. If you are migrating such a module, consolidate to the single unified workflow.)
- [ ] **`examples/with_cake/`** → Delete template example directory

### Files to Update

> **WARNING — These items are the most frequently missed in trials. Every single one is mandatory.**

- [ ] **`go.mod`** → Update the `launch-terraform-template` portion of the `github.com/launchbynttdata/launch-terraform-template` module path to your actual module name (e.g., `github.com/launchbynttdata/tf-aws-module_reference-lambda_function`). This is required for Go tests to compile correctly. **Failure to update this is a Medium severity issue.**
- [ ] **Test imports** → Update ALL Go import paths in `tests/post_deploy_functional/main_test.go`, `tests/post_deploy_functional_readonly/main_test.go`, `tests/testimpl/test_impl.go`, and any other test files to match the new `go.mod` module path. **Failure to update this is a Medium severity issue.**
- [ ] **Test function names** → Rename any template-derived outer test function names (e.g., `TestModule` / `TestSkeletonModule`) to a descriptive name like `TestLambdaReferenceArchitecture`. (The function passed to the runner must still start with `TestComposable` — see the readonly item below.) Also remove any template comments like `// Empty: there are no settings for the template module.` from `types.go`. **Failure to rename is a Medium severity issue.**
- [ ] **`post_deploy_functional_readonly/main_test.go`** → This file MUST call `lib.RunNonDestructiveTest` (NOT `lib.RunSetupTestTeardown`) and MUST pass `TestComposableCompleteReadOnly` (NOT `TestComposableComplete`). **Using the wrong runner or function is a High severity issue.**
- [ ] **README.md** → Replace ALL skeleton artifacts:
  - Replace Azure-specific references (ARM_CLIENT_ID, azure_env.sh, azurerm provider) with provider-appropriate content for AWS modules
  - Remove or replace any `TODO:` placeholders (e.g., `TODO: INSERT DOC LINK ABOUT HOOKS`) — **no `TODO:` text may remain in any committed file**
  - Ensure the `<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->` section is populated — run `terraform-docs markdown . > /dev/null` to generate content, or manually copy inputs/outputs from `variables.tf` and `outputs.tf`. **Do NOT leave this section empty.**
  - Verify that the "Modules" table in the README accurately lists only the modules actually used in `main.tf`
  - **Cross-reference the usage snippet against the actual `examples/complete/main.tf`** — every variable in the snippet must exist in `variables.tf`, every module call must match the real `main.tf`. Do NOT hallucinate variable names or module arguments that don't exist in the code.
- [ ] **`examples/complete/README.md`** → Must accurately describe the example:
  - The usage snippet must match the actual `main.tf` in the same directory
  - Do NOT list outputs that don't exist in `outputs.tf`
  - Do NOT reference variables that don't exist in `variables.tf`

## Cross-Reference

For primitive module patterns, see [primitive-module-creator.agent.md](./primitive-module-creator.agent.md)

These shared standards apply to both primitives and references:
- Commit message formats
- Pre-commit hooks
- Testing approaches
- Makefile targets
- Documentation standards

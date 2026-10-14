# Collection Module Standards

Collection modules compose released Launch modules into one independently deployable cloud service. A caller should get a working service from one module call, without assembling primitives by hand and without inheriting platform decisions the collection has no business making.

## Boundary Test

Classify every candidate resource before writing Terraform:

| Class | Meaning | How the collection models it |
| --- | --- | --- |
| Core | Required for the service to run at all | Always created |
| Optional dependency | Supports the service and is often shared or pre-existing | Created by default, or supplied by the caller |
| Platform choice | Part of a wider network, security, or regional design | Accepted as an input only; never created |

- A resource is a platform choice when it outlives the service, is shared across services, or encodes an organization-wide decision. Typical examples are virtual networks, general-purpose subnets, firewalls and route tables, private DNS architecture, ingress such as Application Gateway or Front Door, Key Vault, data services, and multiregion failover.
- Classify by ownership, not by resource type. A DNS zone, registry, or log workspace that serves only this service is core or an optional dependency; the same resource type shared across services or teams is a platform choice.
- If most candidates are platform choices, the work is a reference architecture. If there is only one resource type, it is a primitive.
- When two parts of a service have different lifecycles, such as a shared runtime environment and the applications deployed into it, make them separate collections. One collection must not force the other to be replaced or destroyed.

Worked example, Azure Container Apps:

- `tf-azurerm-module_collection-container_app_environment`: the Container Apps environment is core; the resource group and Log Analytics workspace are optional dependencies; the virtual network and infrastructure subnet are platform choices supplied by ID.
- `tf-azurerm-module_collection-container_apps`: the container apps are core; the user-assigned identity, the container registry, and the `AcrPull` role assignment are optional dependencies; the environment is supplied by ID.

## Required Structure

```text
examples/complete/
  main.tf
  variables.tf
  outputs.tf
  versions.tf
  test.tfvars
  README.md
examples/existing_dependencies/   # when the module has any optional dependency
tests/
  post_deploy_functional/
  post_deploy_functional_readonly/
  testimpl/
main.tf
variables.tf
outputs.tf
versions.tf
locals.tf
README.md
Makefile
go.mod
go.sum
```

## Composition

- The root module contains only `module` blocks, plus variables, locals, outputs, and `versions.tf`. Do not add `resource` blocks. Avoid data sources; a collection should receive identifiers from its inputs or composed modules.
- Compose Launch registry modules: `module_primitive` for resources, `module_library` for resource naming, and `module_collection` only when the nested collection is itself a dependency of this service.
- Never use `git::` sources. Some older collections do; do not copy them.
- If a required primitive does not exist or has no usable release, stop and report it. Do not inline the resource. A public registry module may be used only with the user's approval, and the README must say why.
- Read each composed module's interface at the release tag you will pin, not at `main`; an unreleased branch can differ from the release or be empty. Pin each module to `~> MAJOR.MINOR` of that tag.
- Do not add provider blocks and do not pass `providers` to composed modules unless the service genuinely spans provider configurations. Examples own provider configuration.

## Version Constraints

- Terraform evaluates every `required_version` in the module tree, so the root floor must be at least the highest `required_version` among the composed modules, and higher if the root's own language features need it.
- Every composed module declares its own provider constraint, and `terraform init` fails when the constraints share no version. Choose a root provider constraint that falls inside all of them, and set its floor no lower than the highest composed floor.
- Comment in `versions.tf` which composed module or feature sets each floor.
- Raising a composed module's pin can raise these floors. Recheck them whenever a pin changes.
- The version-floor guard loads the root and every example with the oldest Terraform version each admits, which also loads the composed modules. Compute the floors up front rather than iterating on CI failures.

## Optional Dependencies

Model each optional dependency as one object variable. Validation within a single variable works at any supported Terraform version; a validation that refers to a second variable needs Terraform 1.9 or later.

```hcl
variable "log_analytics_workspace" {
  description = "Create a Log Analytics workspace (default), or set `create = false` and supply `existing_id`. `name` overrides the generated name and is only valid when `create` is true."
  type = object({
    create      = optional(bool, true)
    name        = optional(string)
    existing_id = optional(string)
  })
  default  = {}
  nullable = false

  validation {
    condition = var.log_analytics_workspace.create ? var.log_analytics_workspace.existing_id == null : (
      var.log_analytics_workspace.existing_id == null ? false : var.log_analytics_workspace.name == null
    )
    error_message = "Set existing_id only when create is false, and name only when create is true."
  }
}
```

- Use the identifier the composed modules consume: `existing_name` for an Azure resource group, `existing_id` for most other resources.
- Call the module with `count = var.<dependency>.create ? 1 : 0` and resolve the value once in a local, for example `log_analytics_workspace_id = var.log_analytics_workspace.create ? module.log_analytics_workspace[0].id : var.log_analytics_workspace.existing_id`.
- Downstream module calls and outputs read only that local, never `module.<name>[0]` directly.
- Choose `count` or `for_each` for each module call once. Changing it later changes resource addresses and destroys and recreates the resources unless `moved` blocks are added.
- Write validations with conditional expressions. Before Terraform 1.12, `&&` and `||` evaluate both sides, so `existing_id != null && startswith(existing_id, "/subscriptions/")` still calls `startswith` on null. Write `existing_id == null ? false : startswith(existing_id, "/subscriptions/")`. Follow the input-validation rules in the shared Terraform module standards.
- An invalid input is still evaluated. Locals, module arguments, and `for_each` must not index a map with an optional key or pass null into a required argument, or the caller sees `Invalid function argument` or `Invalid index` instead of the validation message.

## Repeated Items

- Model repeated items, such as applications, containers, or records, as a map passed to `for_each`, keyed by static strings the caller supplies.
- Never derive keys from values known only after apply, such as resource IDs or generated names; Terraform rejects them at plan.
- Never key `for_each` on a sensitive value. Keep secrets in attributes that are not used as keys, or in a separate sensitive variable keyed by the same static keys.

## Naming

- Call the resource naming module (`terraform.registry.launch.nttdata.com/module_library/resource_name/launch`) in the root with `for_each = var.resource_names_map`, and pass its context variables (`logical_product_family`, `logical_product_service`, `class_env`, `instance_env`, `instance_resource`) through from root inputs. Follow the naming-module usage in the primitive standards.
- Every component the collection creates accepts an optional name override, as a `name` attribute of its object variable or a `<component>_name` variable. Resolve the name with a conditional, for example `var.log_analytics_workspace.name != null ? var.log_analytics_workspace.name : module.resource_names["law"].standard`.
- A component supplied by identifier takes no name; reject a name override on the existing path in validation.
- Pick the naming output that fits each service's naming rules, and document the choice. For example, an Azure Container Registry name allows only alphanumerics, so use a naming output without separators.
- Changing a name, including adding or removing an override, replaces the resource. Say so in the variable description.
- Do not compose the naming module again in examples.

## Variables

- Give every variable an explicit type and a useful description.
- Use high-level service variables rather than re-exposing every argument of every composed primitive. Pass through what a typical deployment of the service needs.
- Validate constrained values, mutually exclusive fields, and fields that must be provided together, following the input-validation rules in the shared Terraform module standards.
- When a description says a setting is valid only when another input is set, add a validation for that rule. If only the cloud API can check it, say so in the description.
- Do not add a validation that a composed primitive already enforces unless the collection needs a stricter rule.

## Ordering

- Prefer implicit ordering: pass one module's output into another module's input.
- Use `depends_on` only for ordering Terraform cannot see from arguments, such as a role assignment that must exist before the identity uses it. On Azure, a container app that pulls from a registry with a managed identity must depend on the `AcrPull` role assignment.
- `depends_on` on a module call defers that module's data sources to apply time, which can leave the second plan non-empty. When you add one, confirm the second plan of every example is empty.

## Outputs

- Prefix outputs by component, for example `resource_group_name`, `log_analytics_workspace_id`, and `environment_id`.
- Each output must return the same value whether its dependency was created or supplied.
- For repeated items, output maps keyed by the same static keys as the input map.
- If a composed module output is sensitive, mark the collection output `sensitive = true`; Terraform fails the plan otherwise.
- Expose identifiers, names, endpoints, and principal IDs a caller needs to wire the service into a platform. Avoid exposing raw module objects.

## Example Requirements

- `examples/complete` is the canonical secure example. It exercises the create path and passes through every root variable.
- `examples/existing_dependencies` creates its prerequisites from Launch primitives and passes them in on the existing path.
- Across the examples, at least one created component uses a name override and at least one uses a generated name.
- Use a random suffix for names that must be globally unique, so concurrent and repeated test runs do not collide.
- Do not commit `examples/*/provider.tf`; the build system generates it.
- Keep each example README synchronized with its Terraform files.

## Common Anti-Patterns

- Creating platform-choice resources such as virtual networks, firewalls, or Key Vault inside the collection.
- Writing a raw `resource` block because a primitive is missing.
- Pinning a composed module to a version whose interface was not read.
- A provider constraint that excludes a composed module's required provider range.
- Separate `create_*` and `existing_*` variables validated against each other at a Terraform floor below 1.9.
- A validation that fails with `Invalid function argument` or `Invalid index` because `&&`, `||`, or a map index evaluated a null.
- Outputs that reference `module.<name>[0]` and fail on the existing path.
- `for_each` keyed by generated names, resource IDs, or sensitive values.
- Turning off `IS_TERRAFORM_IDEMPOTENT_APPLY` to hide a non-empty second plan.

# Collection Module Guidance Release History

## 1.0

- Initial collection module guidance. A collection composes released Launch modules into one independently deployable service. A boundary test classifies resources as core, optional dependency, or platform choice; a missing primitive stops the work rather than being inlined.
- Each optional dependency is one object variable, because a validation that refers to a second variable needs Terraform 1.9 or later.
- The root generates names through the resource naming module. Created components accept a name override; components supplied by identifier take no name.
- Root floors must cover every composed module's `required_version`, and the provider constraint must lie inside every composed module's constraint.
- Tests assert the relationships between composed resources, deploy every example, and keep the idempotent-apply check enabled.

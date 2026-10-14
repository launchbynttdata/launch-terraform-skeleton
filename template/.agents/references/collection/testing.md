# Collection Module Testing

Collection tests must prove that the composed service works as one unit. Each composed primitive already tests its own resource; a collection test adds value by verifying how the resources are wired together and that both the create and existing paths behave.

## Test Scope

- Verify each composed resource through the cloud provider API where practical.
- Assert the relationships between composed resources. These checks are the main value of a collection test. For example, for Azure Container Apps:
  - the environment's Log Analytics customer ID matches the workspace the collection created or received;
  - each container app's environment ID matches the environment;
  - the registry configuration uses the expected managed identity;
  - that identity holds `AcrPull` on the registry scope.
- On the existing path, assert that outputs equal the identifiers the example supplied, which proves the collection did not create a duplicate.
- Assert generated names against the naming module outputs and overridden names against the override values.
- Check security settings the collection configures, such as identity, ingress visibility, private networking inputs, and logging destinations.

## Examples Under Test

- The functional suite must deploy every example as its own parallel subtest. Pass that example's directory, such as `../../examples/complete`, to `lib.RunSetupTestTeardown`. The Container Apps environment collection does this. Pointing `RunSetupTestTeardown` at the parent `examples` directory applies the subfolders one after another in the same test. `RunNonDestructiveTest` does not list subfolders, and it requires `.terraform` in the directory it is given, so the parent directory is not a shortcut for either runner.
- Do not set `IS_TERRAFORM_IDEMPOTENT_APPLY` to `false`. The second plan must be empty; a non-empty second plan is a defect to fix, not a flag to turn off. If a composed primitive forces drift, document the upstream issue in the pull request.

## Destructive and Readonly Tests

- Functional tests may create and exercise resources.
- Readonly tests must not create, update, invoke mutating operations, or alter state.
- The two suites must call different `tests/testimpl/` functions; do not copy the functional body into the readonly test.

## Readonly Test Runner

The readonly package (`tests/post_deploy_functional_readonly`) must:

- Call `lib.RunNonDestructiveTest`, not `lib.RunSetupTestTeardown`. The setup/teardown runner turns a readonly suite into a full apply, test, and destroy flow.
- Pass a `tests/testimpl` function whose name begins with `TestComposable`, such as `TestComposableCompleteReadOnly`. `lcaf-component-terratest` fails the test at runtime when the name does not meet this requirement.

CI excludes the readonly binary from its test command, so both requirements must be correct by construction.

## Assertions

- Prefer `assert.Equal`, `assert.Contains`, and provider state checks with known expected values from `test.tfvars`, module outputs, or API responses.
- Avoid `assert.NotEmpty` and `require.NotEmpty` when the expected value is knowable.
- Use `require` for API response fields that must exist before asserting nested values, including required security attributes.
- Compare cloud resource IDs the way the cloud does. Azure resource IDs are case-insensitive and the SDK can return segments in a different case from Terraform, so compare them with `strings.EqualFold`.

## Where Expected Values Come From

- Take the expected value from the example input, a prerequisite the example created, a name the test calculates, or the cloud API.
- Do not compare a collection output with another output that is only a copy of the first. That assertion passes even when the collection returns the wrong value.
- Do not decide what was expected by looking at the result. If the example creates a role assignment, require that key. Treat an empty result as success only when the example says it creates nothing.

## Negative Plans

- Put these plans in `tests/validation.tftest.hcl` and run `terraform test`. Use `mock_provider` with `command = plan`, as the primitive testing reference describes. Running them needs Terraform 1.7 or later. That does not raise the module floor, except when the floor is 1.6: Terraform 1.6 `validate` reads `tests/` and rejects `mock_provider`, so the version-floor check fails. Raise that floor to 1.7, or lower it to 1.5 when the module's features allow.
- For every validation that combines fields or reads another variable, plan one invalid input, including an omitted or null optional attribute.
- The plan must fail with that validation's `error_message`.
- The plan is not done when it also reports `Invalid function argument`, `Invalid index`, or a missing map key. Those mean an expression evaluated null before validation could explain the input.
- These plans do not need cloud credentials when the failure is in variable validation.
- Do not run `go test ./...`, `go test ./tests/post_deploy_functional`, or `go test ./tests/post_deploy_functional_readonly` to check a validation. Those commands apply real infrastructure. `go test ./tests/testimpl` is the local Go check.

## Go Quality

- Keep provider SDK clients and shared helpers in `tests/testimpl/`.
- Run the Go linter, `go get -u ./...`, `go mod tidy`, and `go build ./...` before cloud-backed runs.
- Keep example outputs and Go expected values synchronized; every output a test reads must exist in each example's `outputs.tf`.

## Test Review Checklist

- Relationship assertions cover every wiring between composed resources.
- Both the create and existing paths are deployed and asserted when the module has optional dependencies.
- Generated and overridden names are asserted against exact values.
- No configuration assertion uses `NotEmpty` when a specific value is available.
- Expected values come from inputs, prerequisites, calculated names, or the cloud API, not from a copy of the output under test.
- `tests/validation.tftest.hcl` has a negative plan for each cross-field validation. The plan fails with that validation's error message and does not also report an invalid function argument or index.
- Functional and readonly suites call different implementation functions, and the readonly suite uses `lib.RunNonDestructiveTest` with a `TestComposable*` function.
- `IS_TERRAFORM_IDEMPOTENT_APPLY` is not turned off.

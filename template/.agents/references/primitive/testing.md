# Primitive Module Testing

Primitive tests must prove the Terraform interface and the cloud resource behavior.

## Test Shape

- `post_deploy_functional` performs write or behavior-changing operations where the resource type supports them.
- `post_deploy_functional_readonly` performs read-only verification only.
- The two test packages must call different implementation functions.
- Shared setup and provider clients belong in `tests/testimpl/`.
- Use `t.Parallel()` where the test framework and provisioned resources support concurrent execution.
- Functional tests deploy and clean up the complete example. Readonly tests assume deployed infrastructure.

## Assertions

- Assert specific expected values from Terraform inputs, computed naming outputs, provider API responses, or known example configuration.
- Avoid `assert.NotEmpty` and `require.NotEmpty` when the value is knowable.
- Use `require` for attributes that must exist before deeper assertions.
- Verify security settings through the cloud provider API when the module configures encryption, policies, public access controls, identity, or networking.
- For a required security API attribute, use `require.True(t, ok, ...)` before assertions rather than an `if ok` branch that silently skips a missing setting.
- The limited valid uses of `NotEmpty` are checking a collection before indexing it or verifying a required environment variable. Configuration and API-returned values should have known expected values.

## Readonly Tests

Readonly tests must not create, update, invoke mutating operations, publish messages, write objects, or alter state.

## Readonly Test Runner

The readonly package (`tests/post_deploy_functional_readonly`) must:

- Call `lib.RunNonDestructiveTest`, not `lib.RunSetupTestTeardown`. The setup/teardown runner turns a readonly suite into a full apply, test, and destroy flow.
- Pass a `tests/testimpl` function whose name begins with `TestComposable`, such as `TestComposableCompleteReadOnly`. `lcaf-component-terratest` fails the test at runtime when the name does not meet this requirement.

CI excludes the readonly binary from its test command, so both requirements must be correct by construction.

## Functional Tests

Functional tests should exercise the resource behavior, not just Terraform outputs. Examples include writing and reading data, invoking a function, publishing a message, checking access policies, or using the relevant provider SDK operation.

## Go Quality

- Keep provider SDK helpers small and purpose-focused.
- Run `go mod tidy` after adding SDK dependencies.
- Before cloud-backed test runs, run the available Go linter, `go get -u ./...`, `go mod tidy`, and `go build ./...`; resolve failures before running the wider test flow.
- Build or run targeted Go tests before cloud-backed runs when possible.
- Keep example outputs and Go expected values synchronized.

## Provider State Verification

- Verify both Terraform outputs and real cloud state. Prefer Terratest provider helpers, then use the provider SDK where no helper covers the resource.
- Read cloud credentials and region or project context from the environment. Fail clearly when required configuration is missing.
- Compare API values to Terraform outputs or known example values, including security configuration such as encryption, TLS, access policy, private networking, or identity settings.

## Test Review Checklist

- No configuration assertion uses `assert.NotEmpty` or `require.NotEmpty` when a specific value is available.
- Functional and readonly entrypoints call different `tests/testimpl/` functions and are not copies of each other.
- The readonly entrypoint uses `lib.RunNonDestructiveTest` and a `TestComposable*` implementation function.
- Functional coverage includes a safe write or behavior operation when the resource supports one.
- Readonly coverage performs no writes, invocation, publishing, resource creation, updates, or state changes.
- Security-critical provider attributes are required and compared to expected values.
- Test-consumed Terraform outputs exist in `examples/complete/outputs.tf`.

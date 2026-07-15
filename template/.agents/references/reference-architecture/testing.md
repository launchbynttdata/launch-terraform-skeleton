# Reference Architecture Testing

Reference architecture tests must verify the composed infrastructure, not just Terraform outputs.

## Test Scope

- Validate each major composed resource through the provider API where practical.
- Verify optional features that the complete example enables.
- Check security controls such as encryption, private networking, IAM policies, logging, and monitoring.
- Verify resource naming outputs against expected naming formats.

## Destructive and Readonly Tests

- Destructive or functional tests may create and exercise resources.
- Readonly tests must not mutate state.
- Do not copy the destructive test body into the readonly test unchanged.

## Readonly Test Runner

The readonly package (`tests/post_deploy_functional_readonly`) must:

- Call `lib.RunNonDestructiveTest`, not `lib.RunSetupTestTeardown`. The setup/teardown runner turns a readonly suite into a full apply, test, and destroy flow.
- Pass a `tests/testimpl` function whose name begins with `TestComposable`, such as `TestComposableCompleteReadOnly`. `lcaf-component-terratest` fails the test at runtime when the name does not meet this requirement.

CI excludes the readonly binary from its test command, so both requirements must be correct by construction.

## Assertions

- Prefer `assert.Equal`, `assert.Contains`, and provider-specific state checks with known expected values.
- Avoid `assert.NotEmpty` where the expected value can be derived from `test.tfvars`, module outputs, or provider API response fields.
- Use `require` for required API response fields before asserting nested values.

## Provider-Specific Checks

- AWS Lambda architectures should verify Lambda configuration, runtime, handler, environment variables, CloudWatch log behavior, IAM role/policies, KMS encryption, and source package behavior where applicable.
- Azure PostgreSQL-style architectures should verify server configuration, networking, private DNS, firewall/public access settings, identity, and encryption where applicable.
- For other providers and services, derive equivalent checks from the provider SDK and service API.

## Go Quality

- Keep provider SDK clients and test helpers in reusable test implementation files.
- Run `go mod tidy` after adding or changing SDK dependencies.
- Build tests before cloud-backed runs when credentials are not available.

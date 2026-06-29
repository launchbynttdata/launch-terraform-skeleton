#!/usr/bin/env bash
#
# Validates the post-deploy readonly test wiring.
#
# CI never executes the readonly test binary -- `make test` excludes it
# (go list ./tests/... | grep -v post_deploy_functional_readonly) because
# post-deploy tests need live infrastructure. That leaves two defects
# invisible to CI until they hit a real test run:
#
#   1. Wrong runner: the readonly suite calls lib.RunSetupTestTeardown
#      (apply -> test -> destroy) instead of lib.RunNonDestructiveTest, so
#      the "read-only" suite is not actually read-only.
#   2. Wrong name: the testimpl function passed to RunNonDestructiveTest does
#      not start with TestComposable. lcaf-component-terratest's
#      demandAllTests2RunAreComposableOnes calls t.FailNow() in that case, so
#      the readonly suite hard-fails the moment it runs.
#
# This hook catches both statically, at commit time. See
# launchbynttdata/launch-workflows#92.

set -euo pipefail

READONLY_DIR="tests/post_deploy_functional_readonly"

# Nothing to validate if the module has no readonly suite.
if [ ! -d "$READONLY_DIR" ]; then
  exit 0
fi

# No Go files in the readonly suite -> nothing to validate.
if ! find "$READONLY_DIR" -name '*.go' -type f | grep -q .; then
  exit 0
fi

status=0

# 1. Wrong runner: the destructive runner must not appear in the readonly suite.
if grep -RnE --include='*.go' 'RunSetupTestTeardown' "$READONLY_DIR" >/dev/null 2>&1; then
  echo "ERROR: $READONLY_DIR uses lib.RunSetupTestTeardown." >&2
  echo "       The readonly suite must use lib.RunNonDestructiveTest -- it must not apply/destroy." >&2
  grep -RnE --include='*.go' 'RunSetupTestTeardown' "$READONLY_DIR" >&2 || true
  status=1
fi

# The readonly suite must call the non-destructive runner.
if ! grep -RnE --include='*.go' 'RunNonDestructiveTest' "$READONLY_DIR" >/dev/null 2>&1; then
  echo "ERROR: $READONLY_DIR does not call lib.RunNonDestructiveTest." >&2
  echo "       The readonly suite must drive its assertions through that runner." >&2
  status=1
fi

# 2. Wrong name: every function passed to RunNonDestructiveTest must start with
#    TestComposable (the lcaf runtime requirement that CI cannot see).
names="$(grep -RhoE --include='*.go' 'RunNonDestructiveTest\([^)]*\)' "$READONLY_DIR" \
          | sed -E 's/.*,[[:space:]]*([A-Za-z0-9_]+\.)?([A-Za-z0-9_]+)[[:space:]]*\)/\2/' || true)"
while IFS= read -r fn; do
  [ -n "$fn" ] || continue
  case "$fn" in
    TestComposable*) : ;;
    *)
      echo "ERROR: function '$fn' is passed to RunNonDestructiveTest but does not start with 'TestComposable'." >&2
      echo "       lcaf-component-terratest requires a TestComposable* function; CI does not catch this." >&2
      status=1
      ;;
  esac
done <<EOF
$names
EOF

if [ "$status" -ne 0 ]; then
  echo "" >&2
  echo "Readonly test validation failed. Background: launchbynttdata/launch-workflows#92" >&2
fi

exit "$status"

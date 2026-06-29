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
# This hook catches both statically, at commit time. To stay robust to source
# formatting it strips // line comments and flattens newlines before matching,
# so multiline calls and identifiers mentioned in comments are handled. See
# launchbynttdata/launch-workflows#92.

set -euo pipefail

# Fixed path -- matches the hook's files: filter in .pre-commit-config.yaml and
# the Makefile's GO_TEST_READONLY_DIRECTORY default. (The directory is not
# configurable here on purpose: the pre-commit files: filter can't read env
# vars, so honoring an override in the script alone would be misleading.)
readonly_dir="tests/post_deploy_functional_readonly"

status=0

# Nothing to validate if the module has no readonly suite.
[ -d "$readonly_dir" ] || exit 0

go_files="$(find "$readonly_dir" -name '*.go' -type f 2>/dev/null || true)"
[ -n "$go_files" ] || exit 0

# Comment-stripped, newline-flattened view of the readonly Go sources, so the
# checks below are robust to multiline calls and to identifiers appearing in
# comments. (Strips // line comments; block comments are not handled.)
flat="$(cat $go_files | sed -e 's://.*$::' | tr '\n' ' ')"

# 1. Wrong runner: the destructive runner must not be *called* in the readonly suite.
if printf '%s' "$flat" | grep -Eq 'RunSetupTestTeardown[[:space:]]*\('; then
  echo "ERROR: $readonly_dir calls lib.RunSetupTestTeardown." >&2
  echo "       The readonly suite must use lib.RunNonDestructiveTest -- it must not apply/destroy." >&2
  status=1
fi

# The readonly suite must call the non-destructive runner.
if ! printf '%s' "$flat" | grep -Eq 'RunNonDestructiveTest[[:space:]]*\('; then
  echo "ERROR: $readonly_dir does not call lib.RunNonDestructiveTest." >&2
  echo "       The readonly suite must drive its assertions through that runner." >&2
  status=1
fi

# 2. Wrong name: every function passed to RunNonDestructiveTest must start with
#    TestComposable (the lcaf runtime requirement that CI cannot see). The last
#    argument is the testimpl function; tolerate a gofmt trailing comma and an
#    optional package qualifier.
names="$(printf '%s' "$flat" \
  | grep -oE 'RunNonDestructiveTest[[:space:]]*\([^)]*\)' \
  | sed -E -e 's/^[^(]*\(//' -e 's/\)$//' -e 's/[[:space:]]//g' -e 's/,+$//' \
  | awk -F',' '{print $NF}' \
  | awk -F'.' '{print $NF}' || true)"

while IFS= read -r fn; do
  [ -n "$fn" ] || continue
  case "$fn" in
    TestComposable*) : ;;
    *)
      echo "ERROR: function '$fn' is passed to RunNonDestructiveTest in $readonly_dir but does not start with 'TestComposable'." >&2
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

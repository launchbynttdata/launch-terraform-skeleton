#!/usr/bin/env bash
#
# Self-test for template/.github/scripts/validate-readonly-test.sh.
# Runs the guard against generated fixtures and asserts its exit codes,
# including the regressions found in review (multiline calls and identifiers
# in comments). Wired into the skeleton's own pre-commit so the guard that
# protects every module is itself protected against regression.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
script="$repo_root/template/.github/scripts/validate-readonly-test.sh"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

fails=0

# make_case <name> <expected> ; reads the readonly main_test.go body on stdin.
#   expected = pass | fail | noreadonly
#   "noreadonly" creates no readonly dir at all (exercises the no-op path).
make_case() {
  name="$1"; expected="$2"
  dir="$workdir/$name"; mkdir -p "$dir"
  if [ "$expected" = "noreadonly" ]; then
    cat >/dev/null
    want=0
  else
    mkdir -p "$dir/tests/post_deploy_functional_readonly"
    cat > "$dir/tests/post_deploy_functional_readonly/main_test.go"
    want=0; [ "$expected" = "fail" ] && want=1
  fi
  set +e
  ( cd "$dir" && "$script" >/dev/null 2>&1 )
  actual=$?
  set -e
  if [ "$actual" -eq "$want" ]; then
    echo "ok   - $name (exit $actual)"
  else
    echo "FAIL - $name: expected exit $want, got $actual"
    fails=$((fails + 1))
  fi
}

make_case correct pass <<'GO'
package test
func TestModule(t *testing.T) {
	lib.RunNonDestructiveTest(t, *ctx, testimpl.TestComposableCompleteReadOnly)
}
GO

make_case wrong_name fail <<'GO'
package test
func TestModule(t *testing.T) {
	lib.RunNonDestructiveTest(t, *ctx, testimpl.TestManagedRedisReadOnly)
}
GO

make_case wrong_runner fail <<'GO'
package test
func TestModule(t *testing.T) {
	lib.RunSetupTestTeardown(t, *ctx, testimpl.TestVnet)
}
GO

# Regression: multiline call with gofmt trailing comma and a wrong name.
make_case multiline_wrong_name fail <<'GO'
package test
func TestModule(t *testing.T) {
	lib.RunNonDestructiveTest(
		t,
		*ctx,
		testimpl.TestManagedRedisReadOnly,
	)
}
GO

# Regression: correct call, but a comment mentions the destructive runner.
make_case comment_mentions_runner pass <<'GO'
package test
// Read-only: unlike RunSetupTestTeardown, this does not apply or destroy.
func TestModule(t *testing.T) {
	lib.RunNonDestructiveTest(t, *ctx, testimpl.TestComposableCompleteReadOnly)
}
GO

# Multiline correct call (trailing comma) should still pass.
make_case multiline_correct pass <<'GO'
package test
func TestModule(t *testing.T) {
	lib.RunNonDestructiveTest(
		t,
		*ctx,
		testimpl.TestComposableCompleteReadOnly,
	)
}
GO

# An empty/stub readonly file (no runner call) is intentionally rejected.
make_case empty_readonly fail </dev/null

make_case no_readonly_dir noreadonly </dev/null

if [ "$fails" -ne 0 ]; then
  echo "$fails self-test case(s) failed." >&2
  exit 1
fi
echo "All validate-readonly-test self-tests passed."

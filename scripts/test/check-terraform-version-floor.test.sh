#!/usr/bin/env bash
#
# Self-test for template/.github/scripts/check-terraform-version-floor.sh.
#
# The fragile part of that guard is resolving "oldest version this constraint
# admits" from a required_version string, so that is asserted exhaustively and
# without needing Terraform. The end-to-end path (does an old Terraform actually
# reject a too-new module) is only exercised when a suitable old binary happens
# to be installed, so pre-commit stays fast and offline.
#
# Wired into the skeleton's own pre-commit so the guard that protects every
# module is itself protected against regression.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
script="$repo_root/template/.github/scripts/check-terraform-version-floor.sh"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

fails=0

# resolves <constraint> <expected-floor|ERROR>
resolves() {
  constraint="$1"; want="$2"
  dir="$workdir/resolve"; rm -rf "$dir"; mkdir -p "$dir"
  printf 'terraform {\n  required_version = "%s"\n}\n' "$constraint" > "$dir/versions.tf"
  set +e
  actual="$( cd "$dir" && "$script" --print-floor 2>/dev/null )"
  rc=$?
  set -e
  [ "$rc" -ne 0 ] && actual="ERROR"
  if [ "$actual" = "$want" ]; then
    echo "ok   - resolve '$constraint' -> $actual"
  else
    echo "FAIL - resolve '$constraint': expected $want, got ${actual:-<empty>}"
    fails=$((fails + 1))
  fi
}

echo "== floor resolution =="
resolves '~> 1.0'              '1.0.0'
resolves '~> 1.3'              '1.3.0'
resolves '~> 1.10'             '1.10.0'
resolves '>= 1.5.0, < 2.0'     '1.5.0'
resolves '>= 1.3'              '1.3.0'
resolves '= 1.4.6'             '1.4.6'
resolves '~> 1.5.7'            '1.5.7'
# An upper bound must not be mistaken for a floor.
resolves '>= 1.5.0, <= 1.5.5'  '1.5.0'
# No lower bound at all is a defect in its own right, not something to guess at.
resolves '<= 1.5.5'            'ERROR'
resolves '< 2.0'               'ERROR'

# ------------------------------------------------------------------------------
# End-to-end: only if some Terraform older than 1.3 is available, since the
# fixture below relies on optional() being rejected.
# ------------------------------------------------------------------------------

old_tf=""
for candidate in "${ASDF_DATA_DIR:-$HOME/.asdf}"/installs/terraform/1.[012].*; do
  [ -x "$candidate/bin/terraform" ] && old_tf="$candidate/bin/terraform"
done

if [ -z "$old_tf" ]; then
  echo "skip - end-to-end check (no Terraform < 1.3 installed)"
else
  ver="$("$old_tf" version | head -1 | sed -E 's/Terraform v//')"
  echo "== end-to-end against Terraform $ver =="

  # expects <name> <pass|fail> ; variables.tf body on stdin
  expects() {
    name="$1"; expected="$2"
    dir="$workdir/$name"; rm -rf "$dir"; mkdir -p "$dir"
    printf 'terraform {\n  required_version = "= %s"\n}\n' "$ver" > "$dir/versions.tf"
    cat > "$dir/variables.tf"
    want=0; [ "$expected" = "fail" ] && want=1
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

  # optional() needs >= 1.3, so declaring this older version must be rejected.
  expects understated-floor fail <<'TF'
variable "thing" {
  type = object({
    name    = string
    enabled = optional(bool, true)
  })
  default = null
}
TF

  # Nothing version-gated: the declared floor is honest and must pass.
  expects accurate-floor pass <<'TF'
variable "thing" {
  type    = string
  default = "ok"
}
TF
fi

if [ "$fails" -gt 0 ]; then
  echo "$fails check(s) failed"
  exit 1
fi
echo "all checks passed"

#!/usr/bin/env bash
#
# Self-test for template/.github/scripts/check-terraform-version-floor.sh.
#
# Two of the guard's three behaviours need no Terraform at all and so run
# everywhere, including this repo's CI (which installs no Terraform):
#
#   * resolving "oldest version this constraint admits" from a required_version
#   * detecting an example whose constraint disagrees with the root
#
# The third -- actually loading the repo with an old binary -- only runs when a
# suitable old Terraform happens to be installed, so pre-commit stays fast and
# offline.
#
# Wired into the skeleton's own pre-commit so the guard that protects every
# module is itself protected against regression.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
script="$repo_root/template/.github/scripts/check-terraform-version-floor.sh"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

fails=0

pass_fail() {  # <name> <expected 0|1> <actual>
  if [ "$3" -eq "$2" ]; then
    echo "ok   - $1 (exit $3)"
  else
    echo "FAIL - $1: expected exit $2, got $3"
    fails=$((fails + 1))
  fi
}

# ------------------------------------------------------------------------------
# 1. Floor resolution
# ------------------------------------------------------------------------------

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
# 2. Example/root constraint drift
#
# Checked before any binary is acquired, so this needs no Terraform.
# ------------------------------------------------------------------------------

# make_repo <dir> <root-constraint> <example-constraint...>
make_repo() {
  d="$1"; rootc="$2"; shift 2
  rm -rf "$d"; mkdir -p "$d"
  printf 'terraform {\n  required_version = "%s"\n}\n' "$rootc" > "$d/versions.tf"
  printf 'variable "x" {\n  type    = string\n  default = "ok"\n}\n' > "$d/variables.tf"
  i=0
  for ec in "$@"; do
    i=$((i + 1))
    mkdir -p "$d/examples/ex$i"
    printf 'terraform {\n  required_version = "%s"\n}\n' "$ec" > "$d/examples/ex$i/versions.tf"
    printf 'module "m" {\n  source = "../.."\n}\n' > "$d/examples/ex$i/main.tf"
  done
}

echo "== example/root constraint drift =="

make_repo "$workdir/drift" '~> 1.5' '~> 1.2'
set +e; ( cd "$workdir/drift" && "$script" >/dev/null 2>&1 ); rc=$?; set -e
pass_fail "example disagreeing with root is rejected" 1 "$rc"

make_repo "$workdir/agree" '~> 1.5' '~> 1.5'
set +e
out="$( cd "$workdir/agree" && "$script" 2>&1 )"; rc=$?
set -e
if printf '%s' "$out" | grep -q "do not match the root module"; then
  echo "FAIL - matching constraints must not be reported as drift"
  fails=$((fails + 1))
else
  echo "ok   - matching constraints are not reported as drift"
fi

make_repo "$workdir/spacing" '~> 1.5' '~>  1.5'
set +e
out="$( cd "$workdir/spacing" && "$script" 2>&1 )"; rc=$?
set -e
if printf '%s' "$out" | grep -q "do not match the root module"; then
  echo "FAIL - whitespace-only difference must not count as drift"
  fails=$((fails + 1))
else
  echo "ok   - whitespace-only difference is not drift"
fi

# ------------------------------------------------------------------------------
# 3. End-to-end, only when an old enough Terraform is present
# ------------------------------------------------------------------------------

old_tf=""
for candidate in "${ASDF_DATA_DIR:-$HOME/.asdf}"/installs/terraform/1.[012].*; do
  [ -x "$candidate/bin/terraform" ] && old_tf="$candidate/bin/terraform"
done

if [ -z "$old_tf" ]; then
  echo "skip - end-to-end checks (no Terraform < 1.3 installed)"
else
  ver="$("$old_tf" version | head -1 | sed -E 's/Terraform v//')"
  echo "== end-to-end against Terraform $ver =="

  # Honest floor everywhere: must pass.
  make_repo "$workdir/honest" "= $ver" "= $ver"
  set +e; ( cd "$workdir/honest" && "$script" >/dev/null 2>&1 ); rc=$?; set -e
  pass_fail "honest floor passes" 0 "$rc"

  # The case that root-only checking missed: the ROOT is fine at this version,
  # but an EXAMPLE uses optional(), which needs >= 1.3.
  make_repo "$workdir/example-too-low" "= $ver" "= $ver"
  cat >> "$workdir/example-too-low/examples/ex1/main.tf" <<'TF'

variable "needs_13" {
  type = object({
    name    = string
    enabled = optional(bool, true)
  })
  default = null
}
TF
  set +e; ( cd "$workdir/example-too-low" && "$script" >/dev/null 2>&1 ); rc=$?; set -e
  pass_fail "example needing a newer Terraform than the root is rejected" 1 "$rc"
fi

if [ "$fails" -gt 0 ]; then
  echo "$fails check(s) failed"
  exit 1
fi
echo "all checks passed"

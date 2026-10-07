#!/usr/bin/env bash
#
# Self-test for template/.github/scripts/check-terraform-version-floor.sh.
#
# Most of the guard's behaviour needs no real Terraform and so runs everywhere,
# including this repo's CI (which installs no Terraform):
#
#   * resolving "oldest version this constraint admits" from a required_version
#   * enforcing that every example declares a floor at or above the root's
#   * finding a binary under asdf or mise, and refusing one built for another
#     CPU on macOS (against a stub mise, terraform, uname and file)
#
# Actually loading the repo with an old binary only runs when a suitable old
# Terraform happens to be installed, so pre-commit stays fast and offline.
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
# 2. The example/root floor relation: every example must declare >= the root.
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

# Asserts on the pre-binary phase only: run the guard and look for the rejection
# message, so these cases stay offline even when the constraint would pass.
rejects_before_binary() {  # <name> <pattern> <root> <example...>
  name="$1"; pattern="$2"; shift 2
  make_repo "$workdir/rel" "$@"
  set +e
  out="$( cd "$workdir/rel" && "$script" 2>&1 )"
  set -e
  if printf '%s' "$out" | grep -q "$pattern"; then
    echo "ok   - $name"
  else
    echo "FAIL - $name: expected output matching '$pattern'"
    fails=$((fails + 1))
  fi
}

accepts_relation() {  # <name> <root> <example...>
  name="$1"; shift
  make_repo "$workdir/rel" "$@"
  set +e
  out="$( cd "$workdir/rel" && "$script" 2>&1 )"
  set -e
  if printf '%s' "$out" | grep -qE "below the root's|declares no required_version"; then
    echo "FAIL - $name: relation was rejected"
    fails=$((fails + 1))
  else
    echo "ok   - $name"
  fi
}

echo "== example/root floor relation =="

rejects_before_binary "example below the root is rejected" \
  "below the root's" '~> 1.5' '~> 1.2'

accepts_relation "example equal to the root is accepted" '~> 1.5' '~> 1.5'

# The point of >= over ==: an example may legitimately need a newer Terraform
# (its own feature use, or a module it consumes) without dragging the root up.
accepts_relation "example above the root is accepted" '~> 1.3' '~> 1.5'

accepts_relation "whitespace-only difference is not a violation" '~> 1.5' '~>  1.5'

# Patch-level and two-component constraints must compare numerically, not
# lexically -- 1.10 is above 1.9, and "1.9" > "1.10" as strings.
accepts_relation "1.10 example over a 1.9 root is accepted" '~> 1.9' '~> 1.10'
rejects_before_binary "1.9 example under a 1.10 root is rejected" \
  "below the root's" '~> 1.10' '~> 1.9'

# An example that declares nothing is not "inheriting" the root -- it is silent
# about a contract it is required to state.
make_repo "$workdir/silent" '~> 1.5' '~> 1.5'
printf 'terraform {\n}\n' > "$workdir/silent/examples/ex1/versions.tf"
set +e; out="$( cd "$workdir/silent" && "$script" 2>&1 )"; rc=$?; set -e
if printf '%s' "$out" | grep -q "declares no required_version"; then
  echo "ok   - example with no required_version is rejected"
else
  echo "FAIL - example with no required_version: expected a clear rejection"
  fails=$((fails + 1))
fi

make_repo "$workdir/nofile" '~> 1.5' '~> 1.5'
rm -f "$workdir/nofile/examples/ex1/versions.tf"
set +e; out="$( cd "$workdir/nofile" && "$script" 2>&1 )"; rc=$?; set -e
if printf '%s' "$out" | grep -q "must declare a required_version"; then
  echo "ok   - example with no versions.tf is rejected"
else
  echo "FAIL - example with no versions.tf: expected a clear rejection"
  fails=$((fails + 1))
fi

# A root that exists but declares nothing must produce the diagnostic, not die
# silently: under `set -e` with pipefail a non-matching grep would abort first.
rm -rf "$workdir/rootless"; mkdir -p "$workdir/rootless"
printf 'terraform {\n}\n' > "$workdir/rootless/versions.tf"
set +e; out="$( cd "$workdir/rootless" && "$script" 2>&1 )"; rc=$?; set -e
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "no required_version found"; then
  echo "ok   - root with no required_version reports why"
else
  echo "FAIL - root with no required_version: expected a diagnostic, got '${out:-<silence>}'"
  fails=$((fails + 1))
fi

# --print-floor feeds a CI cache key, so it must report the ROOT floor even when
# an example declares something higher.
make_repo "$workdir/printfloor" '~> 1.3' '~> 1.9'
set +e; actual="$( cd "$workdir/printfloor" && "$script" --print-floor 2>/dev/null )"; set -e
if [ "$actual" = "1.3.0" ]; then
  echo "ok   - --print-floor reports the root floor, not an example's"
else
  echo "FAIL - --print-floor: expected 1.3.0, got ${actual:-<empty>}"
  fails=$((fails + 1))
fi

# ------------------------------------------------------------------------------
# 3. Binary resolution, offline, against stubs
#
# A fake mise answers only the real `mise which terraform --tool terraform@<v>`
# form, a fake terraform accepts init/validate, and uname/file are stubbed so
# the architecture check behaves the same on any host. asdf is kept off PATH
# and ASDF_DATA_DIR points at an empty directory.
# ------------------------------------------------------------------------------

echo "== binary resolution (stubs) =="

stubs="$workdir/stubs"; fake_mise_root="$workdir/mise-installs"
mkdir -p "$stubs" "$workdir/no-asdf" "$fake_mise_root/1.5.0"
printf '#!/bin/sh\necho "fake terraform $*"\n' > "$fake_mise_root/1.5.0/terraform"
cat > "$stubs/mise" <<STUB
#!/bin/sh
if [ "\$1" = which ] && [ "\$2" = terraform ] && [ "\$3" = --tool ]; then
  p="$fake_mise_root/\${4#terraform@}/terraform"
  [ -x "\$p" ] && { echo "\$p"; exit 0; }
  exit 1
fi
[ "\$1" = install ] && exit 0
echo "error: unexpected argument" >&2
exit 2
STUB
chmod +x "$stubs/mise" "$fake_mise_root/1.5.0/terraform"

# with_host <uname -s> <uname -m> <file description, or FAIL> <cmd...>
with_host() {
  host="$1"; arch="$2"; desc="$3"; shift 3
  hostbin="$workdir/host-$host-$arch"; rm -rf "$hostbin"; mkdir -p "$hostbin"
  printf '#!/bin/sh\ncase "$1" in -s) echo %s ;; -m) echo %s ;; esac\n' "$host" "$arch" > "$hostbin/uname"
  if [ "$desc" = FAIL ]; then
    printf '#!/bin/sh\nexit 1\n' > "$hostbin/file"
  else
    printf '#!/bin/sh\necho "%s"\n' "$desc" > "$hostbin/file"
  fi
  chmod +x "$hostbin/uname" "$hostbin/file"
  PATH="$hostbin:$stubs:/usr/bin:/bin" ASDF_DATA_DIR="$workdir/no-asdf" "$@"
}

make_repo "$workdir/mise" '~> 1.5' '~> 1.5'
set +e
out="$( cd "$workdir/mise" && with_host Darwin arm64 "Mach-O 64-bit executable arm64" "$script" 2>&1 )"; rc=$?
set -e
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "ok: the root module on Terraform 1.5.0"; then
  echo "ok   - mise-only host resolves Terraform through mise which --tool"
else
  echo "FAIL - mise-only host: expected the floor to load via mise (exit $rc): $out"
  fails=$((fails + 1))
fi

set +e
out="$( cd "$workdir/mise" && with_host Darwin arm64 "Mach-O 64-bit executable x86_64" "$script" 2>&1 )"; rc=$?
set -e
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "not built for this arm64 host" \
   && ! printf '%s' "$out" | grep -q "ok: the root module"; then
  echo "ok   - an amd64 binary on an arm64 Mac is refused before it runs"
else
  echo "FAIL - amd64 binary on an arm64 Mac: expected a refusal (exit $rc): $out"
  fails=$((fails + 1))
fi

set +e
out="$( cd "$workdir/mise" && with_host Darwin arm64 "Mach-O universal binary with 2 architectures: [x86_64] [arm64]" "$script" 2>&1 )"; rc=$?
set -e
pass_fail "a universal binary is accepted" 0 "$rc"

# Off macOS the description is never consulted, whatever it says.
set +e
out="$( cd "$workdir/mise" && with_host Linux arm64 "Mach-O 64-bit executable x86_64" "$script" 2>&1 )"; rc=$?
set -e
pass_fail "the architecture check applies only on macOS" 0 "$rc"

# The other direction: an arm64-only binary on an Intel Mac is refused too.
set +e
out="$( cd "$workdir/mise" && with_host Darwin x86_64 "Mach-O 64-bit executable arm64" "$script" 2>&1 )"; rc=$?
set -e
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "not built for this x86_64 host"; then
  echo "ok   - an arm64 binary on an Intel Mac is refused before it runs"
else
  echo "FAIL - arm64 binary on an Intel Mac: expected a refusal (exit $rc): $out"
  fails=$((fails + 1))
fi

# When `file` can't describe the binary, the check is skipped visibly, not silently.
set +e
out="$( cd "$workdir/mise" && with_host Darwin arm64 FAIL "$script" 2>&1 )"; rc=$?
set -e
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "skipping the architecture check"; then
  echo "ok   - a failing \`file\` skips the check with a note"
else
  echo "FAIL - failing file: expected a pass with a note (exit $rc): $out"
  fails=$((fails + 1))
fi

# ------------------------------------------------------------------------------
# 4. End-to-end, only when an old enough Terraform is present
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

  # The same example passes once it declares the floor it actually needs -- and
  # the root keeps its older floor. This is the case == would have blocked.
  new_tf=""
  for candidate in "${ASDF_DATA_DIR:-$HOME/.asdf}"/installs/terraform/1.[3-9].* \
                   "${ASDF_DATA_DIR:-$HOME/.asdf}"/installs/terraform/1.[1-9][0-9].*; do
    [ -x "$candidate/bin/terraform" ] && new_tf="$candidate"
  done
  if [ -z "$new_tf" ]; then
    echo "skip - example-above-root end-to-end (no Terraform >= 1.3 installed)"
  else
    newver="$(basename "$new_tf")"
    # The root is >= rather than = here on purpose: Terraform enforces every
    # required_version in the tree, so an exact-pinned root and a higher example
    # are contradictory and cannot both be satisfied. That is a real (and
    # correctly rejected) configuration, not the one under test.
    make_repo "$workdir/example-higher" ">= $ver" "= $newver"
    cat >> "$workdir/example-higher/examples/ex1/main.tf" <<'TF'

variable "needs_13" {
  type = object({
    name    = string
    enabled = optional(bool, true)
  })
  default = null
}
TF
    set +e
    out="$( cd "$workdir/example-higher" && "$script" 2>&1 )"; rc=$?
    set -e
    if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "ok: the root module on Terraform $ver"; then
      echo "ok   - example above the root loads at its own floor, root stays at $ver"
    else
      echo "FAIL - example above the root: expected pass with root still on $ver (exit $rc)"
      fails=$((fails + 1))
    fi
  fi
fi

if [ "$fails" -gt 0 ]; then
  echo "$fails check(s) failed"
  exit 1
fi
echo "all checks passed"

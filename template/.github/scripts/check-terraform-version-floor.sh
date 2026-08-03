#!/usr/bin/env bash

# Verifies that declared Terraform version floors are ones this repository can
# actually be loaded with -- the root module and every example.
#
# Rather than maintaining a table of "which feature needs which Terraform
# version", this asks Terraform itself: resolve the oldest version a constraint
# admits, then init and validate with that exact binary. If anything uses a
# feature newer than its declared floor, that binary rejects it. The check is
# therefore self-maintaining as new language features appear, and it also
# catches floors inherited from *consumed modules*, which no scan of this
# repository's own HCL can see.
#
# Scope and the root/example relationship:
#
#   * The root module's floor describes what the root module needs. It is NOT
#     raised to cover constraints inherited from modules an example consumes --
#     consumers use the root module, not the examples, and a floor that moved
#     whenever a dependency bumped its own requirement would churn constantly.
#
#   * Each example must declare a floor >= the root's. Terraform applies every
#     required_version in the module tree and takes the maximum, so an example
#     that declares less than the root is stating something untrue about itself.
#     Declaring more is legitimate: an example may consume a module, or use a
#     language feature, that genuinely needs a newer Terraform.
#
#   * Each directory is then loaded with its own declared floor.
#
# In practice root and examples usually match; the >= relation exists so that a
# genuinely newer example does not force the root floor up with it.
#
# This target is CI-oriented. CI runs it after `make lint`, so generated example
# provider files and a lock file already exist. Running it locally is supported
# but may install a Terraform version you would not otherwise have.
#
# Usage:
#   check-terraform-version-floor.sh                # run the check
#   check-terraform-version-floor.sh --print-floor  # print the ROOT floor only
#
# --print-floor exists so CI can compute a cache key before installing the
# toolchain. It reports the root floor, which is always needed; an example
# declaring something higher is rare and installs uncached.

set -euo pipefail

MODE="${1:-check}"
VERSIONS_FILE="${VERSIONS_FILE:-versions.tf}"
# Keep our .terraform out of the way of the main lint pass, which inits the same
# directories with a different Terraform version.
FLOOR_TF_DATA_DIR="${FLOOR_TF_DATA_DIR:-.terraform-version-floor}"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -f "${VERSIONS_FILE}" ]] || die "no ${VERSIONS_FILE} found in $(pwd)"

# ------------------------------------------------------------------------------
# Resolve the lowest Terraform version a constraint admits.
#
# Only lower-bound operators contribute a floor: `~>`, `>=`, `=`, and a bare
# version. Upper bounds (`<`, `<=`) are ignored, and strict `>` / exclusions
# (`!=`) contribute nothing -- neither appears in fleet use today. Where several
# terms are comma-separated we take the highest of the minimums.
# ------------------------------------------------------------------------------

# `|| true` matters: under `set -e` with pipefail, a non-matching grep would abort
# the script here, making the "no required_version" diagnostics below unreachable.
read_constraint() {
  { grep -oE 'required_version[[:space:]]*=[[:space:]]*"[^"]*"' "$1" 2>/dev/null || true; } \
    | head -1 | sed -E 's/.*"(.*)"$/\1/'
}

resolve_floor() {
  local constraint="$1" floor="" term raw maj min pat candidate
  IFS=',' read -ra terms <<< "${constraint}"
  for term in "${terms[@]}"; do
    term="$(printf '%s' "${term}" | tr -d '[:space:]')"
    case "${term}" in
      '~>'*|'>='*|'='[0-9]*|[0-9]*)
        raw="$(printf '%s' "${term}" | grep -oE '[0-9]+(\.[0-9]+)*' || true)"
        [[ -n "${raw}" ]] || continue
        IFS='.' read -r maj min pat <<< "${raw}"
        candidate="${maj:-0}.${min:-0}.${pat:-0}"
        if [[ -z "${floor}" ]] ||
           [[ "$(printf '%s\n%s\n' "${floor}" "${candidate}" | sort -V | tail -1)" == "${candidate}" ]]; then
          floor="${candidate}"
        fi
        ;;
      *) ;;
    esac
  done
  printf '%s' "${floor}"
}

# version_ge A B -> true when A >= B
version_ge() {
  [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" == "$2" ]]
}

constraint="$(read_constraint "${VERSIONS_FILE}")"
[[ -n "${constraint}" ]] || die "no required_version found in ${VERSIONS_FILE}"

floor="$(resolve_floor "${constraint}")"
[[ -n "${floor}" ]] || die "could not resolve a lower bound from required_version = \"${constraint}\""

if [[ "${MODE}" == "--print-floor" ]]; then
  printf '%s\n' "${floor}"
  exit 0
fi

echo "==> Root required_version: ${constraint}  (floor ${floor})"

# ------------------------------------------------------------------------------
# Each example must declare a floor at or above the root's.
#
# Checked before any binary is acquired, so this needs no Terraform.
# ------------------------------------------------------------------------------

example_dirs=()
while IFS= read -r d; do
  [[ -n "$d" ]] && example_dirs+=("$d")
done < <(
  find ./examples -path "*/.terraform" -prune -o -name main.tf -print 2>/dev/null \
    | xargs -n1 dirname 2>/dev/null | sort -u
)

# Parallel arrays: bash 3.2 (macOS) has no associative arrays.
check_dirs=(".")
check_floors=("${floor}")
bad=0

for d in ${example_dirs[@]+"${example_dirs[@]}"}; do
  if [[ ! -f "${d}/versions.tf" ]]; then
    echo "    ${d}: no versions.tf -- it must declare a required_version" >&2
    bad=1
    continue
  fi
  ec="$(read_constraint "${d}/versions.tf")"
  if [[ -z "${ec}" ]]; then
    echo "    ${d}/versions.tf declares no required_version" >&2
    bad=1
    continue
  fi
  ef="$(resolve_floor "${ec}")"
  if [[ -z "${ef}" ]]; then
    echo "    ${d}/versions.tf has no lower bound in \"${ec}\"" >&2
    bad=1
    continue
  fi
  if ! version_ge "${ef}" "${floor}"; then
    echo "    ${d}/versions.tf declares \"${ec}\" (floor ${ef}), below the root's ${floor}" >&2
    bad=1
    continue
  fi
  check_dirs+=("${d}")
  check_floors+=("${ef}")
done

if [[ "${bad}" -ne 0 ]]; then
  cat >&2 <<EOF

FAILED: one or more examples declare a Terraform floor below the root module's.

Terraform applies every required_version in the module tree and uses the
highest, so an example that declares less than the root is stating something
untrue about itself -- and \`make lint\` cannot catch it, because it validates
with the .tool-versions Terraform rather than the declared floor.

Set each examples/*/versions.tf to the root's constraint, or to a higher one if
that example genuinely needs a newer Terraform, and regenerate the READMEs
(terraform-docs renders the constraint into the Requirements table).
EOF
  exit 1
fi

# ------------------------------------------------------------------------------
# Acquire each distinct version needed.
# ------------------------------------------------------------------------------

resolve_binary() {
  local version="$1" candidate
  candidate="${ASDF_DATA_DIR:-${HOME}/.asdf}/installs/terraform/${version}/bin/terraform"
  if [[ -x "${candidate}" ]]; then printf '%s' "${candidate}"; return 0; fi
  if command -v mise >/dev/null 2>&1; then
    candidate="$(mise which terraform --version "${version}" 2>/dev/null || true)"
    if [[ -n "${candidate}" && -x "${candidate}" ]]; then printf '%s' "${candidate}"; return 0; fi
  fi
  return 1
}

ensure_binary() {
  local version="$1" bin
  if bin="$(resolve_binary "${version}")"; then printf '%s' "${bin}"; return 0; fi
  if command -v asdf >/dev/null 2>&1; then
    echo "==> Installing Terraform ${version} via asdf" >&2
    asdf install terraform "${version}" >&2 \
      || die "asdf could not install Terraform ${version} (does a build exist for this platform?)"
  elif command -v mise >/dev/null 2>&1; then
    echo "==> Installing Terraform ${version} via mise" >&2
    mise install "terraform@${version}" >&2 \
      || die "mise could not install Terraform ${version} (does a build exist for this platform?)"
  else
    die "Terraform ${version} is not installed and neither asdf nor mise is available to install it"
  fi
  bin="$(resolve_binary "${version}")" || die "install reported success but Terraform ${version} was not found"
  printf '%s' "${bin}"
}

# ------------------------------------------------------------------------------
# Load each directory with its own declared floor.
# ------------------------------------------------------------------------------

created_locks=()
cleanup() {
  local d
  for d in ${check_dirs[@]+"${check_dirs[@]}"}; do
    [[ -n "${d}" ]] && rm -rf -- "${d:?}/${FLOOR_TF_DATA_DIR}"
  done
  # Only remove lock files this check created; never touch pre-existing ones.
  for d in ${created_locks[@]+"${created_locks[@]}"}; do
    [[ -n "${d}" ]] && rm -f -- "${d}/.terraform.lock.hcl"
  done
}
trap cleanup EXIT

check_dir() {
  local dir="$1" version="$2" label="$3" bin out rc lock_args=()
  bin="$(ensure_binary "${version}")"

  # Never rewrite a lock file produced by the earlier lint init at a different
  # Terraform version; if none exists yet, note it so cleanup can remove ours.
  if [[ -f "${dir}/.terraform.lock.hcl" ]]; then
    lock_args=(-lockfile=readonly)
  else
    created_locks+=("${dir}")
  fi

  set +e
  # Guarded expansion: bash 3.2 (macOS) errors on an empty array under `set -u`.
  out="$( cd "${dir}" && TF_DATA_DIR="${FLOOR_TF_DATA_DIR}" "${bin}" \
      init -backend=false -input=false ${lock_args[@]+"${lock_args[@]}"} 2>&1 )"
  rc=$?
  if [[ ${rc} -eq 0 ]]; then
    out="$( cd "${dir}" && TF_DATA_DIR="${FLOOR_TF_DATA_DIR}" "${bin}" validate 2>&1 )"
    rc=$?
  fi
  set -e

  if [[ ${rc} -ne 0 ]]; then
    cat >&2 <<EOF

FAILED: Terraform ${version} could not load ${label}, but its declared
        required_version claims that version is supported.

Terraform reported:
------------------------------------------------------------------------------
$(printf '%s' "${out}" | tail -30)
------------------------------------------------------------------------------

Either raise that directory's floor to the oldest version that actually works,
or stop using whatever requires a newer Terraform.

Note the requirement may come from a module this directory *consumes* rather
than from its own code -- a consumed module's own required_version applies too,
and is not visible here. That is a legitimate reason for an example to declare a
higher floor than the root module.

If this is an example declaring more than the root, also check that the root's
constraint actually admits that version: an exact-pinned root (= 1.4.6) and a
higher example cannot both be satisfied, because Terraform enforces every
required_version in the tree.

Common culprits: optional() in a variable type and the two-argument optional()
form need >= 1.3; nullable and moved need >= 1.1; a validation block's
error_message form and precondition/postcondition need >= 1.2; terraform_data
needs >= 1.4; check and import blocks need >= 1.5; removed needs >= 1.7;
strcontains/startswith/endswith and provider:: functions need >= 1.8;
templatestring needs >= 1.9.
EOF
    exit 1
  fi
  echo "    ok: ${label} on Terraform ${version}"
}

echo "==> Loading each directory at its declared floor"
i=0
while [[ ${i} -lt ${#check_dirs[@]} ]]; do
  d="${check_dirs[$i]}"
  v="${check_floors[$i]}"
  if [[ "${d}" == "." ]]; then
    check_dir "${d}" "${v}" "the root module"
  else
    check_dir "${d}" "${v}" "${d}"
  fi
  i=$(( i + 1 ))
done

echo "==> OK: root module and $(( ${#check_dirs[@]} - 1 )) example(s) load at their declared floors"

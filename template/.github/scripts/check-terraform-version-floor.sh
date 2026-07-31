#!/usr/bin/env bash

# Verifies that the Terraform version floor declared in required_version is
# actually sufficient to parse and validate this module.
#
# Rather than maintaining a table of "which feature needs which Terraform
# version", this asks Terraform itself: resolve the oldest version the
# constraint admits, then init and validate the module with that exact binary.
# If the module uses anything newer than it claims to need, that binary fails.
# The check is therefore self-maintaining as new language features appear.
#
# Usage:
#   check-terraform-version-floor.sh                # run the check
#   check-terraform-version-floor.sh --print-floor  # print resolved floor only
#
# The --print-floor mode exists so CI can compute a cache key before installing
# the toolchain.

set -euo pipefail

MODE="${1:-check}"
VERSIONS_FILE="${VERSIONS_FILE:-versions.tf}"
# Keep our .terraform out of the way of the main lint pass, which inits the same
# directory with a different Terraform version.
FLOOR_TF_DATA_DIR="${FLOOR_TF_DATA_DIR:-.terraform-version-floor}"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -f "${VERSIONS_FILE}" ]] || die "no ${VERSIONS_FILE} found in $(pwd)"

# ------------------------------------------------------------------------------
# Resolve the lowest Terraform version the constraint admits.
#
# Every lower-bound operator (~>, >=, =) pins a minimum. Where several terms are
# comma-separated we take the highest of those minimums. Upper bounds (<, <=)
# are irrelevant here.
# ------------------------------------------------------------------------------

constraint="$(grep -oE 'required_version[[:space:]]*=[[:space:]]*"[^"]*"' "${VERSIONS_FILE}" \
  | head -1 | sed -E 's/.*"(.*)"$/\1/')"

[[ -n "${constraint}" ]] || die "no required_version found in ${VERSIONS_FILE}"

floor=""
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
    *) ;;  # upper bounds and anything else: no lower bound to contribute
  esac
done

[[ -n "${floor}" ]] || die "could not resolve a lower bound from required_version = \"${constraint}\""

if [[ "${MODE}" == "--print-floor" ]]; then
  printf '%s\n' "${floor}"
  exit 0
fi

echo "==> Declared required_version: ${constraint}"
echo "==> Oldest permitted Terraform: ${floor}"

# ------------------------------------------------------------------------------
# Acquire that exact Terraform version.
# ------------------------------------------------------------------------------

resolve_binary() {
  local version="$1" data_dir candidate
  data_dir="${ASDF_DATA_DIR:-${HOME}/.asdf}"
  candidate="${data_dir}/installs/terraform/${version}/bin/terraform"
  if [[ -x "${candidate}" ]]; then printf '%s' "${candidate}"; return 0; fi
  return 1
}

if ! terraform_bin="$(resolve_binary "${floor}")"; then
  command -v asdf >/dev/null 2>&1 || die "Terraform ${floor} is not installed and asdf is unavailable to install it"
  echo "==> Installing Terraform ${floor} via asdf"
  asdf install terraform "${floor}"
  terraform_bin="$(resolve_binary "${floor}")" \
    || die "asdf reported success but Terraform ${floor} was not found"
fi

echo "==> Using ${terraform_bin}"

# ------------------------------------------------------------------------------
# Ask Terraform whether the module is actually parseable at that version.
# ------------------------------------------------------------------------------

cleanup() { rm -rf -- "${FLOOR_TF_DATA_DIR}"; }
trap cleanup EXIT

if ! TF_DATA_DIR="${FLOOR_TF_DATA_DIR}" "${terraform_bin}" init -backend=false -input=false >/dev/null; then
  cat >&2 <<EOF

FAILED: Terraform ${floor} could not initialize this module, but required_version
        ("${constraint}") claims that version is supported.

Either raise the floor in ${VERSIONS_FILE} to the oldest version that actually
works, or stop using the language feature that requires a newer Terraform.

Common culprits: optional() in a variable type needs >= 1.3; nullable and moved
need >= 1.1; precondition/postcondition need >= 1.2; terraform_data needs >= 1.4;
check and import blocks need >= 1.5; removed needs >= 1.7; strcontains/startswith/
endswith and provider:: functions need >= 1.8; templatestring needs >= 1.9.
EOF
  exit 1
fi

if ! TF_DATA_DIR="${FLOOR_TF_DATA_DIR}" "${terraform_bin}" validate >/dev/null; then
  cat >&2 <<EOF

FAILED: Terraform ${floor} could not validate this module, but required_version
        ("${constraint}") claims that version is supported. See the note above
        about raising the floor in ${VERSIONS_FILE}.
EOF
  exit 1
fi

echo "==> OK: module initializes and validates on Terraform ${floor}"

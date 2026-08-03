#!/usr/bin/env bash

# Verifies that the Terraform version floor declared in required_version is
# actually sufficient to load this repository -- the root module and every
# example.
#
# Rather than maintaining a table of "which feature needs which Terraform
# version", this asks Terraform itself: resolve the oldest version the
# constraint admits, then init and validate with that exact binary. If anything
# here uses a feature newer than the declared floor, that binary rejects it. The
# check is therefore self-maintaining as new language features appear, and it
# also catches floors inherited from *consumed modules*, which no scan of this
# repository's own HCL can see.
#
# Scope note: this repository uses a single floor for the whole repo rather than
# per-directory floors. The root module alone often needs less than an example
# does, but over-stating only excludes Terraform versions long past end of life,
# while under-stating actively breaks consumers -- and one number per repo is far
# cheaper to review and enforce. Every versions.tf must therefore agree.
#
# This target is CI-oriented. CI runs it after `make lint`, so generated example
# provider files and a lock file already exist. Running it locally is supported
# but may install a Terraform version you would not otherwise have.
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

read_constraint() {
  grep -oE 'required_version[[:space:]]*=[[:space:]]*"[^"]*"' "$1" 2>/dev/null \
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

constraint="$(read_constraint "${VERSIONS_FILE}")"
[[ -n "${constraint}" ]] || die "no required_version found in ${VERSIONS_FILE}"

floor="$(resolve_floor "${constraint}")"
[[ -n "${floor}" ]] || die "could not resolve a lower bound from required_version = \"${constraint}\""

if [[ "${MODE}" == "--print-floor" ]]; then
  printf '%s\n' "${floor}"
  exit 0
fi

echo "==> Declared required_version: ${constraint}"
echo "==> Oldest permitted Terraform: ${floor}"

# ------------------------------------------------------------------------------
# Every versions.tf in the repo must declare the same constraint.
#
# An example advertising a lower floor than the root is a lie consumers copy,
# and `make lint` cannot catch it because it validates with the current
# .tool-versions Terraform rather than the declared floor.
# ------------------------------------------------------------------------------

normalise() { printf '%s' "$1" | tr -s '[:space:]' ' ' | sed -E 's/^ | $//g'; }

drift=0
root_norm="$(normalise "${constraint}")"
example_dirs=()
while IFS= read -r d; do example_dirs+=("$d"); done < <(
  find ./examples -path "*/.terraform" -prune -o -name main.tf -print 2>/dev/null | xargs -n1 dirname 2>/dev/null | sort -u
)

for d in "${example_dirs[@]:-}"; do
  [[ -n "${d}" ]] || continue
  if [[ ! -f "${d}/versions.tf" ]]; then
    echo "    ${d}: no versions.tf (skipped)"
    continue
  fi
  ec="$(read_constraint "${d}/versions.tf")"
  if [[ "$(normalise "${ec}")" != "${root_norm}" ]]; then
    echo "    ${d}/versions.tf declares \"${ec}\" but the root declares \"${constraint}\"" >&2
    drift=1
  fi
done

if [[ "${drift}" -ne 0 ]]; then
  cat >&2 <<EOF

FAILED: example Terraform constraints do not match the root module.

This repository uses one floor for the whole repo. An example that advertises a
different constraint misleads anyone who copies it, and it is invisible to
\`make lint\`, which validates using the .tool-versions Terraform rather than the
declared floor.

Set every examples/*/versions.tf to the same required_version as the root, and
regenerate the READMEs (terraform-docs renders the constraint into the
Requirements table).
EOF
  exit 1
fi

# ------------------------------------------------------------------------------
# Acquire that exact Terraform version.
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

if ! terraform_bin="$(resolve_binary "${floor}")"; then
  if command -v asdf >/dev/null 2>&1; then
    echo "==> Installing Terraform ${floor} via asdf"
    asdf install terraform "${floor}" || die "asdf could not install Terraform ${floor} (does a build exist for this platform?)"
  elif command -v mise >/dev/null 2>&1; then
    echo "==> Installing Terraform ${floor} via mise"
    mise install "terraform@${floor}" || die "mise could not install Terraform ${floor} (does a build exist for this platform?)"
  else
    die "Terraform ${floor} is not installed and neither asdf nor mise is available to install it"
  fi
  terraform_bin="$(resolve_binary "${floor}")" \
    || die "install reported success but Terraform ${floor} was not found"
fi

echo "==> Using ${terraform_bin}"

# ------------------------------------------------------------------------------
# Load the root module and every example with that version.
# ------------------------------------------------------------------------------

created_locks=()
cleanup() {
  rm -rf -- "${FLOOR_TF_DATA_DIR}"
  local d
  for d in "${example_dirs[@]:-}"; do
    [[ -n "${d}" ]] && rm -rf -- "${d:?}/${FLOOR_TF_DATA_DIR}"
  done
  # Only remove lock files this check created; never touch pre-existing ones.
  for d in "${created_locks[@]:-}"; do
    [[ -n "${d}" ]] && rm -f -- "${d}/.terraform.lock.hcl"
  done
}
trap cleanup EXIT

check_dir() {
  local dir="$1" label="$2" out rc lock_args=()
  # Never rewrite a lock file produced by the earlier lint init at a different
  # Terraform version; if none exists yet, note it so cleanup can remove ours.
  if [[ -f "${dir}/.terraform.lock.hcl" ]]; then
    lock_args=(-lockfile=readonly)
  else
    created_locks+=("${dir}")
  fi

  set +e
  # Guarded expansion: bash 3.2 (macOS) errors on an empty array under `set -u`.
  out="$( cd "${dir}" && TF_DATA_DIR="${FLOOR_TF_DATA_DIR}" "${terraform_bin}" \
      init -backend=false -input=false ${lock_args[@]+"${lock_args[@]}"} 2>&1 )"
  rc=$?
  if [[ ${rc} -eq 0 ]]; then
    out="$( cd "${dir}" && TF_DATA_DIR="${FLOOR_TF_DATA_DIR}" "${terraform_bin}" validate 2>&1 )"
    rc=$?
  fi
  set -e

  if [[ ${rc} -ne 0 ]]; then
    cat >&2 <<EOF

FAILED: Terraform ${floor} could not load ${label}, but required_version
        ("${constraint}") claims that version is supported.

Terraform reported:
------------------------------------------------------------------------------
$(printf '%s' "${out}" | tail -30)
------------------------------------------------------------------------------

Either raise the floor to the oldest version that actually works, or stop using
whatever requires a newer Terraform.

Note the requirement may come from a module this repository *consumes* rather
than from its own code -- a consumed module's own required_version applies too,
and is not visible anywhere in this repository.

Common culprits: optional() in a variable type and the two-argument optional()
form need >= 1.3; nullable and moved need >= 1.1; a validation block's
error_message form and precondition/postcondition need >= 1.2; terraform_data
needs >= 1.4; check and import blocks need >= 1.5; removed needs >= 1.7;
strcontains/startswith/endswith and provider:: functions need >= 1.8;
templatestring needs >= 1.9.
EOF
    exit 1
  fi
  echo "    ok: ${label}"
}

echo "==> Loading with Terraform ${floor}"
check_dir "." "the root module"
for d in "${example_dirs[@]:-}"; do
  [[ -n "${d}" ]] || continue
  check_dir "${d}" "${d}"
done

echo "==> OK: root module and $(( ${#example_dirs[@]} )) example(s) load on Terraform ${floor}"

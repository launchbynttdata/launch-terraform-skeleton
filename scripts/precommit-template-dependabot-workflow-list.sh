#!/usr/bin/env bash
set -euo pipefail

# This script ensures the exclude-paths list in template/.github/dependabot.yml
# stays in sync with the workflow files delivered through the skeleton.
# It auto-updates the file, then exits non-zero if changes were made so that
# pre-commit signals the user to re-stage.

if ! command -v yq &>/dev/null; then
  echo "yq is required but not installed. See https://github.com/mikefarah/yq" >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
WORKFLOWS_DIR="${REPO_ROOT}/template/.github/workflows"
DEPENDABOT_FILE="${REPO_ROOT}/template/.github/dependabot.yml"

if [ ! -d "$WORKFLOWS_DIR" ]; then
  echo "No template workflows directory found at ${WORKFLOWS_DIR}" >&2
  exit 1
fi

if [ ! -f "$DEPENDABOT_FILE" ]; then
  echo "No dependabot config found at ${DEPENDABOT_FILE}" >&2
  exit 1
fi

# Build the desired exclude-paths from the workflow directory listing
desired=()
for wf in "$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml; do
  [ -e "$wf" ] || continue
  desired+=(".github/workflows/$(basename "$wf")")
done

if [ ${#desired[@]} -eq 0 ]; then
  echo "No workflow files found in ${WORKFLOWS_DIR}" >&2
  exit 1
fi

# Sort for stable comparison
IFS=$'\n' desired=($(sort <<<"${desired[*]}")); unset IFS

# Read current exclude-paths from the github-actions ecosystem entry
current=$(yq -r '
  .updates[] |
  select(.["package-ecosystem"] == "github-actions") |
  .["exclude-paths"][]
' "$DEPENDABOT_FILE" 2>/dev/null | sort)

desired_str=$(printf '%s\n' "${desired[@]}")

if [ "$current" = "$desired_str" ]; then
  exit 0
fi

# Build a yq expression that replaces the exclude-paths array
yq_expr='.updates[] |= (
  select(.["package-ecosystem"] == "github-actions") |
  .["exclude-paths"] = ['
for i in "${!desired[@]}"; do
  [ "$i" -gt 0 ] && yq_expr+=','
  yq_expr+="\"${desired[$i]}\""
done
yq_expr+='])'

yq -i "$yq_expr" "$DEPENDABOT_FILE"

echo "Updated exclude-paths in ${DEPENDABOT_FILE#"$REPO_ROOT"/}" >&2
printf '  - %s\n' "${desired[@]}" >&2
exit 1

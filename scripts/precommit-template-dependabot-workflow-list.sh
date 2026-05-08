#!/usr/bin/env bash
set -euo pipefail

# This script ensures the exclude-paths list in template/.github/dependabot.yml
# stays in sync with the workflow files delivered through the skeleton.
# It auto-updates the file, then exits non-zero if changes were made so that
# pre-commit signals the user to re-stage.

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

# Build the desired exclude-paths entries from the workflow directory listing
desired_entries=""
for wf in "$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml; do
  [ -e "$wf" ] || continue
  filename="$(basename "$wf")"
  desired_entries="${desired_entries}      - .github/workflows/${filename}
"
done

if [ -z "$desired_entries" ]; then
  echo "No workflow files found in ${WORKFLOWS_DIR}" >&2
  exit 1
fi

# Remove trailing newline for clean comparison
desired_entries="$(echo -n "$desired_entries" | sort)"

# Extract the current exclude-paths block from the dependabot file.
# We look for the marker comment and collect indented list entries that follow.
current_entries=""
in_block=false
while IFS= read -r line; do
  if [[ "$line" == *"# Workflows delivered through the skeleton update process"* ]]; then
    in_block=true
    continue
  fi
  if [ "$in_block" = true ]; then
    # Skip other comment lines within the block
    if [[ "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    # Collect lines that match the "      - .github/workflows/" pattern
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+\.github/workflows/ ]]; then
      current_entries="${current_entries}${line}
"
    else
      break
    fi
  fi
done < "$DEPENDABOT_FILE"

current_entries="$(echo -n "$current_entries" | sort)"

if [ "$current_entries" = "$desired_entries" ]; then
  exit 0
fi

# Replace the exclude-paths entries in the dependabot file.
# Strategy: read the file, when we hit the marker comment, output the comment
# lines then our desired entries, skip old entries, continue with the rest.
tmpfile="$(mktemp)"
in_block=false
skip_entries=false
while IFS= read -r line; do
  if [[ "$line" == *"# Workflows delivered through the skeleton update process"* ]]; then
    in_block=true
    echo "$line" >> "$tmpfile"
    continue
  fi
  if [ "$in_block" = true ]; then
    # Pass through comment lines within the block
    if [[ "$line" =~ ^[[:space:]]*# ]] && [ "$skip_entries" = false ]; then
      echo "$line" >> "$tmpfile"
      continue
    fi
    # Once we hit list entries, skip old ones and write new ones
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+\.github/workflows/ ]]; then
      if [ "$skip_entries" = false ]; then
        skip_entries=true
        echo "$desired_entries" >> "$tmpfile"
      fi
      continue
    else
      # Block is over
      if [ "$skip_entries" = false ]; then
        # No existing entries existed, write ours
        echo "$desired_entries" >> "$tmpfile"
      fi
      in_block=false
      skip_entries=false
      echo "$line" >> "$tmpfile"
    fi
  else
    echo "$line" >> "$tmpfile"
  fi
done < "$DEPENDABOT_FILE"

mv "$tmpfile" "$DEPENDABOT_FILE"

echo "Updated exclude-paths in ${DEPENDABOT_FILE#"$REPO_ROOT"/}" >&2
echo "The following workflow files are now excluded:" >&2
echo "$desired_entries" >&2
exit 1

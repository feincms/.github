#!/usr/bin/env bash
# Normalize repository settings across all (non-archived) repos of a list of
# GitHub orgs/users. Only settings which differ from the desired value are
# changed.
#
# Usage:
#   ./scripts/normalize-repo-settings.sh          # dry run: print what would change
#   ./scripts/normalize-repo-settings.sh --apply  # actually change the settings
#
# Requires: gh (authenticated with repo scope, admin on the repos), jq

set -euo pipefail

DRY_RUN=1
if [[ "${1:-}" == "--apply" ]]; then
    DRY_RUN=0
fi

OWNERS=("feincms" "feinheit")

# Desired settings, as "field=value" using the field names of the REST API:
# https://docs.github.com/en/rest/repos/repos#update-a-repository
SETTINGS=(
    "delete_branch_on_merge=true"
)

for owner in "${OWNERS[@]}"; do
    # Archived repos are read-only, their settings cannot be changed.
    gh repo list "$owner" --limit 1000 --no-archived --json nameWithOwner \
        | jq -r '.[].nameWithOwner' \
        | sort \
        | while read -r repo; do
            data=$(gh api "repos/${repo}")

            if [[ "$(echo "$data" | jq -r '.permissions.admin')" != "true" ]]; then
                echo "SKIP       ${repo}  (no admin permission)"
                continue
            fi

            flags=()
            changes=()
            for setting in "${SETTINGS[@]}"; do
                field="${setting%%=*}"
                wanted="${setting#*=}"
                current=$(echo "$data" | jq -r --arg f "$field" '.[$f]')
                if [[ "$current" != "$wanted" ]]; then
                    flags+=(-F "${field}=${wanted}")
                    changes+=("${field}: ${current} -> ${wanted}")
                fi
            done

            if [[ "${#changes[@]}" -eq 0 ]]; then
                echo "OK         ${repo}"
                continue
            fi

            summary=$(
                IFS=,
                echo "${changes[*]}"
            )
            if [[ "$DRY_RUN" == "1" ]]; then
                echo "WOULD SET  ${repo}  (${summary})"
            else
                gh api --method PATCH "repos/${repo}" "${flags[@]}" >/dev/null
                echo "SET        ${repo}  (${summary})"
            fi
        done
done

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

# Enable Dependabot alerts (free for private repos as well). Only the alerts,
# not Dependabot security updates, which would open pull requests.
DEPENDABOT_ALERTS=1

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

            # Dependabot alerts aren't a field of the repository resource, the
            # endpoint answers 204 if they are enabled and 404 if not.
            enable_alerts=0
            if [[ "$DEPENDABOT_ALERTS" == "1" ]] \
                && ! gh api "repos/${repo}/vulnerability-alerts" --silent 2>/dev/null; then
                enable_alerts=1
                changes+=("dependabot alerts: off -> on")
            fi

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
                if [[ "${#flags[@]}" -gt 0 ]]; then
                    gh api --method PATCH "repos/${repo}" "${flags[@]}" >/dev/null
                fi
                if [[ "$enable_alerts" == "1" ]]; then
                    gh api --method PUT "repos/${repo}/vulnerability-alerts" --silent
                fi
                echo "SET        ${repo}  (${summary})"
            fi
        done
done

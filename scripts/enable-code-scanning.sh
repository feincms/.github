#!/usr/bin/env bash
# Enable CodeQL code scanning (GitHub's "default setup") on all public,
# non-archived repos of a list of GitHub orgs/users. Code scanning is free for
# public repos; private repos would need a GitHub Code Security license and are
# left alone. GitHub detects the languages itself and runs the analysis on
# pushes and pull requests to the default branch and on a weekly schedule.
#
# Usage:
#   ./scripts/enable-code-scanning.sh          # dry run: print what would change
#   ./scripts/enable-code-scanning.sh --apply  # actually enable code scanning
#
# Requires: gh (authenticated with repo scope, admin on the repos), jq

set -euo pipefail

DRY_RUN=1
if [[ "${1:-}" == "--apply" ]]; then
    DRY_RUN=0
fi

OWNERS=("feincms" "feinheit" "matthiask")

for owner in "${OWNERS[@]}"; do
    gh repo list "$owner" --limit 1000 --no-archived --visibility public \
        --json nameWithOwner \
        | jq -r '.[].nameWithOwner' \
        | sort \
        | while read -r repo; do
            if [[ "$(gh api "repos/${repo}" --jq '.permissions.admin')" != "true" ]]; then
                echo "SKIP       ${repo}  (no admin permission)"
                continue
            fi

            if ! setup=$(gh api "repos/${repo}/code-scanning/default-setup" 2>&1); then
                echo "ERROR      ${repo}  ($(echo "$setup" | head -1))"
                continue
            fi

            if [[ "$(echo "$setup" | jq -r '.state')" == "configured" ]]; then
                echo "OK         ${repo}  ($(echo "$setup" | jq -r '.languages | join(",")'))"
                continue
            fi

            if [[ "$DRY_RUN" == "1" ]]; then
                echo "WOULD SET  ${repo}"
            # Fails e.g. for repos without any language CodeQL supports.
            elif result=$(gh api --method PATCH \
                "repos/${repo}/code-scanning/default-setup" \
                -f state=configured -f query_suite=default 2>&1); then
                echo "SET        ${repo}"
            else
                echo "FAIL       ${repo}  ($(echo "$result" | head -1))"
            fi
        done
done

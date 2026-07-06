#!/usr/bin/env bash
# Squash-merge open "[pre-commit.ci] pre-commit autoupdate" PRs across the
# feincms GitHub org, but only the ones that are green and conflict-free.
#
# Usage:
#   ./scripts/merge-precommit-prs.sh          # merge everything that's ready
#   ./scripts/merge-precommit-prs.sh --dry-run  # only print what would happen
#
# Requires: gh (authenticated with repo scope), jq

set -euo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
fi

ORG="feincms"

classify() {
    local data="$1"
    echo "$data" | jq -r '
      [.statusCheckRollup[]? |
        if (.status // "COMPLETED") != "COMPLETED" then "PENDING"
        elif ((.conclusion // "") as $c | ($c == "SUCCESS" or $c == "NEUTRAL" or $c == "SKIPPED")) then "SUCCESS"
        elif (.state // "") == "SUCCESS" then "SUCCESS"
        else "FAILING"
        end
      ] as $s
      | if ($s | length) == 0 then "NO_CHECKS"
        elif ($s | index("FAILING")) then "FAILING"
        elif ($s | index("PENDING")) then "PENDING"
        else "READY"
        end'
}

merged=0
skipped=0

gh search prs --owner "$ORG" --state open --app pre-commit-ci --json repository,number,url --limit 100 \
| jq -c '.[]' \
| while read -r pr; do
    repo=$(echo "$pr" | jq -r '.repository.nameWithOwner')
    number=$(echo "$pr" | jq -r '.number')
    url=$(echo "$pr" | jq -r '.url')

    data=$(gh pr view "$number" --repo "$repo" --json mergeable,statusCheckRollup)
    mergeable=$(echo "$data" | jq -r '.mergeable')
    status=$(classify "$data")

    if [[ "$mergeable" == "MERGEABLE" && "$status" == "READY" ]]; then
        if [[ "$DRY_RUN" == "1" ]]; then
            echo "WOULD MERGE  ${repo} #${number}  ${url}"
        else
            echo "MERGING      ${repo} #${number}  ${url}"
            gh pr merge "$number" --repo "$repo" --squash --delete-branch
        fi
    else
        echo "SKIP         ${repo} #${number}  mergeable=${mergeable} status=${status}  ${url}"
    fi
done

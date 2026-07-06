#!/usr/bin/env bash
# Squash-merge open bot pull requests (pre-commit.ci autoupdate, dependabot)
# across the feincms GitHub org, but only the ones that are green and
# conflict-free.
#
# Usage:
#   ./scripts/merge-bot-prs.sh          # dry run: only print what would happen
#   ./scripts/merge-bot-prs.sh --apply  # actually merge everything that's ready
#
# Requires: gh (authenticated with repo scope), jq

set -euo pipefail

DRY_RUN=1
if [[ "${1:-}" == "--apply" ]]; then
    DRY_RUN=0
fi

ORG="feincms"
BOTS=("pre-commit-ci" "dependabot")

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

for bot in "${BOTS[@]}"; do
    gh search prs --owner "$ORG" --state open --app "$bot" --json repository,number,url --limit 100 \
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
                echo "WOULD MERGE  [${bot}] ${repo} #${number}  ${url}"
            else
                echo "MERGING      [${bot}] ${repo} #${number}  ${url}"
                gh pr merge "$number" --repo "$repo" --squash --delete-branch --body ""
            fi
        else
            echo "SKIP         [${bot}] ${repo} #${number}  mergeable=${mergeable} status=${status}  ${url}"
        fi
    done
done

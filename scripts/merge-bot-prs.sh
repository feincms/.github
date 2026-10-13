#!/usr/bin/env bash
# Squash-merge open bot pull requests (pre-commit.ci autoupdate, dependabot)
# across a list of GitHub orgs/users, but only the ones that are green and
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

# Owners to search across - GitHub orgs and/or individual users, gh doesn't
# distinguish between the two for the --owner search qualifier.
OWNERS=("feincms" "matthiask" "feinheit" "django-commons")
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

owner_flags=()
for owner in "${OWNERS[@]}"; do
    owner_flags+=(--owner "$owner")
done

for bot in "${BOTS[@]}"; do
    # --archived=false keeps PRs on archived repos out of the results; they can
    # never be merged anyway.
    gh search prs "${owner_flags[@]}" --state open --app "$bot" --archived=false \
        --json repository,number,url --limit 100 \
        | jq -c '.[]' \
        | while read -r pr; do
            repo=$(echo "$pr" | jq -r '.repository.nameWithOwner')
            number=$(echo "$pr" | jq -r '.number')
            url=$(echo "$pr" | jq -r '.url')

            # Owners like django-commons contain repos we can't push to, and
            # therefore can't merge PRs in.
            if [[ "$(gh api "repos/${repo}" --jq '.permissions.push')" != "true" ]]; then
                echo "SKIP         [${bot}] ${repo} #${number}  (no push permission)  ${url}"
                continue
            fi

            data=$(gh pr view "$number" --repo "$repo" --json mergeable,statusCheckRollup)
            mergeable=$(echo "$data" | jq -r '.mergeable')
            status=$(classify "$data")

            if [[ "$mergeable" == "MERGEABLE" && "$status" == "READY" ]]; then
                if [[ "$DRY_RUN" == "1" ]]; then
                    echo "WOULD MERGE  [${bot}] ${repo} #${number}  ${url}"
                else
                    echo "MERGING      [${bot}] ${repo} #${number}  ${url}"
                    # Branch protection rules etc. may still prevent merging,
                    # carry on with the remaining PRs.
                    if ! gh pr merge "$number" --repo "$repo" --squash --delete-branch --body ""; then
                        echo "FAILED       [${bot}] ${repo} #${number}  ${url}"
                    fi
                fi
            else
                echo "SKIP         [${bot}] ${repo} #${number}  mergeable=${mergeable} status=${status}  ${url}"
            fi
        done
done

#!/usr/bin/env bash
# Add .github/dependabot.yml to every feincms org repo that doesn't have one
# yet, with ecosystems (github-actions / pip / npm) picked based on what's
# actually present in the repo. Commits directly to the default branch.
#
# Usage:
#   ./scripts/add-dependabot-config.sh          # dry run: print what would be added
#   ./scripts/add-dependabot-config.sh --apply  # actually create the files
#
# Requires: gh (authenticated with repo scope), jq

set -euo pipefail

DRY_RUN=1
if [[ "${1:-}" == "--apply" ]]; then
    DRY_RUN=0
fi

ORG="feincms"

github_actions_block=$(cat <<'EOF'
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "monthly"
    groups:
      github-actions:
        patterns:
          - "*"
EOF
)

pip_block=$(cat <<'EOF'
  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "monthly"
    groups:
      python-deps:
        patterns:
          - "*"
EOF
)

npm_block=$(cat <<'EOF'
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "monthly"
    groups:
      npm-deps:
        patterns:
          - "*"
EOF
)

path_exists() {
    # $1 = repo, $2 = path
    gh api "repos/${ORG}/$1/contents/$2" >/dev/null 2>&1
}

gh repo list "$ORG" --limit 200 --json name,isArchived,isFork \
| jq -r '.[] | select(.isArchived==false and .isFork==false) | .name' \
| sort \
| while read -r repo; do
    if path_exists "$repo" ".github/dependabot.yml"; then
        echo "SKIP    ${repo}  (already has dependabot.yml)"
        continue
    fi

    blocks=()
    path_exists "$repo" ".github/workflows" && blocks+=("$github_actions_block")
    { path_exists "$repo" "setup.py" || path_exists "$repo" "setup.cfg" || path_exists "$repo" "pyproject.toml"; } && blocks+=("$pip_block")
    path_exists "$repo" "package.json" && blocks+=("$npm_block")

    if [[ "${#blocks[@]}" -eq 0 ]]; then
        echo "SKIP    ${repo}  (no known ecosystem: no workflows, no pip/npm manifest)"
        continue
    fi

    content="version: 2
updates:
$(IFS=$'\n'; echo "${blocks[*]}")
"

    if [[ "$DRY_RUN" == "1" ]]; then
        echo "WOULD ADD  ${repo}  ($(echo "${blocks[@]}" | grep -o 'package-ecosystem: "[a-z-]*"' | paste -sd, -))"
    else
        default_branch=$(gh api "repos/${ORG}/${repo}" --jq '.default_branch')
        encoded=$(printf '%s' "$content" | base64 -w0)
        gh api --method PUT "repos/${ORG}/${repo}/contents/.github/dependabot.yml" \
            -f message="Add dependabot.yml" \
            -f content="$encoded" \
            -f branch="$default_branch" \
            >/dev/null
        echo "ADDED      ${repo}"
    fi
done

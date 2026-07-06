# .github

Community health files and org-wide tooling for the [feincms](https://github.com/feincms)
GitHub organization.

## Scripts

### `scripts/merge-precommit-prs.sh`

Finds all open `[pre-commit.ci] pre-commit autoupdate` pull requests across every
repo in the org and squash-merges the ones that are green (all checks passed)
and conflict-free. PRs that are still running CI, failing, or have merge
conflicts are skipped and printed so they can be handled separately.

```console
$ ./scripts/merge-precommit-prs.sh --dry-run   # preview only
$ ./scripts/merge-precommit-prs.sh             # actually merge
```

Requires the [`gh` CLI](https://cli.github.com/) (authenticated, `repo` scope)
and `jq`.

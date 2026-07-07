# .github

Community health files and org-wide tooling for the [feincms](https://github.com/feincms)
GitHub organization.

## Scripts

### `scripts/merge-bot-prs.sh`

Finds all open pull requests from pre-commit.ci and dependabot across every
repo in the org and squash-merges the ones that are green (all checks passed)
and conflict-free. PRs that are still running CI, failing, or have merge
conflicts are skipped and printed so they can be handled separately.

```console
$ ./scripts/merge-bot-prs.sh          # preview only (default)
$ ./scripts/merge-bot-prs.sh --apply  # actually merge
```

Requires the [`gh` CLI](https://cli.github.com/) (authenticated, `repo` scope)
and `jq`.

### `scripts/add-dependabot-config.sh`

Adds `.github/dependabot.yml` to every repo in the org that doesn't already
have one, picking ecosystems (`github-actions`, `pip`, `npm`) based on what's
actually present in the repo (workflow files, `setup.py`/`setup.cfg`/
`pyproject.toml`, `package.json`). Repos with no recognizable ecosystem are
skipped. Commits the file directly to each repo's default branch.

```console
$ ./scripts/add-dependabot-config.sh          # preview only (default)
$ ./scripts/add-dependabot-config.sh --apply  # actually create the files
```

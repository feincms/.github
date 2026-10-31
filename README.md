# .github

Community health files and org-wide tooling for the [feincms](https://github.com/feincms)
GitHub organization.

## Scripts

### `scripts/merge-bot-prs.sh`

Finds all open pull requests from pre-commit.ci and dependabot across every
repo in the org and squash-merges the ones that are green (all checks passed)
and conflict-free. PRs that are still running CI, failing, or have merge
conflicts are skipped and printed so they can be handled separately. PRs in
repos you don't have push permission on are skipped as well.

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

### `scripts/normalize-repo-settings.sh`

Makes repository settings consistent across every non-archived repo of the
`feincms` and `feinheit` owners. The desired settings are listed in the
`SETTINGS` array at the top of the script as `field=value` pairs using the
[REST API field names](https://docs.github.com/en/rest/repos/repos#update-a-repository)
(currently only `delete_branch_on_merge=true`). It also enables Dependabot
alerts (free for private repos too; only the alerts, not the security update
pull requests). Only settings which differ are changed; repos you don't have
admin permission on are skipped.

```console
$ ./scripts/normalize-repo-settings.sh          # preview only (default)
$ ./scripts/normalize-repo-settings.sh --apply  # actually change the settings
```

### `scripts/enable-code-scanning.sh`

Enables CodeQL code scanning ([default
setup](https://docs.github.com/en/code-security/code-scanning/enabling-code-scanning/configuring-default-setup-for-code-scanning))
on every public, non-archived repo of the `feincms` and `feinheit` owners which
doesn't have it yet. Code scanning is free for public repos; private repos are
left alone since they'd need a Code Security license. GitHub picks the
languages itself and scans pushes and pull requests to the default branch plus
once a week. Repos without a language CodeQL supports fail and are reported;
repos you don't have admin permission on are skipped.

```console
$ ./scripts/enable-code-scanning.sh          # preview only (default)
$ ./scripts/enable-code-scanning.sh --apply  # actually enable code scanning
```

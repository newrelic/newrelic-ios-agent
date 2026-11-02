# Release notes for the iOS agent

Automation that writes the iOS agent's docs-website release notes, in the
[release-notes template](https://github.com/newrelic/docs-website/blob/develop/templates/release-notes-template.mdx)
format. A person checks every note before it is published.

This is the iOS agent's own copy of the release-notes code the other mobile agents use. It was
copied from [newrelic/newrelic-android-agent `.github/actions/release-notes/`](https://github.com/newrelic/newrelic-android-agent/tree/develop/.github/actions/release-notes)
at `develop` bfe5c2c1 (2026-11-02), keeping only the iOS test fixtures and documentation; the
scripts and actions are unchanged. This repo's `release-notes-*.yml` workflows use it by path
(`./.github/actions/release-notes/<action>`). Changes on either side don't reach the other unless
they are copied over.

Every note has the template's layout: the frontmatter `subject`, `releaseDate`, `version`, the
`features`, `enhancements`, `bugs` and `security` lists, then `downloadLink` (no `category:`), and a
`### New features`, `### Improvements and enhancements`, `### Bug fixes` or `### Security updates`
heading for each section that has bullets. Each frontmatter list item is the whole bullet as plain
text, on one line and without its PR link, markup or final full stop. It is never shortened: the docs
team asked for whole sentences (docs-website#26416). Frontmatter items are worked out again from the
bullet text every time a note is built, so editing a bullet on the next draft is enough.

- **`append`**, on every merged PR: builds the PR's bullet and adds it to the `ios-next` branch on
  `newrelic/docs-website`, behind a draft "next release notes" PR that is never merged.
- **`generate`**, on every release: reconciles the accumulated bullets and every PR between the
  previous release tag and the new one, writes the release `.mdx`, opens it as a docs-website PR
  (ready for review, because `readyForReview` is set), and removes the released bullets from the
  next branch. The release branch lives on the bot's fork of docs-website, so the team can edit the
  note (see "Editing a release note on the fork").
- **`check`**, on every open PR: comments with the section and the bullet the PR will become. With
  `labelledOnly`, a PR with no label passes and the comment says it is left out; a PR with more than
  one `release-note:*` label fails.
- **`ready`**, run by hand: marks a docs PR that is still a draft ready for review, and comments with
  who checked it. It runs as the bot that opened the PR, so it works for people without write access
  to docs-website. With `readyForReview` set, new docs PRs don't need it.

Everything iOS-specific is in `.github/release-notes.json` and the skeleton `ios-agent-next.mdx`;
nothing in this folder names the agent.

## How a bullet is built

1. **Text:** a `## Release note` heading (any level, "note" or "notes") followed by a paragraph in the
   PR description, or a `Release note: ...` line, is used as written. Otherwise the title is used with
   its Conventional Commit type and Jira key removed and the leading verb put in the past tense
   (`fix: guard against null filename (NR-1)` becomes "Guarded against null filename."). `N/A` in
   the section means "use the title". A paragraph of two or more lines that all start with `- ` or
   `* ` is a list: each line becomes its own bullet, all in the PR's one section; blank lines between
   the items are fine. A single `- ` line, or prose mixed with list lines, is one bullet.
2. **Section:** the PR's `release-note:*` label:

   | Label | Section |
   |---|---|
   | `release-note:feature` | New features |
   | `release-note:enhancement` | Improvements and enhancements |
   | `release-note:bug` | Bug fixes (say what was broken) |
   | `release-note:security` | Security updates |

   A PR with more than one label is still included, and the docs PR lists it under "Bullets that need
   extra attention".
3. **Left out:** every PR with no `release-note:*` label (`labelledOnly`), so release, staging,
   production, back-merge and sync PRs need nothing. A label added after the merge still counts,
   because `generate` reads each PR's labels again at release time. Also left out: labelled PRs with
   `[skip-docs]` in the description, and release, back-port, revert and `main`/`develop` sync PRs.
   Every PR in a release that gets no bullet is listed in the docs PR.

## `.github/release-notes.json`

```json
{
  "subject": "iOS agent",
  "docsFolder": "ios-release-notes",
  "filePrefix": "ios-agent-",
  "nextBranch": "ios-next",
  "tagPrefix": "",
  "skeleton": "ios-agent-next.mdx",
  "downloadLink": "https://download.newrelic.com/ios_agent/NewRelic_XCFramework_Agent_{version}.zip",
  "labelledOnly": true,
  "prLinks": false,
  "readyForReview": true
}
```

| Field | Required | Meaning |
|---|---|---|
| `subject` | yes | Frontmatter `subject:`. Letters, digits, spaces and `. + -`. Must match the skeleton's `subject:`. |
| `docsFolder` | yes | Folder under docs-website's `src/content/docs/release-notes/mobile-release-notes/`. |
| `filePrefix` | yes | The release file is prefix + version digits + `.mdx`: `ios-agent-` gives `ios-agent-7711.mdx`. |
| `nextBranch` | yes | Accumulation branch on docs-website; ends in `-next`. `ios-next` gives release branches `ios_release_notes_7-7-11`. |
| `tagPrefix` | yes | Text before the version in release tags: `""` for `7.7.11` tags. Only `<tagPrefix>X.Y.Z` tags are releases, so `7.7.11-rc.3051` is not. |
| `skeleton` | yes | Path of the committed skeleton. Its file name is also the accumulating file's name on docs-website. |
| `downloadLink` | no | `https://` template. `{version}` is `7.7.11`, `{tag}` is the tag. Left out: no `downloadLink:` line. |
| `changelog` | no | A CHANGELOG to reconcile against. iOS has none. |
| `fallbackText` | no | Bullet used when a release has no bullets at all. Default `Updated version.` |
| `prLinks` | no | `true` or `false`. Default `true`: each bullet ends with its PR link, `([#123](…))`. iOS sets `false`: the published note has no links; the next draft and the docs PR text keep them. |
| `labelledOnly` | no | `true` or `false`. Default `false`. iOS sets `true`: only PRs with a `release-note:*` label become bullets; `check` passes unlabelled PRs and says they are left out. |
| `readyForReview` | no | `true` or `false`. Default `false`: `generate` opens the docs PR as a draft, for `ready` to mark later. iOS sets `true`: it opens ready for review, and its text says why. A PR that is already open keeps its state. |

`config.sh` validates all of this first in every action, and in the `check` action on every PR, and
names the field at fault.

## Skeleton

`ios-agent-next.mdx` at the repo root starts every next draft: the frontmatter, then a
`{/* release-note:feature */}`, `{/* release-note:enhancement */}`, `{/* release-note:bug */}` and
`{/* release-note:security */}` marker, each before its section heading, and
`{/* release-note:end */}`. Anything after the end marker would end every note; iOS has nothing
there. Its frontmatter values and headings are placeholders: the release note always gets the layout
described at the top.

## This repo's workflows

- `release-notes-check.yml`: runs `check` on every PR into `develop`.
- `release-notes-append.yml`: runs `append` when a PR into `develop` merges. It checks out the base
  branch, so only reviewed code runs with the bot's token.
- `release-notes-generate.yml`: runs `generate` when a release is published (not for pre-releases),
  and by hand from the Actions tab with a version, `overwrite` and `dry-run`. It checks out `develop`,
  so a re-run for an older tag uses the code as reviewed now. `release-date: published` dates the
  note from the release's publish date. A `release` event runs the workflow file as it is at the
  tagged commit, so changes to the file itself reach a release only once they are on `main`.
- `release-notes-ready.yml`: runs `ready` by hand with a version, for a docs PR still in draft.
- `release-notes-tests.yml`: on every PR that changes this folder, the config, the skeleton or these
  workflows, runs the test suite, shellcheck, the linters and a 7.7.10 `generate` dry run.

The secrets are `BOT_PAT` (opens and updates the docs PRs), `BOT_FORK_PAT` (pushes release branches
to the bot's fork) and `BOT_EMAIL`. The optional repo variable `DOCS_REPO` points the workflows at a
docs-website fork.

**A cancelled generate run must be run again by hand.** `append` and `generate` share the
concurrency group `docs-release-notes-next`, so a release never races a bullet push. GitHub keeps
only one *pending* run per group: when another run queues behind a waiting one, the waiting run is
cancelled. A cancelled append costs nothing, because the release run builds any missing bullet. A
cancelled generate leaves the release without a docs PR and its bullets on the next branch. If a
generate run shows as cancelled, run `release-notes-generate.yml` by hand with that version.

`ready` finds the open docs PR on the version's release branch (`ios_release_notes_7-7-11`), marks it
ready for review, and comments "Marked ready for review by @<you>" with a link to the run. A PR that
is already ready is left alone.

## Editing a release note on the fork

docs-website gives write access only to bot accounts, so release branches it holds can't be edited
by the people who check the notes. With `fork-pat`, `generate` pushes each release's branch to the
bot's fork `newrelic-mobile-agents-bot/docs-website` instead and opens the PR from there; fork
collaborators can push to it. The next draft (`ios-next`) stays on docs-website: nobody edits it.

To edit a note: open the docs PR, follow its branch to the fork, and edit the file there (the GitHub
web editor works) or push to the branch with git. The PR updates by itself, whether it is a draft or
ready for review. You need collaborator access to the fork; ask whoever manages the bot account.
GitHub opens these PRs without "allow edits by maintainers" (`BOT_PAT` has no access to the bot's
fork), so the docs team suggests changes rather than pushing them. If GitHub ever refuses the
request outright, generate retries without it and says so.

## Action inputs

`append`, `check` and `generate` take `github-token` (default: the run's token), `config` (default
`.github/release-notes.json`) and `dry-run` (default `false`).

| Action | Other inputs |
|---|---|
| `append` | `bot-pat`, `bot-email`, `docs-repo` (default `newrelic/docs-website`), `pr-number` (default: the event's PR) |
| `check` | none |
| `generate` | `version` (required), `overwrite`, `release-date` (`YYYY-MM-DD`, or `published` for the GitHub release's publish date; default: the tagged commit's date), `bot-pat`, `bot-email`, `docs-repo`, `fork-pat` (default empty: release branches stay on docs-repo) |
| `ready` | `version` (required), `bot-pat` (required), `docs-repo`, `config`. No `github-token` or `dry-run`: it reads nothing but the docs PR and changes only its draft state and comments. |

`bot-pat` reaches only the steps that talk to docs-website, and `fork-pat` only generate's two that
publish (or preview) the release branch; the steps that read PR text use `github-token`. With
`dry-run: true` nothing on docs-website changes and `bot-pat` is not needed: the note (or the bullet)
and the docs PR text go to the job summary. A real `generate` run never overwrites a release branch
or file that differs from what it built unless `overwrite` is `true`.

## Trying it out

- **Dry run.** Run **Actions → Release notes - generate** with a released version and `dry-run`
  ticked, and read the job summary. `release-notes-tests.yml` does the same for 7.7.10 on every PR
  that changes this code.
- **Changing a note without editing the docs PR.** Edit the `## Release note` section (or the label)
  of the original PR, run generate with `dry-run` to check, then again with `overwrite`. `overwrite`
  discards edits already made on the fork branch.

## Changing this code

- Run `bash .github/actions/release-notes/test/run.sh`,
  `bash .github/actions/release-notes/test/lint-actions.sh` and
  `shellcheck --severity=warning -x .github/actions/release-notes/scripts/*.sh .github/actions/release-notes/test/*.sh`.
  CI (`release-notes-tests.yml`) runs them too.
- `test/test_agents.sh` builds a note from the iOS sample config and skeleton (`test/agents/ios/`,
  copies of this repo's) and compares it with `test/expected/ios.mdx`. After an intended change, run
  it with `UPDATE_EXPECTED=1` and review the diff of `test/expected/` in the PR.
- The scripts are bash 3.2 compatible (macOS) and run in the C locale.
- To take a fix from the Android agent's copy, copy the changed files from its
  `.github/actions/release-notes/scripts/` and action folders; they started out identical. Its tests
  cover the other agents too, so bring over only the tests that apply.

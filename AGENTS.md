# AGENTS.md

## Project

This repository contains a Factorio mod written in Lua.

The mod lives in:

```txt
factorio-rate-calculator-tooltip/
```

## Validation

Before committing Lua changes, run:

```sh
luac -p factorio-rate-calculator-tooltip/control.lua
luac -p factorio-rate-calculator-tooltip/data-final-fixes.lua
git diff --check
```

When editing `changelog.txt`, also verify:

```sh
awk '/^-+$/ { print NR, length($0) }' factorio-rate-calculator-tooltip/changelog.txt
rg -n "\t|[[:blank:]]$" factorio-rate-calculator-tooltip/changelog.txt
```

These commands are only quick sanity checks. They do not prove that the changelog is fully valid.

## Changelog

Always keep `factorio-rate-calculator-tooltip/changelog.txt` up to date when changing user-visible behavior, fixing bugs, or preparing a release.

Official format reference:

```txt
https://lua-api.factorio.com/latest/auxiliary/changelog-format.html
```

Factorio expects `changelog.txt` to be located in the root of the mod folder:

```txt
factorio-rate-calculator-tooltip/changelog.txt
```

The Mod Portal displays changelog text as plain text, but the in-game mod browser requires the strict Factorio format.

Use this shape:

```txt
---------------------------------------------------------------------------------------------------
Version: 0.1.11
Date: 16. 07. 2026
  Bugfixes:
    - Fixed one issue.
    - Fixed another issue in the same release.
```

Rules:

- Use a 99-hyphen separator line before each version.
- The line after a separator must be a non-empty `Version: ` line.
- `Version: ` must start exactly with `Version: `, including the space after the colon.
- Versions must be `major.minor.sub`, each number between `0` and `65535`.
- `0.0.0` is invalid.
- Do not duplicate a version section.
- `Date: ` is optional, but if present it must start exactly with `Date: `.
- Do not add more than one date line in the same version section.
- Completely empty lines are skipped, except directly after a separator, where an empty line is invalid.
- Category names must start with exactly two spaces and end with `:`, for example `  Bugfixes:`.
- Categories are optional, but entries require a previous category in the same version section.
- Single-line entries must start with exactly four spaces, dash, space: `    - Fixed ...`.
- Multiline entry continuation lines must start with exactly six spaces.
- Do not add exact duplicate entries in the same version and category.
- Do not use tabs.
- Do not leave trailing whitespace.
- A version can include multiple bugfixes. Do not create one version per bugfix.
- Group related fixes in one bullet when that is clearer.

Common categories:

```txt
  Features:
  Changes:
  Bugfixes:
  Compatibility:
  Locale:
  Info:
```

## Releases

This mod currently publishes separate builds for Factorio 2.0 and 2.1.

The release metadata is controlled by:

```txt
factorio-rate-calculator-tooltip/info.json
```

Use the existing pattern:

- Factorio 2.0 releases use `"factorio_version": "2.0"` and `"base >= 2.0"`.
- Factorio 2.1 releases use `"factorio_version": "2.1"` and `"base >= 2.1"`.
- Keep version numbers monotonic.
- After releasing both variants, leave the working tree on the latest Factorio 2.1 version unless the user asks otherwise.

## Deployment

Deployment to the Factorio Mod Portal is handled by the GitHub Action:

```txt
.github/workflows/publish-mod.yml
```

The action runs when a tag matching `v*` is pushed.

To trigger deployment:

```sh
git tag v0.1.11
git push origin main --tags
```

The tag must point at the commit that should be packaged and published. Add the tag on the latest release commit, not on an older commit.

The workflow also supports manual dispatch with `ref_to_publish`, but the normal release path is a pushed `v*` tag.

The workflow packages the mod by calling:

```sh
./package.sh factorio-rate-calculator-tooltip
```

Keep `package.sh` available and compatible with the workflow, or update the workflow at the same time.

## Git

- Do not add co-authors to commits unless the user explicitly asks.
- Keep release commits clear and small.
- Prefer one focused fix commit before the release metadata commits.
- Push both `main` and tags when publishing releases.

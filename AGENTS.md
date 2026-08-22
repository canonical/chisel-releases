# AGENTS.md

Guidance for coding agents working on this Chisel release branch.

## Repository layout

This repository is organised by git branch: `main` is meta-only (CI and contributor documentation), and every branch named `ubuntu-XX.XX` -- like this one -- is one [Chisel](https://github.com/canonical/chisel) release, holding the release manifest (`chisel.yaml`), the Slice Definition Files (SDFs, `slices/`), and their [spread](https://github.com/canonical/spread) tests (`tests/spread/`). The upstream repository is [`canonical/chisel-releases`](https://github.com/canonical/chisel-releases), but this clone may be of a fork.

## Full guidance

Full guidance for working on a Chisel release branch lives on the `main` branch, in [AGENTS-release.md](https://github.com/canonical/chisel-releases/blob/main/AGENTS-release.md). ALWAYS read it. The fetch below matches the remote by URL rather than by name:

```bash
git show "$(git remote -v | awk '/canonical\/chisel-releases/{print $1; exit}')/main:AGENTS-release.md"
```

or, if that fails:

```bash
curl -fsSL https://raw.githubusercontent.com/canonical/chisel-releases/main/AGENTS-release.md
```

If you cannot read it, say so and stop rather than guessing at conventions.

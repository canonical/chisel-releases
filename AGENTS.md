# AGENTS.md

Guidance for coding agents working on this Chisel release branch.

Guidance for contributors can be found at [CONTRIBUTING.md](https://github.com/canonical/chisel-releases/blob/main/CONTRIBUTING.md). on `main`.

## Repository layout

This repository is organised by git branch: `main` is meta-only (reusable CI workflows, CI scripts and their tests, and contributor documentation -- there are no slice definitions there), and every branch named `ubuntu-XX.XX` -- like this one -- is one [Chisel](https://github.com/canonical/chisel) release, holding the release manifest (`chisel.yaml`), the Slice Definition Files (SDFs, `slices/`), and their [spread](https://github.com/canonical/spread) tests (`tests/spread/`). The upstream repository is [`canonical/chisel-releases`](https://github.com/canonical/chisel-releases), but this clone may be of a fork.
